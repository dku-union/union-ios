import Foundation
import UIKit

/// 단일 기기에서 안정적으로 유지되는 deviceId. Spring `UserFcmToken.deviceId` 와 매핑.
///
/// 우선순위:
/// 1. UserDefaults 에 저장된 값 (앱 삭제 전까지 유지)
/// 2. `UIDevice.identifierForVendor` (벤더 단위 고유 ID — 같은 vendor 앱이 모두 삭제되면 재발급)
/// 3. 새 UUID 폴백
enum DeviceIdentity {

    private static let deviceIdKey = "union.deviceId"

    static var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: deviceIdKey) {
            return saved
        }
        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(generated, forKey: deviceIdKey)
        return generated
    }

    static var appVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static var osVersion: String {
        UIDevice.current.systemVersion
    }
}
