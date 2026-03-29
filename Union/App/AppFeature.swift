import Foundation
import ComposableArchitecture

// MARK: - App Root Feature (Auth 분기)

@Reducer
struct AppFeature {

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

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) { AuthFeature() }
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.search, action: \.search) { SearchFeature() }

        Reduce { state, action in
            switch action {
            // 앱 시작 시 토큰 유효성 확인
            case .onAppear:
                guard KeychainStore.isLoggedIn else {
                    state.isLoggedIn = false
                    return .none
                }
                // refresh token으로 새 토큰 발급 시도
                return .run { send in
                    guard let refreshToken = KeychainStore.load(.refreshToken) else {
                        await send(.sessionExpired)
                        return
                    }
                    do {
                        _ = try await authClient.refresh(refreshToken)
                        await send(.sessionValid)
                    } catch {
                        await send(.sessionExpired)
                    }
                }

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
