import Foundation

// MARK: - AppCategory

struct AppCategory: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let name: String
    let emoji: String
    let colorHex: String
}
