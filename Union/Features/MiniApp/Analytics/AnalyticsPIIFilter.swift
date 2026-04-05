import Foundation

// MARK: - Analytics PII Filter

/// 이벤트 파라미터에서 개인식별정보(PII)를 감지하여 마스킹하는 필터.
///
/// SDK(JS)에서 1차 마스킹 후 네이티브에서 2차 마스킹 (Defense-in-depth).
/// JS 코드는 조작 가능하므로 네이티브 필터가 최종 방어선.
///
/// 적용 패턴:
/// - 이메일 주소
/// - 전화번호 (국내 형식)
/// - 주민등록번호
/// - 신용카드 번호
struct AnalyticsPIIFilter {

    private static let placeholder = "[REDACTED]"

    /// 마스킹 패턴 목록 (정규식 캐싱으로 반복 컴파일 방지)
    private static let patterns: [(regex: NSRegularExpression, label: String)] = {
        let patterns: [(String, String)] = [
            (#"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}"#,           "email"),
            (#"\d{3}[-.\s]?\d{3,4}[-.\s]?\d{4}"#,                              "phone"),
            (#"\d{6}-[1-4]\d{6}"#,                                              "rrno"),
            (#"\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}"#,                   "card"),
        ]
        return patterns.compactMap { (pattern, label) in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            return (regex, label)
        }
    }()

    // MARK: - Public API

    /// params 딕셔너리의 모든 문자열 값에서 PII 마스킹
    func filter(_ params: [String: AnalyticsValue]) -> [String: AnalyticsValue] {
        var result: [String: AnalyticsValue] = [:]
        for (key, value) in params {
            if case .string(let str) = value {
                result[key] = .string(maskPII(in: str))
            } else {
                result[key] = value
            }
        }
        return result
    }

    /// 단일 문자열에서 PII 마스킹
    func maskPII(in text: String) -> String {
        var result = text
        for (regex, _) in Self.patterns {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: Self.placeholder
            )
        }
        return result
    }
}
