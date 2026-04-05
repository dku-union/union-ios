import Foundation
import os.log

// MARK: - Network Logger

/// DEBUG 빌드 전용 네트워크 로거
///
/// Xcode 콘솔에서 API 요청/응답을 시각적으로 구분할 수 있도록 포맷팅.
/// Release 빌드에서는 컴파일 자체가 제거됨 (`#if DEBUG`).
///
/// 출력 예시:
/// ```
/// ┌─ 🔵 REQUEST ──────────────────────────
/// │ GET /api/v1/apps?sort=popular
/// │ Auth: ✅ Bearer ••••a3f2
/// └───────────────────────────────────────
/// ┌─ 🟢 200 OK ─────────── 142ms ────────
/// │ GET /api/v1/apps?sort=popular
/// │ Size: 2.4 KB
/// │ Body: {"data":[{"id":"550e84...
/// └───────────────────────────────────────
/// ```
enum NetworkLogger {

    #if DEBUG
    private static let logger = Logger(subsystem: "com.union.app", category: "Network")
    private static let dividerWidth = 50
    private static let bodyPreviewLimit = 300
    #endif

    // MARK: - Request

    static func logRequest(_ request: URLRequest) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let path = request.url.map { formatPath($0) } ?? "nil"
        let bodySize = request.httpBody.map { formatBytes($0.count) } ?? "0 B"
        let auth = formatAuthHeader(request.value(forHTTPHeaderField: "Authorization"))

        var lines: [String] = []
        lines.append(divider(icon: "🔵", title: "REQUEST"))
        lines.append("│ \(method) \(path)")
        lines.append("│ Auth: \(auth)")
        if let body = request.httpBody, !body.isEmpty {
            lines.append("│ Body: \(bodySize)")
            if let preview = formatBodyPreview(body) {
                lines.append("│ \(preview)")
            }
        }
        lines.append(closeDivider())

        let output = lines.joined(separator: "\n")
        logger.debug("\(output)")
        #endif
    }

    // MARK: - Response

    static func logResponse(
        _ request: URLRequest,
        status: Int,
        data: Data,
        duration: TimeInterval
    ) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let path = request.url.map { formatPath($0) } ?? "nil"
        let icon = statusIcon(status)
        let statusText = HTTPURLResponse.localizedString(forStatusCode: status).capitalized
        let ms = formatDuration(duration)
        let size = formatBytes(data.count)

        var lines: [String] = []
        lines.append(divider(icon: icon, title: "\(status) \(statusText)", trailing: ms))
        lines.append("│ \(method) \(path)")
        lines.append("│ Size: \(size)")
        if let preview = formatBodyPreview(data) {
            lines.append("│ Body: \(preview)")
        }
        lines.append(closeDivider())

        let output = lines.joined(separator: "\n")
        logger.debug("\(output)")
        #endif
    }

    // MARK: - Token Events

    static func logTokenRefreshStart() {
        #if DEBUG
        let output = [
            divider(icon: "🔑", title: "TOKEN REFRESH"),
            "│ Refreshing access token...",
            closeDivider()
        ].joined(separator: "\n")
        logger.info("\(output)")
        #endif
    }

    static func logTokenRefreshResult(success: Bool, duration: TimeInterval, error: Error? = nil) {
        #if DEBUG
        let ms = formatDuration(duration)
        let status = success ? "✅ Success" : "❌ Failed"

        var lines: [String] = []
        lines.append(divider(icon: "🔑", title: "TOKEN REFRESH \(status)", trailing: ms))
        if let error {
            lines.append("│ Error: \(error.localizedDescription)")
        }
        if success, let token = KeychainStore.load(.accessToken) {
            lines.append("│ New token: \(maskToken(token))")
        }
        lines.append(closeDivider())

        let output = lines.joined(separator: "\n")
        success ? logger.info("\(output)") : logger.error("\(output)")
        #endif
    }

    static func logProactiveRefresh(expiresIn: TimeInterval) {
        #if DEBUG
        let seconds = Int(expiresIn)
        let output = [
            divider(icon: "⏳", title: "PROACTIVE REFRESH"),
            "│ Token expires in \(seconds)s — refreshing preemptively",
            closeDivider()
        ].joined(separator: "\n")
        logger.info("\(output)")
        #endif
    }

    // MARK: - Retry

    static func logRetry(_ request: URLRequest, reason: String) {
        #if DEBUG
        let method = request.httpMethod ?? "UNKNOWN"
        let path = request.url.map { formatPath($0) } ?? "nil"

        let output = [
            divider(icon: "🔄", title: "RETRY"),
            "│ \(method) \(path)",
            "│ Reason: \(reason)",
            closeDivider()
        ].joined(separator: "\n")
        logger.warning("\(output)")
        #endif
    }

    // MARK: - Error

    static func logError(_ request: URLRequest?, error: Error, duration: TimeInterval? = nil) {
        #if DEBUG
        let method = request?.httpMethod ?? "UNKNOWN"
        let path = request?.url.map { formatPath($0) } ?? "nil"
        let ms = duration.map { formatDuration($0) }

        var lines: [String] = []
        lines.append(divider(icon: "❌", title: "ERROR", trailing: ms))
        lines.append("│ \(method) \(path)")
        lines.append("│ \(type(of: error)): \(error.localizedDescription)")
        lines.append(closeDivider())

        let output = lines.joined(separator: "\n")
        logger.error("\(output)")
        #endif
    }

    // MARK: - Session

    static func logSessionExpired() {
        #if DEBUG
        let output = [
            divider(icon: "🚪", title: "SESSION EXPIRED"),
            "│ All tokens cleared — user must re-authenticate",
            closeDivider()
        ].joined(separator: "\n")
        logger.warning("\(output)")
        #endif
    }
}

// MARK: - Formatting Helpers

#if DEBUG
private extension NetworkLogger {

    static func divider(icon: String, title: String, trailing: String? = nil) -> String {
        let base = "┌─ \(icon) \(title) "
        if let trailing {
            let padding = max(0, dividerWidth - base.count - trailing.count - 1)
            return base + String(repeating: "─", count: padding) + " " + trailing
        }
        let padding = max(0, dividerWidth - base.count)
        return base + String(repeating: "─", count: padding)
    }

    static func closeDivider() -> String {
        "└" + String(repeating: "─", count: dividerWidth - 1)
    }

    /// URL에서 baseURL을 제거하고 path + query만 표시
    static func formatPath(_ url: URL) -> String {
        var result = url.path
        if let query = url.query, !query.isEmpty {
            result += "?\(query)"
        }
        return result
    }

    /// 바이트 수를 사람이 읽기 쉬운 형태로 변환
    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    /// TimeInterval을 ms 단위 문자열로 변환
    static func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return "\(Int(duration * 1000))ms"
        }
        return String(format: "%.1fs", duration)
    }

    /// Authorization 헤더를 마스킹하여 표시
    static func formatAuthHeader(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "❌ None"
        }
        if value.hasPrefix("Bearer ") {
            let token = String(value.dropFirst("Bearer ".count))
            return "✅ Bearer \(maskToken(token))"
        }
        return "✅ \(String(value.prefix(20)))..."
    }

    /// 토큰의 마지막 4자리만 노출
    static func maskToken(_ token: String) -> String {
        guard token.count > 4 else { return "••••" }
        return "••••" + token.suffix(4)
    }

    /// 응답 body를 미리보기용으로 잘라서 반환
    static func formatBodyPreview(_ data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        guard let string = String(data: data, encoding: .utf8) else {
            return "<binary \(formatBytes(data.count))>"
        }

        if string.count <= bodyPreviewLimit {
            return string
        }

        return String(string.prefix(bodyPreviewLimit)) + "…"
    }

    /// HTTP 상태 코드에 따른 아이콘
    static func statusIcon(_ code: Int) -> String {
        switch code {
        case 200...299: return "🟢"
        case 300...399: return "🟡"
        case 401:       return "🟠"
        case 400...499: return "🔴"
        case 500...599: return "🔴"
        default:        return "⚪"
        }
    }
}
#endif
