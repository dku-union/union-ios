import Foundation
import UIKit
import WebKit

// MARK: - UI Bridge Module
// SDK: Union.ui.showToast(), showModal(), showLoading(), hideLoading(), setNavigationBar(), close()

struct UIBridgeModule {

    @MainActor
    func handle(action: String, params: [String: Any], webView: WKWebView?) async throws -> Any? {
        switch action {
        case "showToast":
            let message = params["message"] as? String ?? ""
            let duration = params["duration"] as? String ?? "short"
            showToast(message: message, duration: duration)
            return nil

        case "showModal":
            let title = params["title"] as? String ?? ""
            let content = params["content"] as? String ?? ""
            let confirmText = params["confirmText"] as? String ?? "확인"
            let cancelText = params["cancelText"] as? String
            let confirmed = await showModal(title: title, content: content,
                                            confirmText: confirmText, cancelText: cancelText)
            return ["confirmed": confirmed]

        case "showLoading":
            let message = params["message"] as? String
            showLoading(message: message)
            return nil

        case "hideLoading":
            hideLoading()
            return nil

        case "setNavigationBar":
            // WebView의 호스트 뷰 컨트롤러에서 처리
            // 실제 네비게이션 바 업데이트는 Notification으로 전달
            let title = params["title"] as? String
            let bgColor = params["backgroundColor"] as? String
            let textColor = params["textColor"] as? String
            NotificationCenter.default.post(
                name: .miniAppNavigationBarUpdate,
                object: nil,
                userInfo: ["title": title as Any, "backgroundColor": bgColor as Any, "textColor": textColor as Any]
            )
            return nil

        case "close":
            NotificationCenter.default.post(name: .miniAppCloseRequested, object: nil)
            return nil

        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "ui.\(action) not found")
        }
    }

    // MARK: - Toast

    @MainActor
    private func showToast(message: String, duration: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else { return }

        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14, weight: .medium)
        toastLabel.textAlignment = .center
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        toastLabel.numberOfLines = 0
        toastLabel.layer.cornerRadius = 12
        toastLabel.clipsToBounds = true

        let padding: CGFloat = 16
        let maxWidth = window.bounds.width - 48
        let size = toastLabel.sizeThatFits(CGSize(width: maxWidth - padding * 2, height: .greatestFiniteMagnitude))
        toastLabel.frame = CGRect(
            x: (window.bounds.width - size.width - padding * 2) / 2,
            y: window.bounds.height - window.safeAreaInsets.bottom - 80,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        window.addSubview(toastLabel)
        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.25) { toastLabel.alpha = 1 }

        let delay: TimeInterval = duration == "long" ? 3.5 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIView.animate(withDuration: 0.25, animations: { toastLabel.alpha = 0 }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    // MARK: - Modal (UIAlertController)

    @MainActor
    private func showModal(title: String, content: String, confirmText: String, cancelText: String?) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController else {
                continuation.resume(returning: false)
                return
            }

            // 최상위 VC 찾기
            var topVC = rootVC
            while let presented = topVC.presentedViewController { topVC = presented }

            let alert = UIAlertController(title: title, message: content, preferredStyle: .alert)

            if let cancelText {
                alert.addAction(UIAlertAction(title: cancelText, style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
            }
            alert.addAction(UIAlertAction(title: confirmText, style: .default) { _ in
                continuation.resume(returning: true)
            })

            topVC.present(alert, animated: true)
        }
    }

    // MARK: - Loading Overlay

    private static let loadingTag = 99999

    @MainActor
    private func showLoading(message: String?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else { return }

        // 이미 있으면 무시
        if window.viewWithTag(Self.loadingTag) != nil { return }

        let overlay = UIView(frame: window.bounds)
        overlay.tag = Self.loadingTag
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 16
        container.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(spinner)
        overlay.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 100),
            container.heightAnchor.constraint(equalToConstant: 100),
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        if let message {
            let label = UILabel()
            label.text = message
            label.font = .systemFont(ofSize: 13)
            label.textColor = .secondaryLabel
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
                label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                container.heightAnchor.constraint(equalToConstant: 130),
                container.widthAnchor.constraint(equalToConstant: 140),
            ])
        }

        window.addSubview(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
    }

    @MainActor
    private func hideLoading() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              let overlay = window.viewWithTag(Self.loadingTag) else { return }

        UIView.animate(withDuration: 0.2, animations: { overlay.alpha = 0 }) { _ in
            overlay.removeFromSuperview()
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let miniAppNavigationBarUpdate = Notification.Name("miniAppNavigationBarUpdate")
    static let miniAppCloseRequested = Notification.Name("miniAppCloseRequested")
    static let miniAppGoBack = Notification.Name("miniAppGoBack")
    static let miniAppSpaStateChange = Notification.Name("miniAppSpaStateChange")
    static let miniAppWillNavigate = Notification.Name("miniAppWillNavigate")
}
