import Foundation
import ComposableArchitecture

// MARK: - MiniApp Permission Client (TCA Dependency)

/// 미니앱별 사용자 권한 결정 API.
///
/// 백엔드 endpoints:
/// - `GET  /api/v1/users/me/miniapps/{id}/permissions` — 선언 권한 + 사용자 결정
/// - `PUT  /api/v1/users/me/miniapps/{id}/permissions` — 결정 배치 업서트
/// - `GET  /api/v1/users/me/permissions` — 전체 결정 목록 (권한 관리)
@DependencyClient
struct MiniAppPermissionClient: Sendable {
    /// 특정 미니앱의 선언 권한 + 사용자 결정 조회 (최초 접속 게이트).
    var fetch: @Sendable (_ miniAppId: Int) async throws -> MiniAppPermissionState
    /// 권한 결정 배치 업서트 → 갱신된 상태 반환.
    var submit: @Sendable (_ miniAppId: Int, _ decisions: [PermissionScope: Bool]) async throws -> MiniAppPermissionState
    /// 사용자 전체 권한 결정 목록 (권한 관리 화면).
    var fetchAll: @Sendable () async throws -> [MiniAppPermissionGroup]
}

// MARK: - Live (API)

extension MiniAppPermissionClient: DependencyKey {
    static let liveValue: MiniAppPermissionClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)
        let encoder = JSONEncoder()

        return MiniAppPermissionClient(
            fetch: { miniAppId in
                try await apiClient.request(.miniAppPermissions(id: miniAppId))
            },
            submit: { miniAppId, decisions in
                let body = try encoder.encode(UpdatePermissionsRequest(
                    decisions: decisions.map {
                        PermissionDecisionRequest(scope: $0.key.rawValue, granted: $0.value)
                    }
                ))
                return try await apiClient.request(.updateMiniAppPermissions(id: miniAppId, body: body))
            },
            fetchAll: {
                try await apiClient.request(.allMiniAppPermissions)
            }
        )
    }()
}

// MARK: - Test / Preview

extension MiniAppPermissionClient: TestDependencyKey {
    static let testValue = MiniAppPermissionClient()

    static let previewValue = MiniAppPermissionClient(
        fetch: { id in
            MiniAppPermissionState(
                miniAppId: id,
                appId: "com.union.preview",
                permissions: [
                    PermissionItem(scope: "user.profile", hasDecision: false, granted: false),
                    PermissionItem(scope: "device.location", hasDecision: false, granted: false),
                    PermissionItem(scope: "notification", hasDecision: false, granted: false),
                ]
            )
        },
        submit: { id, decisions in
            MiniAppPermissionState(
                miniAppId: id,
                appId: "com.union.preview",
                permissions: decisions.map {
                    PermissionItem(scope: $0.key.rawValue, hasDecision: true, granted: $0.value)
                }
            )
        },
        fetchAll: { [] }
    )
}

extension DependencyValues {
    var miniAppPermissionClient: MiniAppPermissionClient {
        get { self[MiniAppPermissionClient.self] }
        set { self[MiniAppPermissionClient.self] = newValue }
    }
}
