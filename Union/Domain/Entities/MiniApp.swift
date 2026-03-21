import Foundation

// MARK: - MiniApp

struct MiniApp: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let publisher: String
    let categoryId: UUID
    let iconEmoji: String
    let iconColorHex: String
    let rating: Double
    let ratingCount: Int
    let isNew: Bool
    let isPopular: Bool
    let createdAt: Date
}
