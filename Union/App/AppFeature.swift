import Foundation
import ComposableArchitecture

// MARK: - App Root Feature (Auth 분기)

@Reducer
struct AppFeature {

    private enum CancelID { case sessionObserver, deeplinkObserver }

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

        /// 푸시 MINIAPP 딥링크로 열리는 미니앱 (fullScreenCover). 탭/화면 위에 전체화면으로 뜬다.
        var pendingDeeplinkApp: DeeplinkRun?

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

    /// 푸시 MINIAPP 딥링크 실행 — 합성 MiniApp + 미니앱 내부 초기 경로(path).
    struct DeeplinkRun: Equatable, Identifiable {
        let miniApp: MiniApp
        let initialPath: String?
        var id: Int { miniApp.id }
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
        /// 푸시 MINIAPP 딥링크 수신 → 해당 미니앱을 fullScreenCover 로 연다.
        case openMiniAppFromPush(DeeplinkPayload)
        case dismissDeeplinkApp
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

                // 푸시 MINIAPP 딥링크 구독 — 앱 실행 중 탭으로 도착하는 deeplink 를 받는다.
                let deeplinkObserve: Effect<Action> = .run { send in
                    for await note in NotificationCenter.default.notifications(named: .unionOpenMiniApp) {
                        guard let payload = note.userInfo?["payload"] as? DeeplinkPayload else { continue }
                        await send(.openMiniAppFromPush(payload))
                    }
                }
                .cancellable(id: CancelID.deeplinkObserver)

                // 콜드런치(앱 종료 상태에서 푸시 탭)로 구독 전에 도착한 deeplink 회수.
                let consumeColdLaunch: Effect<Action> = .run { send in
                    if let payload = await DeeplinkRouter.shared.consumePendingMiniApp() {
                        await send(.openMiniAppFromPush(payload))
                    }
                }

                guard KeychainStore.isLoggedIn else {
                    state.isLoggedIn = false
                    return .merge(observeEffect, pushBootstrap, deeplinkObserve, consumeColdLaunch)
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

                return .merge(validateEffect, observeEffect, pushBootstrap, deeplinkObserve, consumeColdLaunch)

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

            case .openMiniAppFromPush(let payload):
                // 로그인 상태에서, 미니앱 DB id 가 동봉됐을 때만 연다.
                guard state.isLoggedIn, let miniAppId = payload.miniAppId else { return .none }
                // 이미 같은 미니앱이 열려 있으면 중복 표시 방지.
                guard state.pendingDeeplinkApp?.miniApp.id != miniAppId else { return .none }
                let synthetic = MiniApp(
                    id: miniAppId,
                    name: "",
                    description: "",
                    publisher: "",
                    category: "push",
                    iconUrl: nil,
                    iconEmoji: nil,
                    iconColorHex: nil,
                    rating: 0,
                    ratingCount: 0,
                    isNew: false,
                    isPopular: false,
                    createdAt: Date(),
                    // webUrl 은 비움 — MiniAppWebView 가 launch API(/mini-apps/{miniAppId}/launch)로 bundleUrl 을 가져온다.
                    webUrl: nil,
                    appId: payload.appId
                )
                state.pendingDeeplinkApp = DeeplinkRun(miniApp: synthetic, initialPath: payload.path)
                return .none

            case .dismissDeeplinkApp:
                state.pendingDeeplinkApp = nil
                return .none

            case .checkAuth:
                state.isLoggedIn = KeychainStore.isLoggedIn
                return .none

            case .logout:
                // 0) keychain 을 비우기 전에 서버 teardown 에 쓸 자격증명 스냅샷.
                //    (clearAll 이후엔 Bearer 토큰을 못 읽으므로 미리 캡처)
                let teardownAccessToken = KeychainStore.load(.accessToken)
                let teardownRefreshToken = KeychainStore.load(.refreshToken)
                let teardownFcmToken = DevicePushTokenStore.shared.current()
                let teardownDeviceId = DeviceIdentity.deviceId

                // 1) 토큰 폐기/서버 정리는 아래 effect 에서 invalidate → clearAll 순으로 수행한다.
                //    (TokenProvider.invalidate 가 진행 중 refresh 를 취소·무효화한 뒤 비워야
                //     in-flight refresh 로 세션이 되살아나지 않는다)

                // 2) 사용자에 묶인 로컬 히스토리(@Shared 파일) 비우기.
                //    fresh State 로 교체하기 전에 기존 @Shared 핸들로 비워야 디스크에도 반영된다.
                state.home.$launchedAppIds.withLock { $0 = [] }

                // 3) TCA state 전반 리셋 — 캐시된 응답/검색어/내비게이션 스택을 모두 폐기.
                state.isLoggedIn = false
                state.role = nil
                state.pendingTestContext = nil
                state.runningTest = nil
                state.testRedeemError = nil
                state.pendingDeeplinkApp = nil
                state.auth = AuthFeature.State()
                state.home = HomeFeature.State()
                state.search = SearchFeature.State()
                state.publisher = PublisherFeature.State()

                // 4) 진행 중 refresh 무효화 → 로컬 토큰 폐기 → 서버 세션/FCM 정리(best-effort)
                //    → 미니앱 WebView 영속 데이터 삭제. 모두 best-effort 이며 실패해도 로그아웃 완료.
                return .run { _ in
                    await TokenProvider.shared.invalidate()
                    KeychainStore.clearAll()
                    await SessionTeardown.purgeServerSession(
                        accessToken: teardownAccessToken,
                        refreshToken: teardownRefreshToken,
                        fcmToken: teardownFcmToken,
                        deviceId: teardownDeviceId
                    )
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
