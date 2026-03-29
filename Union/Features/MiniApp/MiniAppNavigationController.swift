import UIKit
import WebKit

/// 미니앱의 WebView 페이지 스택을 관리하는 UINavigationController
@MainActor
final class MiniAppNavigationController: UINavigationController,
                                          UINavigationControllerDelegate,
                                          UIGestureRecognizerDelegate {

    let miniApp: MiniApp
    let loadResult: MiniAppLoadResult
    let pool: MiniAppWebViewPool

    // 프리페치 캐시
    private var prefetchCache: [String: WKWebView] = [:]
    private var prefetchTimers: [String: Timer] = [:]
    private let prefetchTTL: TimeInterval = 30
    private let maxPrefetch = 3

    // SwiftUI 콜백
    var onTitleChange: ((String) -> Void)?
    var onLoadingChange: ((Bool) -> Void)?
    var onError: ((String?) -> Void)?
    var onCanGoBackChange: ((Bool) -> Void)?
    var onClose: (() -> Void)?

    /// 외부에서 설정하는 WKNavigationDelegate (Coordinator가 담당)
    weak var webNavigationDelegate: WKNavigationDelegate?

    init(miniApp: MiniApp, loadResult: MiniAppLoadResult) {
        self.miniApp = miniApp
        self.loadResult = loadResult
        self.pool = MiniAppWebViewPool(miniApp: miniApp, loadResult: loadResult)

        super.init(nibName: nil, bundle: nil)

        // 풀 워밍업
        pool.warmUp()

        // 초기 페이지 (route = "/") 생성
        let initialPage = createPage(route: "/", title: miniApp.name)
        setViewControllers([initialPage], animated: false)

        // 네비게이션 바 숨김 (SwiftUI에서 관리)
        isNavigationBarHidden = true
        delegate = self

        // 초기 페이지 로드
        let url = routeURL(for: "/")
        initialPage.webView.load(URLRequest(url: url))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // view 로드 후 interactivePopGestureRecognizer가 생성됨
        interactivePopGestureRecognizer?.isEnabled = true
        interactivePopGestureRecognizer?.delegate = self
        print("[MiniAppNav] viewDidLoad popGesture exists=\(interactivePopGestureRecognizer != nil) enabled=\(interactivePopGestureRecognizer?.isEnabled ?? false)")
    }

    // MARK: - canGoBack 즉시 업데이트

    private func notifyCanGoBack() {
        let canGoBack = viewControllers.count > 1
        onCanGoBackChange?(canGoBack)
    }

    // MARK: - Bridge 네비게이션 핸들러

    /// 새 페이지를 스택에 푸시
    @discardableResult
    func handlePush(url: String, title: String?, animated: Bool) -> Bool {
        let route = url

        // 프리페치 캐시 확인
        let webView: WKWebView
        if let cached = prefetchCache.removeValue(forKey: route) {
            prefetchTimers[route]?.invalidate()
            prefetchTimers.removeValue(forKey: route)
            webView = cached
        } else {
            webView = pool.acquire()
            let loadURL = routeURL(for: route)
            webView.load(URLRequest(url: loadURL))
        }

        // 이전 페이지의 배경색을 새 WebView에 적용 (CSS 로드 전까지 보이는 색)
        if let currentPage = topViewController as? MiniAppPageViewController {
            let bgColor = currentPage.webView.underPageBackgroundColor
            webView.underPageBackgroundColor = bgColor
            webView.backgroundColor = bgColor
            webView.scrollView.backgroundColor = bgColor
        }

        let page = MiniAppPageViewController(webView: webView, miniApp: miniApp, route: route)
        page.miniAppNavController = self
        page.title = title
        webView.navigationDelegate = webNavigationDelegate

        pushViewController(page, animated: animated)
        notifyCanGoBack()  // push 직후 즉시 업데이트
        print("[MiniAppNav] Pushed route=\(route) stack=\(viewControllers.count)")
        return true
    }

    /// 뒤로가기 (스택이 1개면 미니앱 종료)
    func handleBack() {
        if viewControllers.count > 1 {
            popViewController(animated: true)
            // pop 후 즉시 업데이트 (didShow보다 먼저)
            DispatchQueue.main.async { [weak self] in
                self?.notifyCanGoBack()
            }
        } else {
            onClose?()
        }
    }

    /// 현재 페이지를 새 URL로 교체
    func handleReplace(url: String) {
        guard let currentPage = topViewController as? MiniAppPageViewController else { return }
        let loadURL = routeURL(for: url)
        currentPage.webView.load(URLRequest(url: loadURL))
    }

    /// URL을 미리 로드하여 캐시에 저장
    func handlePrefetch(url: String) {
        let route = url

        guard prefetchCache[route] == nil else { return }

        if prefetchCache.count >= maxPrefetch {
            if let oldest = prefetchTimers.min(by: { $0.value.fireDate < $1.value.fireDate })?.key {
                evictPrefetch(route: oldest)
            }
        }

        let webView = pool.acquire()
        let loadURL = routeURL(for: route)
        webView.load(URLRequest(url: loadURL))
        prefetchCache[route] = webView

        let timer = Timer.scheduledTimer(withTimeInterval: prefetchTTL, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.evictPrefetch(route: route)
            }
        }
        prefetchTimers[route] = timer
    }

    // MARK: - Internal

    private func createPage(route: String, title: String?) -> MiniAppPageViewController {
        let webView = pool.acquire()
        let page = MiniAppPageViewController(webView: webView, miniApp: miniApp, route: route)
        page.miniAppNavController = self
        page.title = title
        return page
    }

    private func routeURL(for route: String) -> URL {
        pool.schemeHandler.entryURL(route: route)
    }

    private func evictPrefetch(route: String) {
        if let webView = prefetchCache.removeValue(forKey: route) {
            pool.release(webView)
        }
        prefetchTimers[route]?.invalidate()
        prefetchTimers.removeValue(forKey: route)
    }

    // MARK: - UIGestureRecognizerDelegate

    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let count = viewControllers.count
        if count > 1 { return true }

        // stack=1 (루트 페이지) → 미니앱 종료 확인
        Task { @MainActor in
            self.showCloseConfirmation()
        }
        return false
    }

    private func showCloseConfirmation() {
        let alert = UIAlertController(
            title: nil,
            message: "미니앱을 종료할까요?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "종료", style: .destructive) { [weak self] _ in
            self?.onClose?()
        })
        present(alert, animated: true)
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // pop 제스처가 다른 pan 제스처(WebView scroll 등)보다 우선
        otherGestureRecognizer is UIPanGestureRecognizer
    }

    // MARK: - UINavigationControllerDelegate

    nonisolated func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        Task { @MainActor in
            guard let page = viewController as? MiniAppPageViewController else { return }
            let title = page.title ?? self.miniApp.name
            self.onTitleChange?(title)
            self.notifyCanGoBack()
            print("[MiniAppNav] didShow route=\(page.route) stack=\(navigationController.viewControllers.count)")
        }
    }
}
