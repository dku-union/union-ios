import Foundation
import ComposableArchitecture

// MARK: - Publisher Feature

/// 퍼블리셔 전용 페이지 — "내가 업로드 한 앱" 목록 + 앱별 버전 상세로 navigation.
@Reducer
struct PublisherFeature {

    @Reducer
    enum Path {
        case appDetail(PublisherAppDetailFeature)
    }

    @ObservableState
    struct State {
        var apps: [PublisherMiniApp] = []
        var isLoading = false
        var error: String?
        var path = StackState<Path.State>()
    }

    enum Action {
        case onAppear
        case refresh
        case appTapped(PublisherMiniApp)
        case appsLoaded([PublisherMiniApp])
        case loadFailed(String)
        case logoutTapped
        case path(StackActionOf<Path>)
    }

    @Dependency(\.publisherAppsClient) var client

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear, .refresh:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.error = nil
                return .run { send in
                    do {
                        let apps = try await client.listMyMiniApps()
                        await send(.appsLoaded(apps))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case .appsLoaded(let apps):
                state.isLoading = false
                state.apps = apps
                return .none

            case .loadFailed(let message):
                state.isLoading = false
                state.error = message
                return .none

            case .appTapped(let app):
                state.path.append(
                    .appDetail(PublisherAppDetailFeature.State(miniApp: app))
                )
                return .none

            case .logoutTapped:
                // 부모(AppFeature)가 이 action을 가로채 .logout을 수행한다.
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
