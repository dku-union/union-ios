import Foundation
import ComposableArchitecture

// MARK: - Publisher Apps Client (TCA Dependency)

/// 퍼블리셔 전용 페이지에서 사용하는 API 의존성.
///
/// 백엔드 endpoints:
/// - `GET /publishers/me/mini-apps` — 내가 멤버인 모든 워크스페이스의 미니앱
/// - `GET /app-versions/mini-app/{miniAppId}` — 특정 미니앱의 버전 목록
/// - `POST /app-versions/{id}/test-session` — 1회용 테스트 토큰 발급
/// - `GET /app-versions/test-bundle?token=...` — 토큰 redeem → CDN signed URL
///
/// 토큰 자동 주입은 `APIClient` 가 처리한다.
@DependencyClient
struct PublisherAppsClient: Sendable {
    var listMyMiniApps: @Sendable () async throws -> [PublisherMiniApp]
    var listVersions: @Sendable (_ miniAppId: Int) async throws -> [AppVersionInfo]
    var createTestSession: @Sendable (_ versionId: UUID) async throws -> URL
    var redeemTestBundle: @Sendable (_ token: String) async throws -> TestBundleInfo
}

// MARK: - Bundle Info

struct TestBundleInfo: Equatable, Sendable, Decodable {
    let versionId: UUID
    let miniAppId: Int
    let miniAppName: String
    let versionNumber: String
    let bundleUrl: String
}

// MARK: - Errors

enum PublisherAppsError: LocalizedError, Equatable {
    case invalidTestLink
    case bundleUnavailable
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidTestLink: "테스트 링크 형식이 올바르지 않습니다."
        case .bundleUnavailable: "테스트 번들을 가져올 수 없습니다."
        case .server(let code, let m): m ?? "서버 오류가 발생했습니다 (\(code))"
        }
    }
}

// MARK: - Live

extension PublisherAppsClient: DependencyKey {
    static let liveValue: PublisherAppsClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)

        return PublisherAppsClient(
            listMyMiniApps: {
                let endpoint = APIEndpoint(path: "/publishers/me/mini-apps")
                return try await apiClient.request(endpoint)
            },
            listVersions: { miniAppId in
                let endpoint = APIEndpoint(path: "/app-versions/mini-app/\(miniAppId)")
                return try await apiClient.request(endpoint)
            },
            createTestSession: { versionId in
                let endpoint = APIEndpoint(
                    path: "/app-versions/\(versionId.uuidString)/test-session",
                    method: .post
                )
                struct Response: Decodable { let testLink: String }
                let response: Response = try await apiClient.request(endpoint)
                guard let url = URL(string: response.testLink) else {
                    throw PublisherAppsError.invalidTestLink
                }
                return url
            },
            redeemTestBundle: { token in
                let endpoint = APIEndpoint(
                    path: "/app-versions/test-bundle",
                    queryItems: [URLQueryItem(name: "token", value: token)]
                )
                return try await apiClient.request(endpoint)
            }
        )
    }()
}

// MARK: - Test / Preview

extension PublisherAppsClient: TestDependencyKey {
    static let testValue = PublisherAppsClient()

    static let previewValue = PublisherAppsClient(
        listMyMiniApps: {
            [
                PublisherMiniApp(
                    id: 1, name: "단짝", description: "친구 매칭",
                    iconUrl: nil, workspaceName: "Dankook Union",
                    status: .approved, createdAt: Date()
                ),
                PublisherMiniApp(
                    id: 2, name: "택시팟", description: "택시 합승",
                    iconUrl: nil, workspaceName: "Dankook Union",
                    status: .pending, createdAt: Date()
                )
            ]
        },
        listVersions: { _ in
            [
                AppVersionInfo(
                    id: UUID(), miniAppId: 1, miniAppName: "단짝",
                    publisherNickname: "송준서", versionNumber: "1.0.1",
                    releaseNotes: "버그 수정", status: .inReview,
                    buildFileUrl: "mini-apps/.../1.0.1.unionapp", bundleSize: 1_245_000,
                    testedAt: nil, createdAt: Date(), updatedAt: Date()
                ),
                AppVersionInfo(
                    id: UUID(), miniAppId: 1, miniAppName: "단짝",
                    publisherNickname: "송준서", versionNumber: "1.0.0",
                    releaseNotes: "최초 배포", status: .deployed,
                    buildFileUrl: "mini-apps/.../1.0.0.unionapp", bundleSize: 1_100_000,
                    testedAt: Date(), createdAt: Date(), updatedAt: Date()
                )
            ]
        },
        createTestSession: { _ in
            URL(string: "union-app://test-app?token=preview-token")!
        },
        redeemTestBundle: { _ in
            TestBundleInfo(
                versionId: UUID(), miniAppId: 1, miniAppName: "단짝",
                versionNumber: "1.0.1",
                bundleUrl: "https://cdn.example.com/sample.unionapp?Expires=0"
            )
        }
    )
}

extension DependencyValues {
    var publisherAppsClient: PublisherAppsClient {
        get { self[PublisherAppsClient.self] }
        set { self[PublisherAppsClient.self] = newValue }
    }
}
