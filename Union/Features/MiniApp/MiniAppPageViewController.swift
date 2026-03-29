import UIKit
import WebKit

/// 단일 WKWebView를 감싸는 UIViewController (UINavigationController 스택에서 사용)
@MainActor
final class MiniAppPageViewController: UIViewController {

    let webView: WKWebView
    let bridgeHandler: BridgeHandler
    let route: String
    weak var miniAppNavController: MiniAppNavigationController?

    private var leakAvoider: LeakAvoider?

    init(webView: WKWebView, miniApp: MiniApp, route: String) {
        self.webView = webView
        self.route = route
        self.bridgeHandler = BridgeHandler(miniApp: miniApp)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // WebView를 서브뷰로 추가 + AutoLayout
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // BridgeHandler 연결
        bridgeHandler.attach(to: webView)
        bridgeHandler.navigationController = miniAppNavController

        // 메시지 핸들러 등록 (LeakAvoider로 순환 참조 방지)
        let avoider = LeakAvoider(delegate: bridgeHandler)
        self.leakAvoider = avoider
        webView.configuration.userContentController.add(avoider, name: "union")

        // WebView scrollView의 pan 제스처가 nav pop 제스처에 양보하도록 설정
        if let popGesture = miniAppNavController?.interactivePopGestureRecognizer {
            webView.scrollView.panGestureRecognizer.require(toFail: popGesture)
            print("[MiniAppPage] require(toFail: popGesture) set for route=\(route) popEnabled=\(popGesture.isEnabled)")
        } else {
            print("[MiniAppPage] WARNING: no popGesture found for route=\(route) navController=\(String(describing: miniAppNavController))")
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // 네비게이션 스택에서 제거될 때 (뒤로가기) 정리
        if isMovingFromParent {
            cleanUp()
        }
    }

    /// 메시지 핸들러 제거 + WebView를 풀에 반환
    func cleanUp() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "union")
        leakAvoider = nil
        miniAppNavController?.pool.release(webView)
    }
}
