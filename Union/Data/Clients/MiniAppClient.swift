import Foundation
import ComposableArchitecture

// MARK: - MiniApp Client (TCA Dependency)

@DependencyClient
struct MiniAppClient: Sendable {
    var fetchDiscovery: @Sendable () async throws -> DiscoveryData
    var fetchBanners: @Sendable () async throws -> [Banner]
    var searchApps: @Sendable (_ query: String) async throws -> [MiniApp]
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
                    return MockData.banners
                }
            },
            searchApps: { query in
                return MockData.allApps.filter {
                    $0.name.localizedCaseInsensitiveContains(query) ||
                    $0.description.localizedCaseInsensitiveContains(query)
                }
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
        searchApps: { _ in MockData.allApps }
    )
}

extension DependencyValues {
    var miniAppClient: MiniAppClient {
        get { self[MiniAppClient.self] }
        set { self[MiniAppClient.self] = newValue }
    }
}
