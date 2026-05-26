import Foundation
import UIKit
import UserNotifications

// MARK: - Notification Bridge Module
// SDK: Union.notification.requestPermission(), getPermissionStatus(), scheduleLocal(...),
//      cancelLocal(...), getDeviceToken(), subscribe(), unsubscribe()
//
// 원격 푸시 발송은 SDK 가 직접 하지 않는다 — publisher 백엔드 → Spring → FCM 경로만 허용.
// 따라서 send / sendRemote 같은 action 은 의도적으로 누락.

struct NotificationBridgeModule {

    /// BridgeHandler 가 자신이 담당하는 미니앱의 appId 를 주입.
    /// Union.notification.subscribe() 호출 시 자동으로 이 appId 가 사용됨.
    let miniAppAppId: String?

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {
        case "requestPermission":
            return try await requestPermission()

        case "getPermissionStatus":
            return await getPermissionStatus()

        case "getDeviceToken":
            return ["token": DevicePushTokenStore.shared.current() as Any]

        case "scheduleLocal":
            return try await scheduleLocal(params: params)

        case "cancelLocal":
            let id = params["notificationId"] as? String ?? ""
            await MainActor.run {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            }
            return nil

        case "cancelAllLocal":
            await MainActor.run {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
            return nil

        case "subscribe":
            guard let appId = effectiveAppId(params: params) else {
                throw BridgeModuleError(code: "MISSING_APP_ID", message: "appId 가 매니페스트에서 누락")
            }
            try await NotificationClient.liveValue.subscribe(appId)
            return nil

        case "unsubscribe":
            guard let appId = effectiveAppId(params: params) else {
                throw BridgeModuleError(code: "MISSING_APP_ID", message: "appId 가 매니페스트에서 누락")
            }
            try await NotificationClient.liveValue.unsubscribe(appId)
            return nil

        case "setPushEnabled":
            guard let appId = effectiveAppId(params: params) else {
                throw BridgeModuleError(code: "MISSING_APP_ID", message: "appId 가 매니페스트에서 누락")
            }
            let enabled = (params["enabled"] as? Bool) ?? true
            try await NotificationClient.liveValue.setPushEnabled(appId, enabled)
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "notification.\(action) not found")
        }
    }

    // MARK: - Permission

    private func requestPermission() async throws -> [String: Any] {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        if granted {
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
        let status = await getPermissionStatus()
        return [
            "granted": granted,
            "status": status["status"] as? String ?? "undetermined"
        ]
    }

    private func getPermissionStatus() async -> [String: Any] {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let status: String
        switch settings.authorizationStatus {
        case .notDetermined: status = "undetermined"
        case .denied: status = "denied"
        case .authorized: status = "authorized"
        case .provisional: status = "provisional"
        case .ephemeral: status = "ephemeral"
        @unknown default: status = "undetermined"
        }
        return ["status": status]
    }

    // MARK: - Local notification

    private func scheduleLocal(params: [String: Any]) async throws -> [String: Any] {
        let title = params["title"] as? String ?? ""
        let body = params["body"] as? String ?? ""
        let delaySeconds = (params["delaySeconds"] as? Double) ?? 5
        let identifier = (params["notificationId"] as? String) ?? UUID().uuidString
        let userInfo = params["data"] as? [String: Any] ?? [:]

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delaySeconds), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
        return ["notificationId": identifier]
    }

    // MARK: - Helpers

    private func effectiveAppId(params: [String: Any]) -> String? {
        if let explicit = params["appId"] as? String, !explicit.isEmpty {
            return explicit
        }
        return miniAppAppId
    }
}
