import Foundation
import ComposableArchitecture

// MARK: - Search Feature (TCA Reducer)

@Reducer
struct SearchFeature {

    @ObservableState
    struct State: Equatable {
        var query = ""
        var results: [MiniApp] = []
        var isSearching = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case search
        case searchResultLoaded([MiniApp])
    }

    @Dependency(\.miniAppClient) var client
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.query):
                // Debounce: 0.3s after typing stops
                guard !state.query.isEmpty else {
                    state.results = []
                    return .cancel(id: CancelID.search)
                }
                return .run { [query = state.query] send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.search)
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .binding:
                return .none

            case .search:
                state.isSearching = true
                return .run { [query = state.query] send in
                    let apps = try await client.searchApps(query)
                    await send(.searchResultLoaded(apps))
                } catch: { _, send in
                    await send(.searchResultLoaded([]))
                }

            case .searchResultLoaded(let apps):
                state.results = apps
                state.isSearching = false
                return .none
            }
        }
    }

    private enum CancelID { case search }
}
