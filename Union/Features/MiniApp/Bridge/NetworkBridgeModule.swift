import Foundation

// MARK: - Network Bridge Module
// SDK: Union.network.request()
// 네이티브 URLSession으로 프록시 → mTLS 인증서 자동 첨부 가능

struct NetworkBridgeModule {

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {
        case "request":
            return try await performRequest(params: params)
        default:
            throw BridgeModuleError(code: "UNKNOWN_ACTION", message: "network.\(action) not found")
        }
    }

    private func performRequest(params: [String: Any]) async throws -> [String: Any] {
        guard let urlString = params["url"] as? String,
              let url = URL(string: urlString) else {
            throw BridgeModuleError(code: "INVALID_URL", message: "유효하지 않은 URL입니다")
        }

        let method = params["method"] as? String ?? "GET"
        let headers = params["headers"] as? [String: String] ?? [:]
        let body = params["body"]
        let timeout = params["timeout"] as? Double ?? 30000

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout / 1000

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            if let bodyData = body as? [String: Any] {
                request.httpBody = try? JSONSerialization.data(withJSONObject: bodyData)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } else if let bodyString = body as? String {
                request.httpBody = bodyString.data(using: .utf8)
            }
        }

        // TODO: mTLS 인증서 첨부를 위한 URLSessionDelegate 구현
        // let session = URLSession(configuration: .default, delegate: mTLSDelegate, delegateQueue: nil)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BridgeModuleError(code: "INVALID_RESPONSE", message: "서버 응답을 받지 못했습니다")
        }

        // 응답 헤더 변환
        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            responseHeaders[String(describing: key)] = String(describing: value)
        }

        // JSON 파싱 시도, 실패하면 텍스트
        let responseData: Any
        if let json = try? JSONSerialization.jsonObject(with: data) {
            responseData = json
        } else {
            responseData = String(data: data, encoding: .utf8) ?? ""
        }

        return [
            "statusCode": httpResponse.statusCode,
            "headers": responseHeaders,
            "data": responseData,
        ]
    }
}
