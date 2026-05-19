import Foundation
import ComposableArchitecture

// MARK: - MiniApp Client (TCA Dependency)

@DependencyClient
struct MiniAppClient: Sendable {
    var fetchDiscovery: @Sendable () async throws -> DiscoveryData
    var fetchBanners: @Sendable () async throws -> [Banner]
    /// 명시적 검색 제출(키보드 Enter) — Redis 인기 검색어 집계 포함.
    var searchApps: @Sendable (_ query: String) async throws -> [MiniApp]
    /// 타이핑 중 실시간 미리보기 — 자음/모음 단위 매칭, 집계 없음.
    var searchAppsPreview: @Sendable (_ query: String) async throws -> [MiniApp]
    /// 검색 결과 클릭 트래킹 (fire-and-forget). 인기 검색어 점수에 keyword + appName 반영.
    var recordSearchClick: @Sendable (_ keyword: String?, _ appName: String) async throws -> Void
}

/// Discovery API 응답을 매핑한 도메인 데이터
struct DiscoveryData: Equatable, Sendable, Codable {
    let popularApps: [MiniApp]
    let newApps: [MiniApp]
    let recommendedApps: [MiniApp]
    let recentApps: [MiniApp]
    let categories: [AppCategory]
    let trendingKeywords: [String]
}

// MARK: - Live (API + Cache)

extension MiniAppClient: DependencyKey {
    static let liveValue: MiniAppClient = {
        let cache = QueryCache()
        let apiClient = APIClient(baseURL: APIConfig.baseURL)

        return MiniAppClient(
            fetchDiscovery: {
                try await cache.query(key: "discovery", staleTime: 300) {
                    let response: DiscoveryResponse = try await apiClient.request(.discovery)
                    return DiscoveryData(
                        popularApps: response.popularApps.map { $0.toMiniApp() },
                        newApps: response.newApps.map { $0.toMiniApp() },
                        recommendedApps: response.recommendedApps.map { $0.toMiniApp() },
                        recentApps: response.recentApps.map { $0.toMiniApp() },
                        categories: response.categories.map { $0.toAppCategory() },
                        trendingKeywords: response.trendingKeywords
                    )
                }
            },
            fetchBanners: {
                try await cache.query(key: "banners", staleTime: 600) {
                    let response: [BannerResponse] = try await apiClient.requestWithoutAuth(.banners)
                    return response.map { $0.toBanner() }
                }
            },
            searchApps: { query in
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }
                let response: [MiniAppLiteResponse] = try await apiClient.requestWithoutAuth(
                    .miniAppSearch(keyword: trimmed)
                )
                return response.map { $0.toMiniApp() }
            },
            searchAppsPreview: { query in
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [] }
                let response: [MiniAppLiteResponse] = try await apiClient.requestWithoutAuth(
                    .miniAppSearchPreview(keyword: trimmed)
                )
                return response.map { $0.toMiniApp() }
            },
            recordSearchClick: { keyword, appName in
                try await apiClient.sendWithoutAuth(
                    .recordSearchClick(keyword: keyword, appName: appName)
                )
            }
        )
    }()
}

// MARK: - Test / Preview

extension MiniAppClient: TestDependencyKey {
    static let testValue = MiniAppClient()

    static let previewValue = MiniAppClient(
        fetchDiscovery: {
            DiscoveryData(
                popularApps: MockData.popularApps,
                newApps: MockData.newApps,
                recommendedApps: Array(MockData.allApps.prefix(5)),
                recentApps: MockData.recentApps,
                categories: MockData.categories,
                trendingKeywords: ["축제", "웨이팅", "스터디", "학식"]
            )
        },
        fetchBanners: { MockData.banners },
        searchApps: { _ in MockData.allApps },
        searchAppsPreview: { q in
            let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty else { return [] }
            return MockData.allApps.filter {
                $0.name.lowercased().contains(trimmed) ||
                $0.description.lowercased().contains(trimmed)
            }
        },
        recordSearchClick: { _, _ in }
    )
}

extension DependencyValues {
    var miniAppClient: MiniAppClient {
        get { self[MiniAppClient.self] }
        set { self[MiniAppClient.self] = newValue }
    }
}
