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
        var categories: [AppCategory] = []
        var trendingKeywords: [String] = []
        var didLoadDiscovery = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        /// 타이핑 디바운스 만료 후 발행되는 내부 액션 — 실시간 미리보기 호출.
        case runPreview(query: String)
        /// 키보드 Enter 등 사용자가 명시적으로 검색 제출 — 인기 검색어 집계 포함 full search.
        case submitSearch
        /// 검색 결과 카드 탭 — fire-and-forget 으로 클릭 트래킹 전송.
        /// 미니앱 실행 자체는 MiniAppCardHorizontal 의 NavigationLink 가 처리.
        case resultTapped(MiniApp)
        case searchResultLoaded([MiniApp])
        case discoveryLoaded(categories: [AppCategory], trendingKeywords: [String])
    }

    @Dependency(\.miniAppClient) var client
    @Dependency(\.continuousClock) var clock

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didLoadDiscovery else { return .none }
                state.didLoadDiscovery = true
                return .run { send in
                    let discovery = try await client.fetchDiscovery()
                    await send(.discoveryLoaded(
                        categories: discovery.categories,
                        trendingKeywords: discovery.trendingKeywords
                    ))
                } catch: { _, _ in
                    // discovery 실패는 silent — empty state 폴백
                }

            case .binding(\.query):
                // 공백만 입력된 경우도 비검색 상태로 취급 — 결과 클리어 + in-flight 모두 취소.
                let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    state.results = []
                    state.isSearching = false
                    return .merge(
                        .cancel(id: CancelID.debounce),
                        .cancel(id: CancelID.preview),
                        .cancel(id: CancelID.submit)
                    )
                }
                // Debounce 300ms — 타이핑이 계속되면 cancelInFlight으로 이전 타이머 취소되고 새로 시작.
                return .run { send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.runPreview(query: trimmed))
                }
                .cancellable(id: CancelID.debounce, cancelInFlight: true)

            case .binding:
                return .none

            case .runPreview(let query):
                state.isSearching = true
                return .run { send in
                    let apps = try await client.searchAppsPreview(query)
                    await send(.searchResultLoaded(apps))
                } catch: { _, send in
                    await send(.searchResultLoaded([]))
                }
                .cancellable(id: CancelID.preview, cancelInFlight: true)

            case .submitSearch:
                let trimmed = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return .none }
                state.isSearching = true
                // 제출 시점 — 대기 중인 디바운스/미리보기 모두 취소 후 full search 단일 경로로.
                return .merge(
                    .cancel(id: CancelID.debounce),
                    .cancel(id: CancelID.preview),
                    .run { send in
                        let apps = try await client.searchApps(trimmed)
                        await send(.searchResultLoaded(apps))
                    } catch: { _, send in
                        await send(.searchResultLoaded([]))
                    }
                    .cancellable(id: CancelID.submit, cancelInFlight: true)
                )

            case .resultTapped(let app):
                let keyword = state.query.trimmingCharacters(in: .whitespacesAndNewlines)
                let kw: String? = keyword.isEmpty ? nil : keyword
                return .run { _ in
                    try? await client.recordSearchClick(kw, app.name)
                }

            case .searchResultLoaded(let apps):
                state.results = apps
                state.isSearching = false
                return .none

            case .discoveryLoaded(let categories, let trendingKeywords):
                state.categories = categories
                state.trendingKeywords = trendingKeywords
                return .none
            }
        }
    }

    private enum CancelID { case debounce, preview, submit }
}
