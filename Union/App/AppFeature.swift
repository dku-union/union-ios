import Foundation
import ComposableArchitecture

// MARK: - App Root Feature (Auth 분기)

@Reducer
struct AppFeature {

    private enum CancelID { case sessionObserver }

    @ObservableState
    struct State {
        var isLoggedIn = KeychainStore.isLoggedIn
        var auth = AuthFeature.State()
        var home = HomeFeature.State()
        var search = SearchFeature.State()
    }

    enum Action {
        case auth(AuthFeature.Action)
        case home(HomeFeature.Action)
        case search(SearchFeature.Action)
        case onAppear
        case checkAuth
        case sessionValid
        case sessionExpired
        case logout
    }

    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) { AuthFeature() }
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.search, action: \.search) { SearchFeature() }

        Reduce { state, action in
            switch action {
            case .onAppear:
                // 세션 만료 Notification 리스너 (로그인 상태와 무관하게 항상 활성)
                // — API 호출 중 TokenProvider가 세션 만료를 감지하면 여기로 전달됨
                let observeEffect: Effect<Action> = .run { send in
                    for await _ in NotificationCenter.default.notifications(
                        named: TokenProvider.sessionExpiredNotification
                    ) {
                        await send(.sessionExpired)
                    }
                }
                .cancellable(id: CancelID.sessionObserver)

                guard KeychainStore.isLoggedIn else {
                    state.isLoggedIn = false
                    return observeEffect
                }

                // 토큰 유효성 확인 (만료 임박 시 proactive refresh 수행)
                let validateEffect: Effect<Action> = .run { send in
                    do {
                        _ = try await TokenProvider.shared.validAccessToken()
                        await send(.sessionValid)
                    } catch {
                        await send(.sessionExpired)
                    }
                }

                return .merge(validateEffect, observeEffect)

            case .sessionValid:
                state.isLoggedIn = true
                return .none

            case .sessionExpired:
                KeychainStore.clearAll()
                state.isLoggedIn = false
                return .none

            // 로그인/회원가입 성공 → 메인으로 전환
            case .auth(.path(.element(_, action: .login(.loginSucceeded)))):
                state.isLoggedIn = true
                state.auth.path.removeAll()
                return .none

            case .auth(.path(.element(_, action: .signUpCode(.signUpCompleted)))):
                state.isLoggedIn = true
                state.auth.path.removeAll()
                return .none

            case .checkAuth:
                state.isLoggedIn = KeychainStore.isLoggedIn
                return .none

            case .logout:
                KeychainStore.clearAll()
                state.isLoggedIn = false
                state.auth = AuthFeature.State()
                return .none

            case .auth, .home, .search:
                return .none
            }
        }
    }
}
