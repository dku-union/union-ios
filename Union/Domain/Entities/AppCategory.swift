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
}
