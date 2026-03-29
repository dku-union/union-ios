import SwiftUI
import WebKit

// MARK: - MiniAppWebView (SwiftUI)

struct MiniAppWebView: View {
    let miniApp: MiniApp

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var navTitle: String
    @State private var loadError: String?
    @State private var resolvedURL: URL?

    init(miniApp: MiniApp) {
        self.miniApp = miniApp
        self._navTitle = State(initialValue: miniApp.name)
    }

    var body: some View {
        ZStack {
            if let webUrl = miniApp.webUrl, let url = URL(string: webUrl) {
                if let resolvedURL {
                    MiniAppWebViewRepresentable(
                        url: resolvedURL,
                        miniApp: miniApp,
                        isLoading: $isLoading,
                        navTitle: $navTitle,
                        loadError: $loadError,
                        onClose: { dismiss() }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }

                if isLoading {
                    loadingOverlay
                }

                if let loadError {
                    errorOverlay(message: loadError)
                }
            } else {
                noUrlView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(navTitle)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await resolveURL()
        }
    }

    /// .unionapp URL이면 다운로드+압축해제, 일반 URL이면 그대로 사용
    private func resolveURL() async {
        guard let webUrl = miniApp.webUrl, let url = URL(string: webUrl) else { return }

        if webUrl.hasSuffix(".unionapp") || webUrl.contains(".unionapp?") {
            do {
                let localURL = try await MiniAppLoader.load(from: url, appId: miniApp.id.uuidString)
                resolvedURL = localURL
            } catch {
                loadError = error.localizedDescription
                isLoading = false
            }
        } else {
            resolvedURL = url
        }
    }

    // MARK: - Sub Views

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("로딩 중...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("페이지를 불러올 수 없습니다")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }

    private var noUrlView: some View {
        VStack(spacing: 16) {
            Image(systemName: "app.dashed")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("아직 배포되지 않은 미니앱입니다")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - UIViewRepresentable (WKWebView + Bridge)

struct MiniAppWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let miniApp: MiniApp
    @Binding var isLoading: Bool
    @Binding var navTitle: String
    @Binding var loadError: String?
    let onClose: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Bridge 핸들러 설정
        let bridgeHandler = BridgeHandler(miniApp: miniApp)
        context.coordinator.bridgeHandler = bridgeHandler

        let config = WKWebViewConfiguration()
        config.userContentController.add(
            LeakAvoider(delegate: bridgeHandler),
            name: "union"   // SDK의 window.webkit.messageHandlers.union 과 매칭
        )

        // 미니앱 콘솔 로그를 네이티브로 포워딩 (디버그용)
        let consoleScript = WKUserScript(
            source: """
            (function() {
                const origLog = console.log;
                const origError = console.error;
                const origWarn = console.warn;
                console.log = function() {
                    origLog.apply(console, arguments);
                    window.webkit.messageHandlers.union.postMessage({
                        id: 'console', module: 'debug', action: 'log',
                        params: { level: 'log', message: Array.from(arguments).map(String).join(' ') },
                        sdkVersion: '1.0.0', timestamp: Date.now()
                    });
                };
                console.error = function() {
                    origError.apply(console, arguments);
                    window.webkit.messageHandlers.union.postMessage({
                        id: 'console', module: 'debug', action: 'log',
                        params: { level: 'error', message: Array.from(arguments).map(String).join(' ') },
                        sdkVersion: '1.0.0', timestamp: Date.now()
                    });
                };
                console.warn = function() {
                    origWarn.apply(console, arguments);
                    window.webkit.messageHandlers.union.postMessage({
                        id: 'console', module: 'debug', action: 'log',
                        params: { level: 'warn', message: Array.from(arguments).map(String).join(' ') },
                        sdkVersion: '1.0.0', timestamp: Date.now()
                    });
                };
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(consoleScript)

        // WebView 설정
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true  // Safari Web Inspector 활성화 (디버그)

        bridgeHandler.attach(to: webView)

        // 알림 구독 (미니앱에서 close 요청)
        context.coordinator.observeNotifications()

        // URL 로드 (로컬 파일이면 loadFileURL, 원격이면 load)
        if url.isFileURL {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator (WKNavigationDelegate)

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: MiniAppWebViewRepresentable
        var bridgeHandler: BridgeHandler?
        nonisolated(unsafe) private var closeObserver: NSObjectProtocol?
        nonisolated(unsafe) private var navBarObserver: NSObjectProtocol?

        init(parent: MiniAppWebViewRepresentable) {
            self.parent = parent
        }

        deinit {
            if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
            if let navBarObserver { NotificationCenter.default.removeObserver(navBarObserver) }
        }

        func observeNotifications() {
            closeObserver = NotificationCenter.default.addObserver(
                forName: .miniAppCloseRequested, object: nil, queue: .main
            ) { [weak self] _ in
                self?.parent.onClose()
            }

            navBarObserver = NotificationCenter.default.addObserver(
                forName: .miniAppNavigationBarUpdate, object: nil, queue: .main
            ) { [weak self] notification in
                if let title = notification.userInfo?["title"] as? String {
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

            // 앱 라이프사이클 이벤트 전송
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

        // 외부 링크는 Safari로 열기
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               url.host != parent.url.host {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// MARK: - LeakAvoider (WKScriptMessageHandler retain cycle 방지)

final class LeakAvoider: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
