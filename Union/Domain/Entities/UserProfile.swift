import Foundation

// MARK: - UserProfile

struct UserProfile: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let nickname: String
    let university: String
    let department: String
    let isVerified: Bool
    let profileEmoji: String
    /// 서버 프로필 이미지 URL(공개). 없으면 `profileEmoji` 폴백.
    var profileImageUrl: String?

    init(
        id: UUID,
        nickname: String,
        university: String,
        department: String,
        isVerified: Bool,
        profileEmoji: String,
        profileImageUrl: String? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.university = university
        self.department = department
        self.isVerified = isVerified
        self.profileEmoji = profileEmoji
        self.profileImageUrl = profileImageUrl
    }
}
