import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate, @preconcurrency MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Firebase 초기화 — GoogleService-Info.plist 가 번들에 있을 때만.
        // 누락 시 configure 가 크래시하므로 가드하고, 푸시만 비활성화한다.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        } else {
            print("[Union] GoogleService-Info.plist 누락 — Firebase 미초기화, 원격 푸시 비활성")
        }

        // 포그라운드/탭 알림 처리 위임
        UNUserNotificationCenter.current().delegate = self

        // 앱 콜드 스타트 시 알림으로 진입한 경우 deeplink 처리
        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            DeeplinkRouter.shared.handle(userInfo: userInfo, source: .coldLaunch)
        }
        return true
    }

    // MARK: - Push Notifications: Registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // FCM 은 APNs 위에서 동작 — raw APNs 토큰을 Firebase 에 전달한다.
        // FCM 등록 토큰은 messaging(_:didReceiveRegistrationToken:) 로 비동기 전달되지만,
        // 그 콜백이 apnsToken 부착 전에 fire 될 수 있어 여기서 명시적으로도 fetch 한다.
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("[Union] FCM 토큰 fetch 실패: \(error.localizedDescription)")
                return
            }
            if let token { self?.registerFcmTokenToServer(token) }
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Union] APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - FCM Registration Token

    /// Firebase 가 FCM 등록 토큰을 발급/갱신할 때 호출된다.
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else {
            print("[Union] FCM 등록 토큰 nil — 등록 스킵")
            return
        }
        registerFcmTokenToServer(fcmToken)
    }

    /// FCM 토큰을 메모리 캐시에 저장하고 Spring 서버에 등록한다 (fire-and-forget).
    /// delegate 콜백과 명시적 token fetch 양쪽에서 호출 — 동일 토큰이면 백엔드 upsert 로 idempotent.
    /// 로그인 전이면 401 → 로그인 성공 시 AppFeature 가 재등록한다.
    private func registerFcmTokenToServer(_ token: String) {
        print("[Union] FCM token: \(token)")
        DevicePushTokenStore.shared.update(token)
        Task.detached {
            do {
                try await NotificationClient.liveValue.registerDeviceToken(
                    DeviceIdentity.deviceId,
                    token,
                    DeviceIdentity.appVersion,
                    DeviceIdentity.osVersion
                )
                print("[Union] FCM 토큰 서버 등록 성공")
            } catch {
                print("[Union] FCM 토큰 서버 등록 실패: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Push Notifications: Reception

    /// 백그라운드 사일런트 푸시 — content-available 케이스.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        DeeplinkRouter.shared.handle(userInfo: userInfo, source: .background)
        completionHandler(.newData)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// 포그라운드 상태에서도 배너/사운드를 보이게 함.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // SDK 이벤트로 미니앱에도 알림 페이로드 전달
        DeeplinkRouter.shared.broadcastToBridge(userInfo: notification.request.content.userInfo)
        completionHandler([.banner, .sound, .badge, .list])
    }

    /// 사용자가 알림을 탭한 케이스 — deeplink 라우팅.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        DeeplinkRouter.shared.handle(
            userInfo: response.notification.request.content.userInfo,
            source: .tap
        )
        completionHandler()
    }
}
