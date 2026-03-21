import Foundation

// MARK: - AppNotification

struct AppNotification: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let type: NotificationType
    let isRead: Bool
    let createdAt: Date

    enum NotificationType: String, Hashable, Codable, Sendable {
        case update
        case recommendation
        case announcement
    }
}
