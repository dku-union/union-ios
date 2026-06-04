import SwiftUI
import SafariServices

// MARK: - Legal Links

/// 앱 사용자용 약관·개인정보처리방침 호스팅 URL.
/// union-dashboard 의 `/legal/app/*` 페이지(앱 사용자 데이터 기준)를 가리킨다.
enum LegalLinks {
    static let terms = URL(string: "https://union-phi.vercel.app/legal/app/terms")!
    static let privacy = URL(string: "https://union-phi.vercel.app/legal/app/privacy")!
}

// MARK: - Web Link (sheet item)

/// `.sheet(item:)` 으로 `SafariView` 를 띄우기 위한 Identifiable URL 래퍼.
struct WebLink: Identifiable, Hashable {
    let url: URL
    var id: String { url.absoluteString }

    init(_ url: URL) { self.url = url }
}

// MARK: - Safari View

/// `SFSafariViewController` 를 SwiftUI 에서 띄우기 위한 래퍼.
/// 약관·개인정보처리방침 등 웹 문서를 인앱 브라우저로 표시한다.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(UNColor.interactive)
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
