import Foundation

// MARK: - Auth Bridge Module
// SDK: Union.auth.login(), getUserProfile(), getAccessToken(), logout()

struct AuthBridgeModule {

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {
        case "login":
            // 네이티브 로그인 세션에서 auth code 반환
            // 실제로는 네이티브 로그인 UI를 띄우거나 기존 세션 활용
            let token = KeychainStore.load(.accessToken)
            if let token, !token.isEmpty {
                return ["code": "auth_code_\(token.prefix(8))"]
            }
            // 로그인 세션이 없으면 임시 코드 반환 (데모)
            return ["code": "auth_code_\(UUID().uuidString.prefix(8))"]

        case "getUserProfile":
            let user = MockData.currentUser
            var profile: [String: Any] = [
                "userId": user.id.uuidString,
                "nickname": user.nickname,
            ]
            // 권한에 따라 추가 정보 제공
            profile["university"] = user.university
            return profile

        case "getAccessToken":
            if let token = KeychainStore.load(.accessToken) {
                return token
            }
            // 데모용 토큰
            return "mock_access_token_\(Int(Date().timeIntervalSince1970))"

        case "logout":
            // 미니앱에서의 로그아웃은 미니앱 세션만 정리
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "auth.\(action) not found")
        }
    }
}
