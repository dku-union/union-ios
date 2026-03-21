import Foundation
import ComposableArchitecture

// MARK: - MiniApp Client (TCA Dependency)

@DependencyClient
struct MiniAppClient: Sendable {
    var fetchPopularApps: @Sendable () async throws -> [MiniApp]
    var fetchNewApps: @Sendable () async throws -> [MiniApp]
    var fetchRecommendedApps: @Sendable () async throws -> [MiniApp]
    var fetchRecentApps: @Sendable () async throws -> [MiniApp]
    var fetchCategories: @Sendable () async throws -> [AppCategory]
    var fetchBanners: @Sendable () async throws -> [Banner]
    var searchApps: @Sendable (_ query: String) async throws -> [MiniApp]
}

// MARK: - Live (API + Cache)

extension MiniAppClient: DependencyKey {
    static let liveValue: MiniAppClient = {
        let cache = QueryCache()

        return MiniAppClient(
            fetchPopularApps: {
                try await cache.query(key: "popular_apps", staleTime: 300) {
                    // TODO: Replace with actual API call
                    // let client = APIClient()
                    // return try await client.request(.popularApps)
                    return MockData.popularApps
                }
            },
            fetchNewApps: {
                try await cache.query(key: "new_apps", staleTime: 300) {
                    return MockData.newApps
                }
            },
            fetchRecommendedApps: {
                try await cache.query(key: "recommended_apps", staleTime: 600) {
                    return MockData.recommendedApps
                }
            },
            fetchRecentApps: {
                return MockData.recentApps
            },
            fetchCategories: {
                try await cache.query(key: "categories", staleTime: 3600) {
                    return MockData.categories
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
        fetchPopularApps: { MockData.popularApps },
        fetchNewApps: { MockData.newApps },
        fetchRecommendedApps: { MockData.recommendedApps },
        fetchRecentApps: { MockData.recentApps },
        fetchCategories: { MockData.categories },
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
