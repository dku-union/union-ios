import Foundation

// MARK: - Banner

struct Banner: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let title: String
    let subtitle: String
    let gradientStartHex: String
    let gradientEndHex: String
    let emoji: String
}
