import Foundation

// MARK: - Storage Bridge Module
// SDK: Union.storage.get(), set(), remove(), clear()
// 앱별 격리된 UserDefaults suite 사용

struct StorageBridgeModule {
    private let defaults: UserDefaults

    init(appId: String) {
        // 미니앱별 격리된 저장소: "union.miniapp.<appId>"
        self.defaults = UserDefaults(suiteName: "union.miniapp.\(appId)") ?? .standard
    }

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {
        case "get":
            guard let key = params["key"] as? String else {
                throw BridgeModuleError(code: "INVALID_PARAMS", message: "key is required")
            }
            return defaults.object(forKey: key)

        case "set":
            guard let key = params["key"] as? String else {
                throw BridgeModuleError(code: "INVALID_PARAMS", message: "key is required")
            }
            let value = params["value"]
            defaults.set(value, forKey: key)
            return nil

        case "remove":
            guard let key = params["key"] as? String else {
                throw BridgeModuleError(code: "INVALID_PARAMS", message: "key is required")
            }
            defaults.removeObject(forKey: key)
            return nil

        case "clear":
            // suite의 모든 키 삭제
            for key in defaults.dictionaryRepresentation().keys {
                defaults.removeObject(forKey: key)
            }
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "storage.\(action) not found")
        }
    }
}
