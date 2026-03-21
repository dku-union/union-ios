import Foundation

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let nickname: String
    let university: String
    let department: String
    let isVerified: Bool
    let profileEmoji: String
}
