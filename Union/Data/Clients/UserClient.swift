import Foundation
import ComposableArchitecture

// MARK: - User Client (TCA Dependency)

/// 인증된 사용자 본인의 프로필 조회/수정/탈퇴를 담당하는 의존성.
///
/// 백엔드 endpoints:
/// - `GET /api/v1/users/me` — 본인 조회
/// - `PATCH /api/v1/users/me` — 닉네임 수정
/// - `POST /api/v1/users/me/profile-image/upload-url` — GCS 업로드 URL 발급
/// - `PATCH /api/v1/users/me/profile-image` — 업로드한 이미지 URL 확정
/// - `DELETE /api/v1/users/me` — 회원 탈퇴(soft delete)
@DependencyClient
struct UserClient: Sendable {
    var fetchMe: @Sendable () async throws -> UserMeResponse
    var updateNickname: @Sendable (_ nickname: String) async throws -> UserMeResponse
    /// JPEG 데이터를 받아 (업로드 URL 발급 → GCS PUT → URL 확정) 3단계를 수행하고 갱신된 프로필을 반환.
    var changeProfileImage: @Sendable (_ jpegData: Data) async throws -> UserMeResponse
    /// 회원 탈퇴. 성공 시 서버가 토큰/푸시/구독을 정리한다(204).
    var deleteAccount: @Sendable () async throws -> Void
}

// MARK: - Response DTO

struct UserMeResponse: Codable, Sendable, Equatable {
    let id: UUID
    let email: String
    let nickname: String
    let profileImage: String?
    let universityName: String?
    let isVerified: Bool

    func toUserProfile() -> UserProfile {
        UserProfile(
            id: id,
            nickname: nickname,
            university: universityName ?? "",
            department: "",
            isVerified: isVerified,
            profileEmoji: String(nickname.first.map(String.init) ?? "👤"),
            profileImageUrl: profileImage
        )
    }
}

// MARK: - Request / Intermediate DTOs

private struct UpdateNicknameRequest: Encodable {
    let nickname: String
}

private struct ProfileImageUploadUrlRequest: Encodable {
    let filename: String
}

/// Spring `GcsSignedUrlResponseDto` 와 1:1 — 업로드용 signed PUT URL + 업로드 후 공개 URL.
private struct GcsSignedUrlResponse: Decodable {
    let signedUrl: String
    let fileUrl: String
}

private struct UpdateProfileImageRequest: Encodable {
    let imageUrl: String
}

// MARK: - Live

extension UserClient: DependencyKey {
    static let liveValue: UserClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)
        let encoder = JSONEncoder()

        return UserClient(
            fetchMe: {
                try await apiClient.request(.me)
            },
            updateNickname: { nickname in
                let body = try encoder.encode(UpdateNicknameRequest(nickname: nickname))
                return try await apiClient.request(.updateNickname(body: body))
            },
            changeProfileImage: { jpegData in
                // 1) 업로드 URL 발급 (인증)
                let urlBody = try encoder.encode(ProfileImageUploadUrlRequest(filename: "profile.jpg"))
                let signed: GcsSignedUrlResponse = try await apiClient.request(.profileImageUploadUrl(body: urlBody))

                // 2) GCS V4 signed URL 로 직접 PUT. 서명에 content-type 이 포함되지 않으므로
                //    Authorization/x-goog-* 등 추가 헤더는 보내지 않는다. 이미지 MIME 만 설정.
                guard let putURL = URL(string: signed.signedUrl) else { throw UserClientError.invalidUploadURL }
                var put = URLRequest(url: putURL)
                put.httpMethod = "PUT"
                put.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                let (_, putResponse) = try await URLSession.shared.upload(for: put, from: jpegData)
                guard let http = putResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    throw UserClientError.uploadFailed
                }

                // 3) 업로드한 공개 URL 확정 (인증)
                let confirmBody = try encoder.encode(UpdateProfileImageRequest(imageUrl: signed.fileUrl))
                return try await apiClient.request(.updateProfileImage(body: confirmBody))
            },
            deleteAccount: {
                try await apiClient.send(.deleteAccount)
            }
        )
    }()
}

// MARK: - Error

enum UserClientError: LocalizedError, Equatable {
    case invalidUploadURL
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL: "업로드 주소가 올바르지 않습니다"
        case .uploadFailed: "이미지 업로드에 실패했습니다"
        }
    }
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
                profileImage: nil,
                universityName: "단국대학교",
                isVerified: true
            )
        },
        updateNickname: { nickname in
            UserMeResponse(id: UUID(), email: "preview@dankook.ac.kr", nickname: nickname,
                           profileImage: nil, universityName: "단국대학교", isVerified: true)
        },
        changeProfileImage: { _ in
            UserMeResponse(id: UUID(), email: "preview@dankook.ac.kr", nickname: "준",
                           profileImage: "https://example.com/p.jpg", universityName: "단국대학교", isVerified: true)
        },
        deleteAccount: {}
    )
}

extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
