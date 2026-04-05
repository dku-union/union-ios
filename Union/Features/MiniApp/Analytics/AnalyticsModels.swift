import Foundation

// MARK: - Analytics Value (Encodable primitive wrapper)

/// Analytics 이벤트 파라미터 값 타입.
/// SDK params 는 string | number | boolean 만 허용하므로 열거형으로 제한.
/// Codable 로 DiskQueue JSON 저장/복원을 지원한다.
enum AnalyticsValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v):    try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v):   try container.encode(v)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool 을 Int 보다 먼저 시도 (JSON true/false 가 Int 1/0 으로 오해받는 것 방지)
        if let v = try? container.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? container.decode(Int.self)    { self = .int(v);    return }
        if let v = try? container.decode(Double.self) { self = .double(v); return }
        if let v = try? container.decode(String.self) { self = .string(v); return }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "AnalyticsValue: unsupported JSON value"
        )
    }

    /// `Any` 값을 `AnalyticsValue` 로 변환. 지원 타입이 아니면 nil.
    static func from(_ value: Any) -> AnalyticsValue? {
        switch value {
        case let v as Bool:   return .bool(v)
        case let v as Int:    return .int(v)
        case let v as Double: return .double(v)
        case let v as Float:  return .double(Double(v))
        case let v as String: return .string(v)
        case let v as NSNumber:
            // NSNumber 는 Bool / Int / Double 로 disambiguate
            if CFGetTypeID(v) == CFBooleanGetTypeID() { return .bool(v.boolValue) }
            let d = v.doubleValue
            if d == Double(v.intValue) && !d.isInfinite { return .int(v.intValue) }
            return .double(d)
        default:
            return nil
        }
    }

    var rawValue: Any {
        switch self {
        case .string(let v): return v
        case .int(let v):    return v
        case .double(let v): return v
        case .bool(let v):   return v
        }
    }
}

// MARK: - Track Payload (Bridge → Analytics)

/// SDK 브릿지에서 `analytics.track` 액션으로 전달되는 페이로드.
/// SDK `TrackingPayload` 와 1:1 대응.
struct TrackPayload {
    let eventType: String       // lifecycle | screen | performance | error | custom | conversion
    let eventName: String       // e.g. "join_club", "screen_view"
    let timestamp: Int64        // epoch ms (client-side)
    let params: [String: AnalyticsValue]?

    /// `[String: Any]` 브릿지 파라미터에서 생성
    static func from(_ raw: [String: Any]) -> TrackPayload? {
        guard
            let eventType = raw["eventType"] as? String,
            let eventName = raw["eventName"] as? String
        else { return nil }

        let ts = (raw["timestamp"] as? Double).map { Int64($0) } ?? Int64(Date().timeIntervalSince1970 * 1000)
        let rawParams = raw["params"] as? [String: Any]

        return TrackPayload(
            eventType: eventType,
            eventName: eventName,
            timestamp: ts,
            params: rawParams.map { convertParams($0) }
        )
    }
}

/// `[String: Any]` → `[String: AnalyticsValue]` 변환 (PII 마스킹 전 단계)
func convertParams(_ raw: [String: Any]) -> [String: AnalyticsValue] {
    var result: [String: AnalyticsValue] = [:]
    for (key, value) in raw {
        if let v = AnalyticsValue.from(value) {
            result[key] = v
        }
    }
    return result
}

// MARK: - Analytics Event Model (Backend 전송용)

/// 백엔드 `POST /api/v1/analytics/events` 에 전송되는 개별 이벤트.
/// `RawEventDto` (Spring) 와 필드 1:1 대응.
/// `Codable` 로 DiskQueue JSON 저장/복원을 지원한다.
struct AnalyticsEventModel: Codable {

    // 이벤트 식별
    let eventType: String
    let eventName: String

    // 타이밍
    let clientTimestamp: Int64      // epoch ms

    // 세션
    let sessionId: String
    let superappSessionId: String

    // 사용자 (프라이버시 보존 — 원본 userId 미포함)
    let hashedUserId: String?       // SHA-256(userId:appId)

    // 앱 컨텍스트
    let appId: String
    let appVersion: String
    let sdkVersion: String

    // 플랫폼
    let platform: String            // "ios"
    let osVersion: String
    let deviceModel: String

    // 순서
    let sequenceNumber: Int

    // 페이로드
    let params: [String: AnalyticsValue]?
    let userProperties: [String: AnalyticsValue]?
}

// MARK: - Batch Request / Response

struct AnalyticsBatchRequest: Encodable {
    let events: [AnalyticsEventModel]
}

struct AnalyticsBatchResponse: Decodable {
    let accepted: Int
    let rejected: Int
    let errors: [IngestError]

    struct IngestError: Decodable {
        let index: Int
        let code: String
        let message: String
    }
}

// MARK: - Analytics Event Type Constants

enum AnalyticsEventType {
    static let lifecycle  = "lifecycle"
    static let screen     = "screen"
    static let performance = "performance"
    static let error      = "error"
    static let custom     = "custom"
    static let conversion = "conversion"
}
