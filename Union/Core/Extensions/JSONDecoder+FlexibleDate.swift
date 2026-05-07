import Foundation

// MARK: - Flexible ISO-8601 Date Decoding

/// Spring `LocalDateTime` 은 timezone 없이 직렬화된다 (예: `"2026-05-07T15:04:40.124557"`).
/// 반면 `Instant`/`OffsetDateTime` 은 `Z` 또는 offset 을 포함한다.
/// 클라이언트가 어느 쪽이든 받을 수 있도록 여러 포맷을 순차 시도한다.
extension JSONDecoder.DateDecodingStrategy {
    static let flexibleISO8601: JSONDecoder.DateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        if let date = FlexibleDateParser.shared.parse(raw) {
            return date
        }
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode ISO-8601 date: \(raw)"
        )
    }
}

private final class FlexibleDateParser: @unchecked Sendable {
    static let shared = FlexibleDateParser()

    private let withTZAndFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let withTZ: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Spring LocalDateTime: `"yyyy-MM-dd'T'HH:mm:ss[.fraction]"` (타임존 없음).
    /// 서버가 KST 환경에서 동작한다고 가정하고 Asia/Seoul 로 해석한다.
    private let springLocal: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS"
        return f
    }()

    private let springLocalNoFraction: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    func parse(_ string: String) -> Date? {
        if let d = withTZAndFraction.date(from: string) { return d }
        if let d = withTZ.date(from: string) { return d }

        // Spring LocalDateTime — fractional seconds 길이가 가변이므로 패딩.
        if let dot = string.firstIndex(of: ".") {
            let head = string[..<dot]
            let tailStart = string.index(after: dot)
            let tail = String(string[tailStart...])
            let padded = String((tail + String(repeating: "0", count: 9)).prefix(9))
            if let d = springLocal.date(from: "\(head).\(padded)") { return d }
        }
        if let d = springLocalNoFraction.date(from: string) { return d }
        return nil
    }
}
