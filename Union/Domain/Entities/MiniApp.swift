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
    /// CDN 배포 URL (예: https://cdn.union.app/apps/{appId}/{version}/index.html)
    let webUrl: String?
}
