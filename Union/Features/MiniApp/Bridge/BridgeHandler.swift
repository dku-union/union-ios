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

    // MARK: - Analytics
    /// 이 BridgeHandler 가 담당하는 미니앱의 Analytics appId.
    private let analyticsAppId: String

    // 모듈 핸들러
    private lazy var authModule = AuthBridgeModule(miniAppId: miniApp.id)
    private lazy var uiModule = UIBridgeModule()
    private lazy var deviceModule = DeviceBridgeModule()
    private lazy var storageModule: StorageBridgeModule = {
        StorageBridgeModule(appId: String(miniApp.id))
    }()
    private lazy var analyticsModule = AnalyticsBridgeModule()
    private lazy var networkModule = NetworkBridgeModule()
    private lazy var notificationModule = NotificationBridgeModule(miniAppAppId: miniApp.appId)

    /// AppDelegate → DeeplinkRouter 가 broadcast 한 push 페이로드를 구독하는 Task.
    private var notificationObserverTask: Task<Void, Never>?

    init(miniApp: MiniApp) {
        self.miniApp = miniApp
        // appId: union.config.json 값 우선, 없으면 fallback
        self.analyticsAppId = miniApp.appId ?? "miniapp.\(miniApp.id)"
        super.init()

        // Analytics 세션 시작 (멱등적 — 같은 appId 이면 기존 세션 재사용)
        Task {
            await AnalyticsManager.shared.openSession(appId: analyticsAppId)
        }

        // Native → SDK: 원격 푸시 수신 시 미니앱 WebView 안 SDK 에 'notification:received' 이벤트 전달.
        let myAppId = miniApp.appId
        notificationObserverTask = Task { @MainActor [weak self] in
            for await note in NotificationCenter.default.notifications(
                named: .unionBridgeNotificationReceived
            ) {
                guard let self else { return }
                nonisolated(unsafe) let info = note.userInfo ?? [:]
                // 매니페스트 appId 가 일치하는 미니앱만 자기 이벤트로 수신.
                let payloadAppId = info["appId"] as? String
                if let payloadAppId, let myAppId, payloadAppId != myAppId {
                    continue
                }
                self.sendEvent("notification:received", data: info)
            }
        }
    }

    deinit {
        notificationObserverTask?.cancel()
    }

    // MARK: - Analytics Lifecycle Hooks

    /// 첫 페이지 WebView 로드 완료 시 호출 (WKNavigationDelegate.didFinish 에서 트리거).
    /// 반복 호출되지 않도록 AnalyticsManager 내부에서 중복 방지.
    func notifyWebViewDidLoad() {
        Task {
            await AnalyticsManager.shared.trackLifecycle(eventName: "app_open")
        }
    }

    /// 미니앱 종료 시 호출 (onClose 콜백에서 트리거).
    func notifyMiniAppClosed() {
        Task {
            await AnalyticsManager.shared.closeSession()
        }
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
        // 권한 게이트 — 동의되지 않은(선언 후 거부) 스코프를 요구하는 호출을 차단.
        // 동의가 확립되지 않은 앱은 PermissionStore 가 fail-open 으로 통과시킨다(기존 앱 미파손).
        if let scope = Self.requiredScope(module: module, action: action),
           !PermissionStore.shared.isAllowed(appId: miniApp.id, scope: scope) {
            throw BridgeModuleError(
                code: "PERMISSION_DENIED",
                message: "'\(scope.rawValue)' 권한이 거부되었습니다"
            )
        }

        // [String: Any]는 Sendable이 아니지만, 이 params는 현재 Task 내에서만 사용되므로 안전
        nonisolated(unsafe) let params = params
        nonisolated(unsafe) let storageModule = self.storageModule
        nonisolated(unsafe) let webView = self.webView

        switch module {
        case "auth":
            let result = try await authModule.handle(action: action, params: params)
            // getUserProfile: email/university 는 필드 단위 게이팅 — 미허용 스코프는 응답에서 제거.
            if action == "getUserProfile", var profile = result as? [String: Any] {
                let appId = miniApp.id
                if !PermissionStore.shared.isAllowed(appId: appId, scope: .userEmail) {
                    profile.removeValue(forKey: "email")
                }
                if !PermissionStore.shared.isAllowed(appId: appId, scope: .userUniversity) {
                    profile.removeValue(forKey: "university")
                }
                return profile
            }
            return result
        case "ui":        return try await uiModule.handle(action: action, params: params, webView: webView)
        case "device":    return try await deviceModule.handle(action: action, params: params)
        case "storage":   return try await storageModule.handle(action: action, params: params)
        case "analytics": return try await analyticsModule.handle(action: action, params: params)
        case "network":
            // 상대경로 URL → WebView 현재 URL 기준으로 절대경로 resolve.
            // URLSession은 scheme 없는 URL을 처리 못하므로 여기서 변환한다.
            var networkParams = params
            if let urlString = params["url"] as? String,
               !urlString.hasPrefix("http://"), !urlString.hasPrefix("https://"),
               let base = webView?.url,
               let resolved = URL(string: urlString, relativeTo: base) {
                networkParams["url"] = resolved.absoluteString
            }
            return try await networkModule.handle(action: action, params: networkParams)
        case "notification":
            return try await notificationModule.handle(action: action, params: params)
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

    // MARK: - 권한 매핑

    /// (module, action) → 호출에 필요한 권한 스코프. 매핑이 없으면 게이트 없음.
    /// SDK MockAdapter / 백엔드 계약과 동일한 규칙을 유지한다.
    ///
    /// `auth.getUserProfile` 의 `user.profile` 은 **umbrella 게이트**다 — 거부 시 프로필 호출 전체가
    /// 차단된다(nickname/userId 포함). `user.email` / `user.university` 는 그 위에 얹히는 **필드 단위**
    /// 스코프로, getUserProfile 통과 후 응답에서 개별 제거된다(routeToModule 의 auth case 참고).
    /// 따라서 미니앱이 email/university 를 쓰려면 `user.profile` 도 함께 선언/허용되어야 한다.
    ///
    /// 비고: `notification` 의 읽기·취소 계열(getPermissionStatus/getDeviceToken/cancelLocal/cancelAllLocal)과
    /// `device.vibrate`·`device.clipboard`, ui/network/analytics/navigation 은 게이트 대상이 아니다.
    static func requiredScope(module: String, action: String) -> PermissionScope? {
        switch (module, action) {
        case ("auth", "getUserProfile"):
            return .userProfile
        case ("device", "getLocation"):
            return .deviceLocation
        case ("device", "scanQRCode"):
            return .deviceCamera
        case ("storage", "get"), ("storage", "set"), ("storage", "remove"), ("storage", "clear"):
            return .deviceStorage
        case ("notification", "requestPermission"), ("notification", "scheduleLocal"),
             ("notification", "subscribe"), ("notification", "unsubscribe"), ("notification", "setPushEnabled"):
            return .notification
        default:
            return nil
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
