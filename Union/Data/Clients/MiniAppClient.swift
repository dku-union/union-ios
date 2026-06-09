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
                var data = try await cache.query(key: "discovery", staleTime: 300) {
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
                #if DEBUG
                data = MiniAppClient.injectDevApp(into: data)
                #endif
                return data
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

#if DEBUG
private extension MiniAppClient {
    /// DEBUG 빌드에서 discovery 결과 맨 앞에 로컬 개발 서버 택시팟을 주입한다.
    /// TAXIPOT_DEV_URL 환경변수로 포트 재정의 가능 (Scheme → Run → Environment Variables).
    static func injectDevApp(into data: DiscoveryData) -> DiscoveryData {
        let devURL = ProcessInfo.processInfo.environment["TAXIPOT_DEV_URL"]
            ?? "https://storage.googleapis.com/union-app-miniapps/mini-apps/66d1bf78-29b5-45d8-bba7-f08f88bffa23/20260609/com.union.taxi-pot-1.0.2.unionapp"

        // 모든 섹션에서 실제 택시팟 찾기 — 백엔드 ID를 재사용해야 id-token 엔드포인트가 동작함
        let allApps = data.popularApps + data.newApps + data.recommendedApps + data.recentApps
        guard let real = allApps.first(where: {
            $0.appId == "com.union.taxipot" || $0.appId == "com.union.taxi-pot"
        }) else { return data }

        let devApp = MiniApp(
            id: real.id,
            name: "🛠 \(real.name) (dev)", description: devURL,
            publisher: real.publisher, category: real.category,
            iconUrl: nil, iconEmoji: real.iconEmoji ?? "🚕", iconColorHex: "FF6060",
            rating: real.rating, ratingCount: real.ratingCount,
            isNew: false, isPopular: false, createdAt: Date.distantPast,
            webUrl: devURL, appId: real.appId
        )

        // 원본 제거 후 dev 버전을 popularApps 맨 앞에 삽입
        return DiscoveryData(
            popularApps: [devApp] + data.popularApps.filter { $0.id != real.id },
            newApps: data.newApps.filter { $0.id != real.id },
            recommendedApps: data.recommendedApps.filter { $0.id != real.id },
            recentApps: data.recentApps,
            categories: data.categories,
            trendingKeywords: data.trendingKeywords
        )
    }
}
#endif

extension DependencyValues {
    var miniAppClient: MiniAppClient {
        get { self[MiniAppClient.self] }
        set { self[MiniAppClient.self] = newValue }
    }
}
