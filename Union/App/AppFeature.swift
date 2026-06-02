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
        var publisher = PublisherFeature.State()
        var notifications = NotificationsFeature.State()
        /// 현재 access token 의 role claim (UI 분기용 - publisher 탭 노출 결정).
        /// 로그인 직후/세션 만료 시 갱신된다.
        var role: String? = JWTDecoder.currentRole()

        /// 스킴으로 진입했지만 아직 redeem 되지 않은 테스트 컨텍스트.
        /// 로그인 단계가 끝나면 자동으로 redeem 한다.
        var pendingTestContext: PublisherTestContext?
        /// redeem 완료 후 fullScreenCover 로 표시되는 테스트 WebView 상태.
        var runningTest: TestRun?
        var testRedeemError: String?

        /// JWT의 role 이 ROLE_PUBLISHER 또는 ROLE_ADMIN 인지 — publisher 전용 탭 노출 여부.
        var isPublisher: Bool {
            switch role {
            case "ROLE_PUBLISHER", "ROLE_ADMIN": true
            default: false
            }
        }
    }

    /// 스킴 진입으로 만들어진 테스트 실행 — 합성 MiniApp + 표시용 버전 번호.
    struct TestRun: Equatable {
        let miniApp: MiniApp
        let versionNumber: String
    }

    enum Action {
        case auth(AuthFeature.Action)
        case home(HomeFeature.Action)
        case search(SearchFeature.Action)
        case publisher(PublisherFeature.Action)
        case notifications(NotificationsFeature.Action)
        case onAppear
        case checkAuth
        case sessionValid
        case sessionExpired
        case logout
        /// 외부 URL(예: union-app://test-app?token=<uuid>) 진입 처리
        case openURL(URL)
        /// `pendingTestContext`를 이용해 테스트 번들을 redeem 하고 WebView 표시까지 진행
        case redeemPendingTest
        case testRedeemed(TestBundleInfo)
        case testRedeemFailed(String)
        case dismissRunningTest
        case dismissTestRedeemError
    }

    @Dependency(\.publisherAppsClient) var publisherAppsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) { AuthFeature() }
        Scope(state: \.home, action: \.home) { HomeFeature() }
        Scope(state: \.search, action: \.search) { SearchFeature() }
        Scope(state: \.publisher, action: \.publisher) { PublisherFeature() }
        Scope(state: \.notifications, action: \.notifications) { NotificationsFeature() }

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

                // 푸시 알림 권한 요청 + APNs 등록 (앱 첫 진입 시 즉시)
                let pushBootstrap: Effect<Action> = .run { _ in
                    await PushNotificationCoordinator.bootstrap()
                }

                guard KeychainStore.isLoggedIn else {
                    state.isLoggedIn = false
                    return .merge(observeEffect, pushBootstrap)
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

                return .merge(validateEffect, observeEffect, pushBootstrap)

            case .sessionValid:
                state.isLoggedIn = true
                state.role = JWTDecoder.currentRole()
                // 세션 확정 직후 — 이미 받아둔 FCM 토큰이 있으면 서버에 재등록 (이전에 401이었을 가능성).
                return reRegisterPushToken()

            case .sessionExpired:
                KeychainStore.clearAll()
                state.isLoggedIn = false
                state.role = nil
                return .none

            // 로그인/회원가입 성공 → 메인으로 전환
            case .auth(.path(.element(_, action: .login(.loginSucceeded)))):
                state.isLoggedIn = true
                state.role = JWTDecoder.currentRole()
                state.auth.path.removeAll()
                // 로그인 직후 — 미로그인 상태에서 401 로 실패했던 FCM 토큰 등록을 재시도.
                return reRegisterPushToken()

            case .auth(.path(.element(_, action: .signUpCode(.signUpCompleted)))):
                state.isLoggedIn = true
                state.role = JWTDecoder.currentRole()
                state.auth.path.removeAll()
                return reRegisterPushToken()

            // Publisher 로그인 성공 → isLoggedIn 처리 후, 스킴으로 들어온 컨텍스트가 있으면 자동 redeem.
            case .auth(.path(.element(_, action: .publisherLoginCode(.loginSucceeded)))):
                state.isLoggedIn = true
                state.role = JWTDecoder.currentRole()
                state.auth.path.removeAll()
                if state.pendingTestContext?.isRedeemable == true {
                    return .merge(reRegisterPushToken(), .send(.redeemPendingTest))
                }
                return reRegisterPushToken()

            case .openURL(let url):
                guard let context = parsePublisherTestURL(url) else {
                    return .none
                }
                // 이미 publisher(또는 admin)로 로그인된 상태면 재로그인 없이 즉시 redeem.
                if state.isLoggedIn, state.isPublisher, context.isRedeemable {
                    state.pendingTestContext = context
                    return .send(.redeemPendingTest)
                }
                // 미로그인 또는 일반 사용자 → publisher 로그인부터 진행.
                // 로그인 완료 시 위 case 가 redeem 까지 이어준다.
                state.pendingTestContext = context
                state.isLoggedIn = false
                return .send(.auth(.publisherLoginRequested(context)))

            case .redeemPendingTest:
                guard let token = state.pendingTestContext?.token else {
                    state.pendingTestContext = nil
                    return .none
                }
                state.pendingTestContext = nil
                return .run { send in
                    do {
                        let bundle = try await publisherAppsClient.redeemTestBundle(token: token)
                        await send(.testRedeemed(bundle))
                    } catch {
                        await send(.testRedeemFailed(error.localizedDescription))
                    }
                }

            case .testRedeemed(let bundle):
                let synthetic = MiniApp(
                    id: bundle.miniAppId,
                    name: bundle.miniAppName,
                    description: "",
                    publisher: "테스트 빌드",
                    category: "test",
                    iconUrl: nil,
                    iconEmoji: nil,
                    iconColorHex: nil,
                    rating: 0,
                    ratingCount: 0,
                    isNew: false,
                    isPopular: false,
                    createdAt: Date(),
                    webUrl: bundle.bundleUrl,
                    // 정식 미니앱의 appId 를 그대로 사용 — Bridge `notification` 모듈이
                    // subscribe/unsubscribe 등 appId 기반 기능을 테스트 빌드에서도 수행할 수 있다.
                    appId: bundle.appId
                )
                state.runningTest = TestRun(miniApp: synthetic, versionNumber: bundle.versionNumber)
                // 테스트가 실제로 시작되는 시점에 testedAt 마크 → dashboard "심사 요청" 활성화.
                // 실패해도 사용자 흐름엔 영향 없도록 fire-and-forget.
                let versionId = bundle.versionId
                return .run { _ in
                    try? await publisherAppsClient.markTested(versionId: versionId)
                }

            case .testRedeemFailed(let message):
                state.testRedeemError = message
                return .none

            case .dismissRunningTest:
                state.runningTest = nil
                return .none

            case .dismissTestRedeemError:
                state.testRedeemError = nil
                return .none

            case .checkAuth:
                state.isLoggedIn = KeychainStore.isLoggedIn
                return .none

            case .logout:
                // 1) 토큰(Access/Refresh) 즉시 폐기 — TokenProvider 가 사용 중이던
                //    refresh Task 가 있다면 다음 호출에서 noRefreshToken 으로 떨어진다.
                KeychainStore.clearAll()

                // 2) 사용자에 묶인 로컬 히스토리(@Shared 파일) 비우기.
                //    fresh State 로 교체하기 전에 기존 @Shared 핸들로 비워야 디스크에도 반영된다.
                state.home.$launchedAppIds.withLock { $0 = [] }

                // 3) TCA state 전반 리셋 — 캐시된 응답/검색어/내비게이션 스택을 모두 폐기.
                state.isLoggedIn = false
                state.role = nil
                state.pendingTestContext = nil
                state.runningTest = nil
                state.testRedeemError = nil
                state.auth = AuthFeature.State()
                state.home = HomeFeature.State()
                state.search = SearchFeature.State()
                state.publisher = PublisherFeature.State()

                // 4) 미니앱 WebView 들이 남긴 쿠키/LocalStorage 등 영속 데이터 삭제.
                return .run { _ in
                    await SessionCleaner.purgeWebViewData()
                }

            // PublisherView 의 로그아웃 버튼 → AppFeature.logout 으로 위임
            case .publisher(.logoutTapped):
                return .send(.logout)

            // PublisherView 의 More → QR 스캔 결과 → 기존 .openURL 파이프라인으로 위임
            case .publisher(.qrScanned(let url)):
                return .send(.openURL(url))

            case .auth, .home, .search, .publisher, .notifications:
                return .none
            }
        }
    }

    // MARK: - Push Token Re-registration

    /// 캐시된 푸시 토큰(FCM)을 서버에 재등록하는 Effect.
    /// 로그인 전 401 로 실패했던 토큰을 로그인/세션 확정 시점에 다시 등록한다.
    private func reRegisterPushToken() -> Effect<Action> {
        guard let token = DevicePushTokenStore.shared.current() else { return .none }
        return .run { _ in
            try? await NotificationClient.liveValue.registerDeviceToken(
                DeviceIdentity.deviceId,
                token,
                DeviceIdentity.appVersion,
                DeviceIdentity.osVersion
            )
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
