import Foundation
import UIKit
import UserNotifications

/// 앱 진입 시 푸시 권한을 요청하고 APNs 등록을 트리거한다.
/// APNs 토큰은 AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken 에서 수신해 Firebase 에 전달하고,
/// 발급된 FCM 토큰을 messaging(_:didReceiveRegistrationToken:) 에서 `NotificationClient.registerDeviceToken` 로 서버에 PUT.
@MainActor
enum PushNotificationCoordinator {

    /// 앱 첫 진입 또는 세션 복구 시 호출.
    /// 권한이 거부되어 있어도 다음 실행에서 다시 요청하지 않음 (iOS 정책).
    static func bootstrap() async {
        let center = UNUserNotificationCenter.current()

        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            return

        case .denied:
            // 사용자가 명시적으로 거부 — 다시 묻지 않음
            return

        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } catch {
                print("[Union] 알림 권한 요청 실패: \(error.localizedDescription)")
            }
            return

        @unknown default:
            return
        }
    }
}
