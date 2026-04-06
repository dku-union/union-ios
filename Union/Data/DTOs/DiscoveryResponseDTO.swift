import Foundation

// MARK: - Discovery API Response (GET /mini-apps/discovery)

struct DiscoveryResponse: Codable, Sendable {
    let recentApps: [MiniAppLiteResponse]
    let popularApps: [MiniAppLiteResponse]
    let newApps: [MiniAppLiteResponse]
    let recommendedApps: [MiniAppLiteResponse]
    let trendingKeywords: [String]
    let categories: [CategoryResponse]
}

// MARK: - MiniAppLiteDto 매핑

struct MiniAppLiteResponse: Codable, Sendable {
    let id: Int
    let name: String
    let appId: String?
    let iconUrl: String?
    let publisherName: String
    let category: CategoryResponse?
    let rating: Double?

    func toMiniApp() -> MiniApp {
        let categoryName = category?.name ?? ""
        let style = AppCategory.fallbackStyle(for: categoryName)
        return MiniApp(
            id: id,
            name: name,
            description: "",
            publisher: publisherName,
            category: categoryName,
            iconUrl: iconUrl,
            iconEmoji: style.emoji,
            iconColorHex: style.colorHex,
            rating: rating ?? 0.0,
            ratingCount: 0,
            isNew: false,
            isPopular: false,
            createdAt: Date(),
            webUrl: nil,
            appId: appId
        )
    }
}

// MARK: - MiniAppCategoryResponseDto 매핑

struct CategoryResponse: Codable, Sendable {
    let id: Int
    let name: String
    let displayName: String
    let iconUrl: String?

    func toAppCategory() -> AppCategory {
        let style = AppCategory.fallbackStyle(for: name)
        return AppCategory(
            id: id,
            name: displayName,
            emoji: style.emoji,
            colorHex: style.colorHex,
            iconUrl: iconUrl
        )
    }
}
