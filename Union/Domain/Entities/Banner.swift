import Foundation

// MARK: - Banner

struct Banner: Identifiable, Hashable, Codable, Sendable {
    /// 백엔드 BIGSERIAL → Int. Mock(UUID) 호환을 위해 stableHash 기반 안정 변환 별도 제공.
    let id: Int
    /// CDN URL — 존재 시 비동기 이미지 렌더, 없으면 gradient+emoji 폴백 카드.
    let imageUrl: String?
    let title: String?
    let subtitle: String?
    let emoji: String?
    let gradientStartHex: String?
    let gradientEndHex: String?
    let linkType: LinkType
    /// linkType=MINI_APP → MiniApp.id 의 문자열, EXTERNAL_URL → https URL, NONE → nil
    let linkTarget: String?

    enum LinkType: String, Codable, Hashable, Sendable {
        case none = "NONE"
        case miniApp = "MINI_APP"
        case externalUrl = "EXTERNAL_URL"
    }
}
