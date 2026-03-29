import Foundation
import WebKit

/// 미니앱 세션 내에서 미리 워밍업된 WKWebView 인스턴스를 관리하는 풀
@MainActor
final class MiniAppWebViewPool {

    private let miniApp: MiniApp
    private let loadResult: MiniAppLoadResult
    private var available: [WKWebView] = []
    private let maxPoolSize = 3
    private let warmCount = 2

    let schemeHandler: MiniAppSchemeHandler

    init(miniApp: MiniApp, loadResult: MiniAppLoadResult) {
        self.miniApp = miniApp
        self.loadResult = loadResult
        self.schemeHandler = MiniAppSchemeHandler(
            appId: loadResult.appId,
            baseDirectory: loadResult.baseDirectory
        )
    }

    /// 풀에 warmCount만큼 WebView를 미리 생성
    func warmUp() {
        for _ in 0..<warmCount where available.count < maxPoolSize {
            available.append(createWebView())
        }
    }

    /// 풀에서 WebView를 가져오거나 새로 생성
    func acquire() -> WKWebView {
        if let webView = available.popLast() {
            return webView
        }
        return createWebView()
    }

    /// WebView를 풀에 반환 (about:blank로 리셋)
    func release(_ webView: WKWebView) {
        // 메시지 핸들러는 호출측에서 제거 후 반환해야 함
        webView.navigationDelegate = nil
        webView.load(URLRequest(url: URL(string: "about:blank")!))

        guard available.count < maxPoolSize else { return }
        available.append(webView)
    }

    // MARK: - Private

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        // 커스텀 스킴 핸들러 등록
        config.setURLSchemeHandler(schemeHandler, forURLScheme: MiniAppSchemeHandler.scheme)

        // 콘솔 포워딩 스크립트
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
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isInspectable = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear

        return webView
    }
}
