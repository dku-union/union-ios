import Foundation
import ComposableArchitecture

// MARK: - Home Feature (TCA Reducer)

@Reducer
struct HomeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        var banners: [Banner] = []
        var categories: [AppCategory] = []
        var popularApps: [MiniApp] = []
        var newApps: [MiniApp] = []
        var recommendedApps: [MiniApp] = []
        var recentApps: [MiniApp] = []
        var isLoading = false
        var error: String?

        /// 미니앱 실행 기록 (최근 순). 파일에 영속 저장됨.
        @Shared(.launchedAppIds) var launchedAppIds: [Int] = []

        /// 한 번이라도 미니앱을 실행한 적 있는지 여부 → 스켈레톤 최근 사용 섹션 표시 여부에 사용.
        var hasEverLaunchedApp: Bool { !launchedAppIds.isEmpty }
    }

    // MARK: - Action

    enum Action {
        // View actions
        case onAppear
        case refresh
        case appTapped(MiniApp)

        // Internal actions (from Effects)
        case homeDataLoaded(HomeData)
        case loadFailed(String)
    }

    // MARK: - HomeData (batch response)

    struct HomeData: Equatable, Sendable {
        let banners: [Banner]
        let categories: [AppCategory]
        let popularApps: [MiniApp]
        let newApps: [MiniApp]
        let recommendedApps: [MiniApp]
        let recentApps: [MiniApp]
    }

    // MARK: - Dependencies

    @Dependency(\.miniAppClient) var client

    // MARK: - Reducer Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.error = nil
                return .run { send in
                    let data = try await loadHomeData()
                    await send(.homeDataLoaded(data))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case .refresh:
                state.isLoading = true
                state.error = nil
                return .run { send in
                    let data = try await loadHomeData()
                    await send(.homeDataLoaded(data))
                } catch: { error, send in
                    await send(.loadFailed(error.localizedDescription))
                }

            case .appTapped(let app):
                // 실행 기록 저장: 중복 제거 후 최신 순으로 삽입, 최대 100개 유지
                state.$launchedAppIds.withLock { ids in
                    ids.removeAll { $0 == app.id }
                    ids.insert(app.id, at: 0)
                    if ids.count > 100 {
                        ids = Array(ids.prefix(100))
                    }
                }
                return .none

            case .homeDataLoaded(let data):
                state.banners = data.banners
                state.categories = data.categories
                state.popularApps = data.popularApps
                state.newApps = data.newApps
                state.recommendedApps = data.recommendedApps
                state.recentApps = data.recentApps
                state.isLoading = false
                return .none

            case .loadFailed(let message):
                state.error = message
                state.isLoading = false
                return .none
            }
        }
    }

    // MARK: - Private

    private func loadHomeData() async throws -> HomeData {
        async let discovery = client.fetchDiscovery()
        async let banners = client.fetchBanners()

        let disc = try await discovery
        return HomeData(
            banners: try await banners,
            categories: disc.categories,
            popularApps: disc.popularApps,
            newApps: disc.newApps,
            recommendedApps: disc.recommendedApps,
            recentApps: disc.recentApps
        )
    }
}
