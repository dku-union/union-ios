import Foundation

// MARK: - AppCategory

struct AppCategory: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let emoji: String
    let colorHex: String
    let iconUrl: String?

    /// 카테고리 내부 이름에 해당하는 폴백 스타일 (이모지, 색상)
    static func fallbackStyle(for name: String) -> (emoji: String, colorHex: String) {
        switch name.uppercased() {
        case "FESTIVAL": return ("🎪", "FF6060")
        case "MEAL":     return ("🍚", "FFB547")
        case "STUDY":    return ("📚", "3B5BFF")
        case "MARKET":   return ("🛍️", "22C993")
        case "SOCIAL":   return ("💬", "8B5CF6")
        case "ETC":      return ("📦", "FF9A5C")
        default:         return ("📱", "8B8B8B")
        }
    }

    /// 카테고리 코드(MEAL 등)를 한글 표시명으로 변환. 미니앱 카드 카테고리 태그에 사용.
    static func localizedName(for name: String) -> String {
        switch name.uppercased() {
        case "FESTIVAL": return "축제"
        case "MEAL":     return "학식"
        case "STUDY":    return "스터디"
        case "MARKET":   return "거래"
        case "SOCIAL":   return "소통"
        case "ETC":      return "기타"
        default:         return name
        }
    }
}
