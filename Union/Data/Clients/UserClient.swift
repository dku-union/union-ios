import Foundation
import ComposableArchitecture

// MARK: - User Client (TCA Dependency)

/// 인증된 사용자 본인의 프로필 조회를 담당하는 의존성.
///
/// 백엔드 endpoints:
/// - `GET /api/v1/users/me` — Bearer JWT 필수, JwtUserPrincipal 기반 본인 조회
@DependencyClient
struct UserClient: Sendable {
    var fetchMe: @Sendable () async throws -> UserMeResponse
}

// MARK: - Response DTO

struct UserMeResponse: Codable, Sendable, Equatable {
    let id: UUID
    let email: String
    let nickname: String
    let universityName: String?
    let isVerified: Bool

    /// 백엔드 응답에 없는 필드는 iOS 측에서 폴백 처리.
    /// User 스키마 변경(department/profile_emoji)은 별도 백엔드 작업 항목.
    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            nickname: nickname,
            university: universityName ?? "",
            department: "",
            isVerified: isVerified,
            profileEmoji: String(nickname.first.map(String.init) ?? "👤")
        )
    }
}

// MARK: - Live

extension UserClient: DependencyKey {
    static let liveValue: UserClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)
        return UserClient(
            fetchMe: {
                try await apiClient.request(.me)
            }
        )
    }()
}

// MARK: - Test / Preview

extension UserClient: TestDependencyKey {
    static let testValue = UserClient()

    static let previewValue = UserClient(
        fetchMe: {
            UserMeResponse(
                id: UUID(),
                email: "preview@dankook.ac.kr",
                nickname: "준",
                universityName: "단국대학교",
                isVerified: true
            )
        }
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
