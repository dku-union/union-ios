import Foundation
import WebKit
import UIKit
import CoreLocation

// MARK: - Bridge Request / Response (SDK 프로토콜 매칭)

struct BridgeRequest: Decodable {
    let id: String
    let module: String
    let action: String
    let params: [String: AnyCodable]?
    let sdkVersion: String
    let timestamp: Double
}

struct BridgeResponse: Encodable {
    let id: String
    let success: Bool
    let data: AnyCodable?
    let error: BridgeErrorPayload?
}

struct BridgeErrorPayload: Encodable {
    let code: String
    let message: String
}

// MARK: - AnyCodable (JSON 브릿지용)

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = NSNull() }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = string }
        else if let array = try? container.decode([AnyCodable].self) { value = array.map(\.value) }
        else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let bool as Bool: try container.encode(bool)
        case let int as Int: try container.encode(int)
        case let double as Double: try container.encode(double)
        case let string as String: try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }
}

// MARK: - BridgeHandler

/// WKScriptMessageHandler: SDK의 postMessage를 수신 → 모듈 라우팅 → 응답 전송
@MainActor
final class BridgeHandler: NSObject, WKScriptMessageHandler {

    private weak var webView: WKWebView?
    private let miniApp: MiniApp
    weak var navigationController: MiniAppNavigationController?

    // 모듈 핸들러
    private lazy var authModule = AuthBridgeModule()
    private lazy var uiModule = UIBridgeModule()
    private lazy var deviceModule = DeviceBridgeModule()
    private lazy var storageModule: StorageBridgeModule = {
        StorageBridgeModule(appId: miniApp.id.uuidString)
    }()
    private lazy var analyticsModule = AnalyticsBridgeModule()
    private lazy var networkModule = NetworkBridgeModule()

    init(miniApp: MiniApp) {
        self.miniApp = miniApp
        super.init()
    }

    func attach(to webView: WKWebView) {
        self.webView = webView
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "union" else { return }

        // WKWebView는 postMessage의 인자를 자동으로 NSDictionary로 변환
        guard let body = message.body as? [String: Any],
              let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let request = try? JSONDecoder().decode(BridgeRequest.self, from: jsonData) else {
            print("[Bridge] Failed to parse request: \(message.body)")
            return
        }

        Task {
            let response = await handleRequest(request)
            sendResponse(response)
        }
    }

    // MARK: - 모듈 라우팅

    private func handleRequest(_ request: BridgeRequest) async -> BridgeResponse {
        let params = request.params?.mapValues(\.value) ?? [:]

        do {
            let result: Any? = try await routeToModule(
                module: request.module,
                action: request.action,
                params: params
            )

            return BridgeResponse(
                id: request.id,
                success: true,
                data: result.map { AnyCodable($0) },
                error: nil
            )
        } catch let error as BridgeModuleError {
            return BridgeResponse(
                id: request.id,
                success: false,
                data: nil,
                error: BridgeErrorPayload(code: error.code, message: error.message)
            )
        } catch {
            return BridgeResponse(
                id: request.id,
                success: false,
                data: nil,
                error: BridgeErrorPayload(code: "NATIVE_ERROR", message: error.localizedDescription)
            )
        }
    }

    private func routeToModule(module: String, action: String, params: [String: Any]) async throws -> Any? {
        // [String: Any]는 Sendable이 아니지만, 이 params는 현재 Task 내에서만 사용되므로 안전
        nonisolated(unsafe) let params = params
        nonisolated(unsafe) let storageModule = self.storageModule
        nonisolated(unsafe) let webView = self.webView

        switch module {
        case "auth":      return try await authModule.handle(action: action, params: params)
        case "ui":        return try await uiModule.handle(action: action, params: params, webView: webView)
        case "device":    return try await deviceModule.handle(action: action, params: params)
        case "storage":   return try await storageModule.handle(action: action, params: params)
        case "analytics": return try await analyticsModule.handle(action: action, params: params)
        case "network":   return try await networkModule.handle(action: action, params: params)
        case "navigation":
            switch action {
            case "push":
                let url = params["url"] as? String ?? "/"
                let title = params["title"] as? String
                let animated = (params["animated"] as? Bool) ?? true
                navigationController?.handlePush(url: url, title: title, animated: animated)
            case "back":
                navigationController?.handleBack()
            case "replace":
                let url = params["url"] as? String ?? "/"
                navigationController?.handleReplace(url: url)
            case "prefetch":
                let url = params["url"] as? String ?? "/"
                navigationController?.handlePrefetch(url: url)
            case "willNavigate":
                // SPA pushState 직전 — 스냅샷 캡처 트리거
                NotificationCenter.default.post(name: .miniAppWillNavigate, object: nil)
            case "stateChange":
                // SPA depth 변경 알림
                let depth = (params["depth"] as? Int) ?? 0
                NotificationCenter.default.post(
                    name: .miniAppSpaStateChange, object: nil,
                    userInfo: ["depth": depth, "canGoBack": depth > 0]
                )
            default: break
            }
            return nil
        case "debug":
            let level = params["level"] as? String ?? "log"
            let message = params["message"] as? String ?? ""
            print("[WebView \(level)] \(message)")
            return nil
        default:
            throw BridgeModuleError(code: "UNKNOWN_MODULE", message: "Unknown module: \(module)")
        }
    }

    // MARK: - 응답 전송 (CustomEvent dispatch)

    private func sendResponse(_ response: BridgeResponse) {
        guard let webView else { return }
        guard let jsonData = try? JSONEncoder().encode(response),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let js = "window.dispatchEvent(new CustomEvent('union-bridge-response', { detail: \(jsonString) }));"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                print("[Bridge] Failed to send response: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 네이티브 → SDK 이벤트 푸시

    func sendEvent(_ event: String, data: Any? = nil) {
        guard let webView else { return }

        var eventObj: [String: Any] = ["type": "event", "event": event]
        if let data { eventObj["data"] = data }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: eventObj),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }

        let js = "window.dispatchEvent(new CustomEvent('union-bridge-event', { detail: \(jsonString) }));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - Bridge Module Error

struct BridgeModuleError: Error {
    let code: String
    let message: String
}
