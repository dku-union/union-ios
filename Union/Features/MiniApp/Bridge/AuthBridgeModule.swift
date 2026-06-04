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
            // 인증된 세션이 있으면 /api/v1/users/me 응답을 반환,
            // 실패 시 Keychain 토큰 기반 익명 식별자로 폴백 (데모 호환).
            if let me = try? await UserClient.liveValue.fetchMe() {
                var profile: [String: Any] = [
                    "userId": me.id.uuidString,
                    "nickname": me.nickname,
                ]
                // email/university 는 BridgeHandler 가 user.email / user.university 권한에 따라
                // 응답에서 필드 단위로 제거한다(미허용 시 stripping).
                if !me.email.isEmpty {
                    profile["email"] = me.email
                }
                if let university = me.universityName, !university.isEmpty {
                    profile["university"] = university
                }
                return profile
            }
            let fallbackId = KeychainStore.load(.accessToken).map { "anon_\($0.prefix(8))" } ?? "anon_unknown"
            return [
                "userId": fallbackId,
                "nickname": "Guest",
            ]

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
