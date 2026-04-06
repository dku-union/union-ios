import Foundation
import os.log

// MARK: - Analytics Bridge Module

/// SDK `analytics` 모듈 브릿지 핸들러.
///
/// SDK에서 지원하는 actions:
/// | action | 설명 |
/// |--------|------|
/// | `track` | 통합 이벤트 (모든 eventType 처리) |
/// | `setUserProperty` | 사용자 속성 설정 (세션 내 모든 이벤트에 첨부됨) |
/// | `trackEvent` | 구 호환성 — `track(eventType: custom)` 으로 변환 |
/// | `trackPageView` | 구 호환성 — `track(eventType: screen)` 으로 변환 |
struct AnalyticsBridgeModule {

    private let logger = Logger(subsystem: "app.union", category: "analytics")

    // MARK: - Handle

    func handle(action: String, params: [String: Any]) async throws -> Any? {
        switch action {

        // MARK: track (통합 이벤트 — SDK 1.0+)
        case "track":
            guard let payload = TrackPayload.from(params) else {
                throw BridgeModuleError(
                    code: "INVALID_PAYLOAD",
                    message: "analytics.track requires eventType, eventName"
                )
            }
            await AnalyticsManager.shared.track(payload: payload)
            return nil

        // MARK: setUserProperty
        case "setUserProperty":
            guard let key = params["key"] as? String, !key.isEmpty,
                  let rawValue = params["value"],
                  let analyticsValue = AnalyticsValue.from(rawValue) else {
                throw BridgeModuleError(
                    code: "INVALID_PAYLOAD",
                    message: "analytics.setUserProperty requires key (String) and value (String|Number|Bool)"
                )
            }
            await AnalyticsManager.shared.setUserProperty(key: key, value: analyticsValue)
            return nil

        // MARK: trackEvent (하위 호환성 — SDK 0.x)
        case "trackEvent":
            let eventName = params["eventName"] as? String ?? "unknown"
            let rawParams = params["params"] as? [String: Any]
            let payload = TrackPayload(
                eventType: AnalyticsEventType.custom,
                eventName: eventName,
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                params: rawParams.map { convertParams($0) }
            )
            await AnalyticsManager.shared.track(payload: payload)
            return nil

        // MARK: trackPageView (하위 호환성 — SDK 0.x)
        case "trackPageView":
            let pageName = params["pageName"] as? String ?? "unknown"
            let payload = TrackPayload(
                eventType: AnalyticsEventType.screen,
                eventName: "screen_view",
                timestamp: Int64(Date().timeIntervalSince1970 * 1000),
                params: ["pageName": .string(pageName)]
            )
            await AnalyticsManager.shared.track(payload: payload)
            return nil

        default:
            throw BridgeModuleError(
                code: "UNKNOWN_ACTION",
                message: "analytics.\(action) is not supported"
            )
        }
    }
}
