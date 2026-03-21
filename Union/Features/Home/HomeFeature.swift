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
    }

    // MARK: - Action

    enum Action {
        // View actions
        case onAppear
        case refresh

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
        async let banners = client.fetchBanners()
        async let categories = client.fetchCategories()
        async let popular = client.fetchPopularApps()
        async let new = client.fetchNewApps()
        async let recommended = client.fetchRecommendedApps()
        async let recent = client.fetchRecentApps()

        return try await HomeData(
            banners: banners,
            categories: categories,
            popularApps: popular,
            newApps: new,
            recommendedApps: recommended,
            recentApps: recent
        )
    }
}
