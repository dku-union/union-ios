import Foundation

// MARK: - MiniApp

struct MiniApp: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let description: String
    let publisher: String
    let category: String
    let iconUrl: String?
    let iconEmoji: String?
    let iconColorHex: String?
    let rating: Double
    let ratingCount: Int
    let isNew: Bool
    let isPopular: Bool
    let createdAt: Date
    /// CDN 배포 URL (예: https://cdn.union.app/apps/{appId}/{version}/index.html)
    let webUrl: String?
    /// union.config.json 의 appId (reverse-domain, e.g. "com.union.soccer").
    /// Analytics 이벤트 식별 키. 백엔드 API 응답에 없으면 nil (fallback 사용).
    let appId: String?
}

// MARK: - Backward Compatible Init

extension MiniApp {
    /// appId 를 지정하지 않는 하위 호환 이니셜라이저.
    /// MockData 및 appId 를 아직 제공하지 않는 코드 경로에서 사용.
    init(
        id: Int, name: String, description: String, publisher: String,
        category: String, iconUrl: String?, iconEmoji: String?, iconColorHex: String?,
        rating: Double, ratingCount: Int, isNew: Bool, isPopular: Bool,
        createdAt: Date, webUrl: String?
    ) {
        self.init(
            id: id, name: name, description: description, publisher: publisher,
            category: category, iconUrl: iconUrl, iconEmoji: iconEmoji, iconColorHex: iconColorHex,
            rating: rating, ratingCount: ratingCount, isNew: isNew, isPopular: isPopular,
            createdAt: createdAt, webUrl: webUrl, appId: nil
        )
    }
}
