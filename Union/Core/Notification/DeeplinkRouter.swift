import Foundation
import UIKit

// MARK: - Notification names (앱 내 broadcast)

extension Notification.Name {
    /// AppDelegate → MainTabView / AppFeature: 알림 탭/수신으로 도착한 deeplink.
    static let unionDeeplinkReceived = Notification.Name("union.deeplink.received")
    /// AppDelegate → BridgeHandler: 미니앱 SDK 에 notification:received 이벤트 전달.
    static let unionBridgeNotificationReceived = Notification.Name("union.bridge.notification.received")
}

// MARK: - Payload

/// Spring `FcmService.buildFcmData` 가 채워주는 키들을 디코딩한다.
struct DeeplinkPayload: Sendable, Equatable {
    let campaignId: String?
    let category: String?
    let deeplinkType: DeepType
    let appId: String?
    let path: String?
    let webUrl: String?
    let internalRoute: String?

    enum DeepType: String, Sendable {
        case MINIAPP, WEB, INTERNAL, NONE, UNKNOWN
    }

    init?(userInfo: [AnyHashable: Any]) {
        // FCM 표준 페이로드는 키가 String. Spring 의 data dictionary 가 그대로 들어온다.
        let typeRaw = (userInfo["deeplinkType"] as? String) ?? "NONE"
        self.deeplinkType = DeepType(rawValue: typeRaw) ?? .UNKNOWN
        self.campaignId = userInfo["campaignId"] as? String
        self.category = userInfo["category"] as? String
        self.appId = userInfo["appId"] as? String
        self.path = userInfo["path"] as? String
        self.webUrl = userInfo["webUrl"] as? String
        self.internalRoute = userInfo["internalRoute"] as? String
        // 캠페인 ID 가 하나도 없으면 유효한 union 알림이 아님 (다른 서비스의 푸시일 수도)
        if self.campaignId == nil && self.category == nil { return nil }
    }
}

// MARK: - Router

@MainActor
final class DeeplinkRouter {

    static let shared = DeeplinkRouter()

    enum Source: String { case coldLaunch, background, tap }

    private init() {}

    /// 알림 수신/탭 시 호출 — AppFeature 가 .onAppear 에서 등록한 listener 가 받아 처리한다.
    nonisolated func handle(userInfo: [AnyHashable: Any], source: Source) {
        guard let payload = DeeplinkPayload(userInfo: userInfo) else {
            return
        }

        // Source 가 .tap 이거나 .coldLaunch 인 경우 라우팅이 필요.
        // .background 는 사일런트 푸시 — UI 전환 없음, Bridge 이벤트만.
        switch source {
        case .background:
            broadcastToBridge(userInfo: userInfo)
        case .tap, .coldLaunch:
            let routerInfo: [String: Any] = [
                "payload": payload,
                "source": source.rawValue
            ]
            nonisolated(unsafe) let sendableInfo = routerInfo
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .unionDeeplinkReceived,
                    object: nil,
                    userInfo: sendableInfo
                )
            }
            broadcastToBridge(userInfo: userInfo)

            // WEB 타입 — 외부 Safari open (앱 내부 라우팅과 무관)
            if payload.deeplinkType == .WEB,
               let urlString = payload.webUrl,
               let url = URL(string: urlString) {
                DispatchQueue.main.async {
                    UIApplication.shared.open(url, options: [:])
                }
            }
        }
    }

    /// 미니앱 WebView 가 떠 있다면 SDK 에 notification:received 이벤트를 전달한다.
    /// 실제로는 BridgeHandler 가 NotificationCenter 를 구독해서 처리한다.
    nonisolated func broadcastToBridge(userInfo: [AnyHashable: Any]) {
        // 직렬화 가능한 dictionary 만 통과 — AnyHashable → String 키만 추출.
        var payload: [String: Any] = [:]
        for (k, v) in userInfo {
            if let key = k as? String { payload[key] = v }
        }
        nonisolated(unsafe) let sendablePayload = payload
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .unionBridgeNotificationReceived,
                object: nil,
                userInfo: sendablePayload
            )
        }
    }
}
