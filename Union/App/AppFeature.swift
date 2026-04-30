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
        /// 외부 URL(예: union-app://test-app?versionId=...) 진입 처리
        case openURL(URL)
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

            // Publisher 로그인 성공 → 우선 isLoggedIn 처리만 (post-login 라우팅은 후속 작업)
            case .auth(.path(.element(_, action: .publisherLoginCode(.loginSucceeded)))):
                state.isLoggedIn = true
                state.auth.path.removeAll()
                return .none

            case .openURL(let url):
                guard let context = parsePublisherTestURL(url) else {
                    return .none
                }
                // 로그인 상태와 무관하게 publisher 인증으로 진입.
                // (이미 publisher로 로그인되어 있어도 컨텍스트를 명시적으로 다시 받기 위함.
                //  post-login 자동 진입은 후속 작업.)
                state.isLoggedIn = false
                return .send(.auth(.publisherLoginRequested(context)))

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

    // MARK: - URL Scheme Parsing

    /// `union-app://test-app?token=<uuid>` 형식을 파싱한다.
    ///
    /// 백엔드(`/app-versions/{id}/test-session`)가 발급하는 표준 형태:
    /// - scheme = `union-app`
    /// - host   = `test-app` (고정 sentinel — appId 아님)
    /// - query  = `token` (권장) 또는 `versionId` (deprecated)
    ///
    /// 토큰이 있으면 redeem 가능, 없으면 legacy 링크로 인식만 하고 redeem 불가.
    private func parsePublisherTestURL(_ url: URL) -> PublisherTestContext? {
        guard url.scheme == "union-app" else { return nil }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let token = components?.queryItems?.first(where: { $0.name == "token" })?.value
        let legacyVersionId = components?.queryItems?.first(where: { $0.name == "versionId" })?.value

        guard token != nil || legacyVersionId != nil else { return nil }

        return PublisherTestContext(token: token, legacyVersionId: legacyVersionId)
    }
}
