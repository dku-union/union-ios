import Foundation

/// FCM 등록 토큰의 메모리 캐시.
/// AppDelegate가 FCM 등록 콜백(messaging:didReceiveRegistrationToken:)에서 업데이트하고,
/// Bridge `notification.getDeviceToken` 등에서 조회.
final class DevicePushTokenStore: @unchecked Sendable {
    static let shared = DevicePushTokenStore()
    private let lock = NSLock()
    private var token: String?

    private init() {}

    func update(_ newToken: String) {
        lock.lock(); defer { lock.unlock() }
        token = newToken
    }

    func current() -> String? {
        lock.lock(); defer { lock.unlock() }
        return token
    }
}
