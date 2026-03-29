import SwiftUI
import WebKit

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

    init(miniApp: MiniApp) {
        self.miniApp = miniApp
        self._navTitle = State(initialValue: miniApp.name)
    }

    var body: some View {
        ZStack {
            if let webUrl = miniApp.webUrl, !webUrl.isEmpty {
                if let loadResult = resolvedLocal {
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
                } else if let remoteURL = resolvedRemote {
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
                }

                if let loadError { errorOverlay(message: loadError) }
            } else {
                noUrlView
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
        }
        .task { await resolveURL() }
    }

    private func resolveURL() async {
        guard let webUrl = miniApp.webUrl, let url = URL(string: webUrl) else { return }
        if webUrl.hasSuffix(".unionapp") || webUrl.contains(".unionapp?") {
            do {
                resolvedLocal = try await MiniAppLoader.load(from: url, appId: miniApp.id.uuidString)
            } catch {
                loadError = error.localizedDescription
                isLoading = false
            }
        } else {
            resolvedRemote = url
        }
    }

    // MARK: - Sub Views

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("로딩 중...").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("페이지를 불러올 수 없습니다").font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var noUrlView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed").font(.system(size: 40)).foregroundStyle(.secondary)
            Text("아직 배포되지 않은 미니앱입니다").font(.headline)
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
        navController.onClose = { [weak coordinator = context.coordinator] in
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
            // 현재 페이지의 bridgeHandler에 resume 이벤트 전송
            if let page = navController?.topViewController as? MiniAppPageViewController {
                page.bridgeHandler.sendEvent("app:resume")
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
            ) { [weak self] _ in self?.parent.onClose() }

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
