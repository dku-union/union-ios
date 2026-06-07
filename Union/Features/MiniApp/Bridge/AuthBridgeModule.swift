import Foundation

// MARK: - Auth Bridge Module
// SDK: Union.auth.login(), getUserProfile(), getIdToken(), getAccessToken(), logout()

/// 미니앱 ID 토큰 발급 응답 (POST /mini-apps/{id}/id-token)
private struct IdTokenResponse: Decodable {
    let idToken: String
    let tokenType: String?
    let expiresIn: Int?
}

@MainActor
final class AuthBridgeModule {

    private let miniAppId: Int
    /// 발급받은 ID 토큰 캐시. 만료 임박 전까지 재사용한다.
    private var cachedIdToken: String?

    init(miniAppId: Int) {
        self.miniAppId = miniAppId
    }

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

        case "getIdToken", "getAccessToken":
            // getAccessToken 은 하위호환 alias — 더 이상 세션 토큰이 아니라 이 미니앱(appId)에
            // 스코프된 ID 토큰을 반환한다. 사용자의 Union 세션 토큰은 미니앱에 노출하지 않는다.
            return try await idToken()

        case "logout":
            // 미니앱에서의 로그아웃은 미니앱 세션(캐시된 ID 토큰)만 정리
            cachedIdToken = nil
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "auth.\(action) not found")
        }
    }

    /// 이 미니앱에 스코프된 사용자 ID 토큰. 캐시가 없거나 60초 내 만료 예정이면 백엔드에서 재발급한다.
    /// 백엔드 호출은 사용자 세션(APIClient 가 자동 주입)으로 인증되지만, 그 세션 토큰 자체는 반환되지 않는다.
    private func idToken() async throws -> String {
        if let token = cachedIdToken,
           let payload = JWTDecoder.decode(token),
           !payload.isExpiring(within: 60) {
            return token
        }

        let client = APIClient(baseURL: APIConfig.baseURL)
        let response: IdTokenResponse = try await client.request(.miniAppIdToken(id: miniAppId))
        cachedIdToken = response.idToken
        return response.idToken
    }
}
