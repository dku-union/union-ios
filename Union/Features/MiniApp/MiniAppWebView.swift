import SwiftUI
import WebKit

// MARK: - Launch API Response

private struct LaunchResponse: Decodable {
    let bundleUrl: String
}

// MARK: - MiniAppWebView (SwiftUI)

struct MiniAppWebView: View {
    let miniApp: MiniApp

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var navTitle: String
    @State private var loadError: String?
    @State private var canGoBack = false

    @State private var resolvedLocal: MiniAppLoadResult?
    @State private var resolvedRemote: URL?

    /// launch API 호출이 완료되었는지 여부.
    /// true + resolvedLocal/Remote 모두 nil = 배포된 버전 없음
    @State private var launchResolved = false

    /// 권한 동의 게이트 단계. .proceed 이전에는 WebView 를 생성하지 않는다.
    @State private var consentPhase: ConsentPhase = .checking

    private enum ConsentPhase: Equatable {
        case checking                       // 권한 상태 확인 중
        case prompting([PermissionItem])    // 동의 모달 표시 (요청 스코프)
        case proceed                        // 진행 (WebView 로드 허용)
    }

    init(miniApp: MiniApp) {
        self.miniApp = miniApp
        self._navTitle = State(initialValue: miniApp.name)
    }

    var body: some View {
        ZStack {
            // 동의 게이트: 권한 동의가 끝나기(.proceed) 전에는 WebView 를 생성하지 않는다
            // (미니앱 JS 가 동의 전에 실행되어 브릿지를 호출하는 것을 방지).
            if consentPhase == .proceed, let loadResult = resolvedLocal {
                // 로컬 .unionapp 패키지 로드
                MiniAppNavigationControllerRepresentable(
                    miniApp: miniApp,
                    loadResult: loadResult,
                    isLoading: $isLoading,
                    navTitle: $navTitle,
                    loadError: $loadError,
                    canGoBack: $canGoBack,
                    onClose: { dismiss() }
                )
                .ignoresSafeArea(edges: .bottom)

            } else if consentPhase == .proceed, let remoteURL = resolvedRemote {
                // 원격 HTTP(S) URL 로드
                MiniAppWebViewRepresentable(
                    remoteURL: remoteURL,
                    miniApp: miniApp,
                    isLoading: $isLoading,
                    navTitle: $navTitle,
                    loadError: $loadError,
                    canGoBack: $canGoBack,
                    onClose: { dismiss() }
                )
                .ignoresSafeArea(edges: .bottom)

            } else if launchResolved, resolvedLocal == nil, resolvedRemote == nil {
                // launch API 완료 후에도 URL 없음 = 배포된 버전 없음
                // (URL 은 있으나 동의 대기 중인 경우는 제외 — 그땐 로딩 상태로 둔다)
                noUrlView
            }
            // else: URL 획득 중 또는 동의 대기 중 → 아무것도 표시하지 않음 (네비게이션 바 로딩 인디케이터로 표시)

            if let loadError { errorOverlay(message: loadError) }

            // 최초 접속 권한 동의 모달 (앱-동의 계층)
            if case let .prompting(items) = consentPhase {
                consentOverlay(items: items)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(navTitle)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    if canGoBack {
                        NotificationCenter.default.post(name: .miniAppGoBack, object: nil)
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.medium)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading && !launchResolved {
                    ProgressView().scaleEffect(0.8)
                }
            }
        }
        .task { await resolveURL() }
        .task { await runConsentGate() }
    }

    // MARK: - 권한 동의 게이트

    /// 미니앱 JS 가 실행되기 전(WebView 생성 전) 권한 동의 상태를 결정한다.
    /// resolveURL 과 동시에 실행되며, WebView 는 `.proceed` + URL 해석 완료 시에만 생성된다.
    private func runConsentGate() async {
        let appId = miniApp.id

        // 이미 결정이 있는 앱 → 즉시 진행 (네트워크 없이 fast-path, 모달 skip).
        if PermissionStore.shared.isKnown(appId: appId) {
            consentPhase = .proceed
            return
        }

        do {
            let state = try await MiniAppPermissionClient.liveValue.fetch(appId)
            let declared = state.permissions.filter { $0.permissionScope != nil }

            // 선언된 권한이 없으면 동의받을 것이 없다 → 진행.
            if declared.isEmpty {
                consentPhase = .proceed
                return
            }

            // 모든 선언 권한에 이미 결정이 있으면(다른 기기/이전 결정) 로컬 캐시 하이드레이트 후 진행.
            if declared.allSatisfy(\.hasDecision) {
                hydrate(appId: appId, from: declared)
                consentPhase = .proceed
                return
            }

            // 결정이 필요한 스코프가 있으면 모달 표시.
            consentPhase = .prompting(declared)
        } catch {
            // 오프라인/오류 → 앱은 로드(fail-open), 다음 접속 시 재프롬프트.
            consentPhase = .proceed
        }
    }

    /// "허용" — 토글 상태대로 로컬 캐시에 저장 → 진행. 백엔드 동기화는 비차단(로컬이 집행의 진실원).
    private func handleConsent(decisions: [PermissionScope: Bool]) {
        let appId = miniApp.id
        PermissionStore.shared.setDecisions(appId: appId, decisions)
        consentPhase = .proceed
        Task {
            do {
                _ = try await MiniAppPermissionClient.liveValue.submit(appId, decisions)
            } catch {
                // 로컬 집행은 유효. 백엔드 동기화 실패만 로깅(권한 관리 화면에서 재시도 가능).
                print("[Permission] 권한 결정 백엔드 동기화 실패 appId=\(appId): \(error)")
            }
        }
    }

    /// 백엔드 결정값으로 로컬 캐시를 채운다(모달 없이 진행하는 경로 — 타 기기/이전 결정 존재 시).
    private func hydrate(appId: Int, from declared: [PermissionItem]) {
        let decisions = Dictionary(uniqueKeysWithValues: declared.compactMap { item -> (PermissionScope, Bool)? in
            guard let scope = item.permissionScope else { return nil }
            return (scope, item.granted)
        })
        PermissionStore.shared.setDecisions(appId: appId, decisions)
    }

    @ViewBuilder
    private func consentOverlay(items: [PermissionItem]) -> some View {
        MiniAppConsentModal(
            appName: miniApp.name,
            scopes: items.compactMap(\.permissionScope),
            onAllow: { handleConsent(decisions: $0) },
            onPostpone: { consentPhase = .proceed }
        )
        .zIndex(10)
    }

    // MARK: - URL 해석

    /// 1) miniApp.webUrl 이 있으면 그대로 사용
    /// 2) 없으면 POST /mini-apps/{id}/launch 호출하여 bundleUrl 획득
    private func resolveURL() async {
        let urlString: String?

        if let w = miniApp.webUrl, !w.isEmpty {
            // MockData 또는 이미 URL이 내려온 경우
            urlString = w
        } else {
            // launch API로 URL 획득
            urlString = await fetchLaunchUrl()
        }

        launchResolved = true

        guard let urlString, let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        if urlString.hasSuffix(".unionapp") || urlString.contains(".unionapp?") {
            // .unionapp ZIP 다운로드 → 압축 해제 → 로컬 서빙
            do {
                resolvedLocal = try await MiniAppLoader.load(from: url, appId: String(miniApp.id))
            } catch {
                loadError = error.localizedDescription
                isLoading = false
            }
        } else {
            // 원격 HTTP(S) URL 직접 로드
            resolvedRemote = url
        }
    }

    /// POST /mini-apps/{id}/launch → bundleUrl 반환
    /// 실패하면 loadError 를 설정하고 nil 반환
    private func fetchLaunchUrl() async -> String? {
        do {
            let apiClient = APIClient(baseURL: APIConfig.baseURL)
            let response: LaunchResponse = try await apiClient.request(.launchApp(id: miniApp.id))
            return response.bundleUrl
        } catch {
            loadError = "앱을 불러올 수 없습니다: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Sub Views

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("페이지를 불러올 수 없습니다").font(UNFont.headingSmall())
            Text(message).font(UNFont.captionLarge()).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var noUrlView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("아직 배포되지 않은 미니앱입니다").font(UNFont.headingSmall())
            Text("퍼블리셔가 앱을 아직 배포하지 않았습니다").font(UNFont.captionLarge()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - MiniAppNavigationControllerRepresentable (로컬 미니앱용)

struct MiniAppNavigationControllerRepresentable: UIViewControllerRepresentable {
    let miniApp: MiniApp
    let loadResult: MiniAppLoadResult
    @Binding var isLoading: Bool
    @Binding var navTitle: String
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MiniAppNavigationController {
        let navController = MiniAppNavigationController(miniApp: miniApp, loadResult: loadResult)

        navController.onTitleChange = { [weak coordinator = context.coordinator] title in
            coordinator?.parent.navTitle = title
        }
        navController.onLoadingChange = { [weak coordinator = context.coordinator] loading in
            coordinator?.parent.isLoading = loading
        }
        navController.onError = { [weak coordinator = context.coordinator] error in
            coordinator?.parent.loadError = error
        }
        navController.onCanGoBackChange = { [weak coordinator = context.coordinator] canGoBack in
            coordinator?.parent.canGoBack = canGoBack
        }
        navController.onClose = { [weak coordinator = context.coordinator, weak navController] in
            // Analytics: app_close 이벤트 전송 후 세션 종료
            if let rootPage = navController?.viewControllers.first as? MiniAppPageViewController {
                rootPage.bridgeHandler.notifyMiniAppClosed()
            }
            coordinator?.parent.onClose()
        }

        context.coordinator.navController = navController

        // Coordinator를 WKNavigationDelegate로 설정 (현재 + 이후 push되는 페이지 모두)
        navController.webNavigationDelegate = context.coordinator

        // 초기 페이지의 WKNavigationDelegate 설정
        if let initialPage = navController.viewControllers.first as? MiniAppPageViewController {
            initialPage.webView.navigationDelegate = context.coordinator
            context.coordinator.observeCanGoBack(for: initialPage.webView)
        }

        // goBack 알림 관찰
        context.coordinator.observeNotifications()

        return navController
    }

    func updateUIViewController(_ uiViewController: MiniAppNavigationController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MiniAppNavigationControllerRepresentable
        weak var navController: MiniAppNavigationController?
        private var canGoBackObservation: NSKeyValueObservation?

        nonisolated(unsafe) private var goBackObserver: NSObjectProtocol?
        nonisolated(unsafe) private var closeObserver: NSObjectProtocol?
        nonisolated(unsafe) private var navBarObserver: NSObjectProtocol?

        /// Analytics app_open 을 첫 번째 WebView 로드 시 1회만 전송하기 위한 플래그
        private var hasTrackedOpen = false

        init(parent: MiniAppNavigationControllerRepresentable) {
            self.parent = parent
        }

        deinit {
            [goBackObserver, closeObserver, navBarObserver]
                .compactMap { $0 }
                .forEach { NotificationCenter.default.removeObserver($0) }
            canGoBackObservation?.invalidate()
        }

        func observeCanGoBack(for webView: WKWebView) {
            canGoBackObservation?.invalidate()
            canGoBackObservation = webView.observe(\.canGoBack, options: .new) { [weak self] _, _ in
                Task { @MainActor in
                    self?.updateCanGoBack()
                }
            }
        }

        private func updateCanGoBack() {
            let hasMultiplePages = (navController?.viewControllers.count ?? 0) > 1
            parent.canGoBack = hasMultiplePages
        }

        func observeNotifications() {
            goBackObserver = NotificationCenter.default.addObserver(
                forName: .miniAppGoBack, object: nil, queue: .main
            ) { [weak self] _ in
                self?.navController?.handleBack()
            }

            closeObserver = NotificationCenter.default.addObserver(
                forName: .miniAppCloseRequested, object: nil, queue: .main
            ) { [weak self] _ in
                self?.parent.onClose()
            }

            navBarObserver = NotificationCenter.default.addObserver(
                forName: .miniAppNavigationBarUpdate, object: nil, queue: .main
            ) { [weak self] notif in
                if let title = notif.userInfo?["title"] as? String {
                    self?.parent.navTitle = title
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            // SDK 이벤트: app:resume
            if let page = navController?.topViewController as? MiniAppPageViewController {
                page.bridgeHandler.sendEvent("app:resume")
            }
            // Analytics: 첫 페이지 로드 시 app_open 추적
            if !hasTrackedOpen {
                hasTrackedOpen = true
                if let rootPage = navController?.viewControllers.first as? MiniAppPageViewController {
                    rootPage.bridgeHandler.notifyWebViewDidLoad()
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               url.scheme != MiniAppSchemeHandler.scheme,
               url.scheme != "about" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - MiniAppWebViewRepresentable (원격 URL용)

struct MiniAppWebViewRepresentable: UIViewRepresentable {
    let miniApp: MiniApp
    @Binding var isLoading: Bool
    @Binding var navTitle: String
    @Binding var loadError: String?
    @Binding var canGoBack: Bool
    let onClose: () -> Void

    private let remoteURL: URL

    init(remoteURL: URL, miniApp: MiniApp,
         isLoading: Binding<Bool>, navTitle: Binding<String>,
         loadError: Binding<String?>, canGoBack: Binding<Bool>,
         onClose: @escaping () -> Void) {
        self.remoteURL = remoteURL; self.miniApp = miniApp
        _isLoading = isLoading; _navTitle = navTitle; _loadError = loadError; _canGoBack = canGoBack
        self.onClose = onClose
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let bridgeHandler = BridgeHandler(miniApp: miniApp)
        context.coordinator.bridgeHandler = bridgeHandler
        context.coordinator.onClose = onClose

        let config = WKWebViewConfiguration()
        config.userContentController.add(LeakAvoider(delegate: bridgeHandler), name: "union")

        // 콘솔 포워딩
        let consoleScript = WKUserScript(
            source: """
            (function() {
                var orig = { log: console.log, error: console.error, warn: console.warn };
                ['log','error','warn'].forEach(function(level) {
                    console[level] = function() {
                        orig[level].apply(console, arguments);
                        try {
                            window.webkit.messageHandlers.union.postMessage({
                                id: 'console', module: 'debug', action: 'log',
                                params: { level: level, message: Array.from(arguments).map(String).join(' ') },
                                sdkVersion: '1.0.0', timestamp: Date.now()
                            });
                        } catch(e) {}
                    };
                });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(consoleScript)

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true

        bridgeHandler.attach(to: webView)
        context.coordinator.webView = webView

        // canGoBack KVO
        context.coordinator.canGoBackObservation = webView.observe(\.canGoBack, options: .new) { [weak coordinator = context.coordinator] webView, _ in
            Task { @MainActor in
                coordinator?.parent.canGoBack = webView.canGoBack
            }
        }

        context.coordinator.observeNotifications()
        webView.load(URLRequest(url: remoteURL))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: MiniAppWebViewRepresentable
        weak var webView: WKWebView?
        var bridgeHandler: BridgeHandler?
        var canGoBackObservation: NSKeyValueObservation?

        nonisolated(unsafe) private var closeObserver: NSObjectProtocol?
        nonisolated(unsafe) private var navBarObserver: NSObjectProtocol?
        nonisolated(unsafe) private var goBackObserver: NSObjectProtocol?

        /// Analytics app_open 1회만 전송하기 위한 플래그
        private var hasTrackedOpen = false
        /// 미니앱 종료 콜백 (Analytics app_close 전송 후 호출)
        var onClose: (() -> Void)?

        init(parent: MiniAppWebViewRepresentable) {
            self.parent = parent
        }

        deinit {
            [closeObserver, navBarObserver, goBackObserver]
                .compactMap { $0 }
                .forEach { NotificationCenter.default.removeObserver($0) }
            canGoBackObservation?.invalidate()
        }

        func observeNotifications() {
            closeObserver = NotificationCenter.default.addObserver(
                forName: .miniAppCloseRequested, object: nil, queue: .main
            ) { [weak self] _ in
                // Analytics: 미니앱 종료 전 세션 닫기
                self?.bridgeHandler?.notifyMiniAppClosed()
                self?.parent.onClose()
            }

            navBarObserver = NotificationCenter.default.addObserver(
                forName: .miniAppNavigationBarUpdate, object: nil, queue: .main
            ) { [weak self] notif in
                if let title = notif.userInfo?["title"] as? String { self?.parent.navTitle = title }
            }

            goBackObserver = NotificationCenter.default.addObserver(
                forName: .miniAppGoBack, object: nil, queue: .main
            ) { [weak self] _ in
                if self?.webView?.canGoBack == true {
                    self?.webView?.goBack()
                } else {
                    self?.parent.onClose()
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            bridgeHandler?.sendEvent("app:resume")
            // Analytics: 첫 로드 시 app_open 전송
            if !hasTrackedOpen {
                hasTrackedOpen = true
                bridgeHandler?.notifyWebViewDidLoad()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.loadError = error.localizedDescription
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               url.scheme != "about",
               url.scheme != "http" && url.scheme != "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - LeakAvoider

final class LeakAvoider: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) { self.delegate = delegate }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(controller, didReceive: message)
    }
}
