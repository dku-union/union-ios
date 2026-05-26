import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
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
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Union] APNs token: \(token)")
        DevicePushTokenStore.shared.update(token)

        // Spring 서버에 등록 (fire-and-forget). 로그인 전이면 401 → 다음 로그인 후 재시도.
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

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Union] APNs registration failed: \(error.localizedDescription)")
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
