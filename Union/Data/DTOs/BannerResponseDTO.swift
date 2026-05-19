import Foundation

// MARK: - Banner API Response (GET /banners)

struct BannerResponse: Codable, Sendable {
    let id: Int
    let imageUrl: String?
    let title: String?
    let subtitle: String?
    let emoji: String?
    let gradientStartHex: String?
    let gradientEndHex: String?
    let linkType: String         // "NONE" | "MINI_APP" | "EXTERNAL_URL"
    let linkTarget: String?

    func toBanner() -> Banner {
        Banner(
            id: id,
            imageUrl: imageUrl,
            title: title,
            subtitle: subtitle,
            emoji: emoji,
            gradientStartHex: gradientStartHex,
            gradientEndHex: gradientEndHex,
            linkType: Banner.LinkType(rawValue: linkType) ?? .none,
            linkTarget: linkTarget
        )
    }
}
