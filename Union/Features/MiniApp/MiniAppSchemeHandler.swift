import Foundation
import WebKit
import UniformTypeIdentifiers

/// union-app:// 커스텀 스킴 핸들러
/// file:// 대신 사용하여 pushState/popstate 가 정상 동작하도록 함
final class MiniAppSchemeHandler: NSObject, WKURLSchemeHandler {

    static let scheme = "union-app"

    private let appId: String
    private let baseDirectory: URL

    init(appId: String, baseDirectory: URL) {
        self.appId = appId
        self.baseDirectory = baseDirectory
        super.init()
    }

    /// 미니앱 진입 URL 생성
    var entryURL: URL {
        entryURL(route: nil)
    }

    /// route가 주어지면 ?__route=<encoded_route>를 붙여 진입 URL 생성
    func entryURL(route: String? = nil) -> URL {
        var urlString = "\(Self.scheme)://\(appId)/index.html"
        if let route, !route.isEmpty, route != "/" {
            let encoded = route.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? route
            urlString += "?__route=\(encoded)"
        }
        return URL(string: urlString)!
    }

    // MARK: - WKURLSchemeHandler

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(SchemeError.invalidURL)
            return
        }

        // union-app://{appId}/path/to/file
        var relativePath = url.path
        if relativePath.hasPrefix("/") {
            relativePath = String(relativePath.dropFirst())
        }
        if relativePath.isEmpty {
            relativePath = "index.html"
        }

        let fileURL = baseDirectory.appendingPathComponent(relativePath)

        // 경로 탈출 방지
        guard fileURL.standardizedFileURL.path.hasPrefix(baseDirectory.standardizedFileURL.path) else {
            urlSchemeTask.didFailWithError(SchemeError.accessDenied)
            return
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            urlSchemeTask.didFailWithError(SchemeError.fileNotFound)
            return
        }

        let mimeType = Self.mimeType(for: fileURL)
        let response = URLResponse(
            url: url,
            mimeType: mimeType,
            expectedContentLength: data.count,
            textEncodingName: mimeType.hasPrefix("text/") ? "utf-8" : nil
        )

        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        // 동기 읽기이므로 취소할 작업 없음
    }

    // MARK: - MIME Type

    private static func mimeType(for fileURL: URL) -> String {
        let ext = fileURL.pathExtension.lowercased()
        if let utType = UTType(filenameExtension: ext), let mime = utType.preferredMIMEType {
            return mime
        }
        switch ext {
        case "html", "htm": return "text/html"
        case "js", "mjs":   return "application/javascript"
        case "css":          return "text/css"
        case "json":         return "application/json"
        case "svg":          return "image/svg+xml"
        case "wasm":         return "application/wasm"
        default:             return "application/octet-stream"
        }
    }

    // MARK: - Errors

    enum SchemeError: LocalizedError {
        case invalidURL, fileNotFound, accessDenied

        var errorDescription: String? {
            switch self {
            case .invalidURL:   "잘못된 URL입니다"
            case .fileNotFound: "파일을 찾을 수 없습니다"
            case .accessDenied: "접근이 거부되었습니다"
            }
        }
    }
}
