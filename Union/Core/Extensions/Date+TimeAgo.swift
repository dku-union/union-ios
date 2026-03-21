import Foundation

extension Date {
    func timeAgoDisplay() -> String {
        let seconds = Int(-timeIntervalSinceNow)
        if seconds < 60 { return "방금 전" }
        if seconds < 3600 { return "\(seconds / 60)분 전" }
        if seconds < 86400 { return "\(seconds / 3600)시간 전" }
        if seconds < 604800 { return "\(seconds / 86400)일 전" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: self)
    }
}
