import Foundation

// MARK: - Publisher Mini App

/// 퍼블리셔 전용 화면("내가 업로드 한 앱")에서 사용하는 미니앱 요약.
///
/// 백엔드 `MiniAppResponseDto` 와 1:1 매핑.
/// 일반 디스커버리 `MiniApp` 과 달리 status, workspaceName 정보를 포함한다.
struct PublisherMiniApp: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let iconUrl: String?
    let workspaceName: String
    let status: Status
    let createdAt: Date

    enum Status: String, Codable, Sendable, Hashable {
        case pending = "PENDING"
        case approved = "APPROVED"
        case suspended = "SUSPENDED"

        var displayLabel: String {
            switch self {
            case .pending: "심사 대기"
            case .approved: "승인됨"
            case .suspended: "일시 중단"
            }
        }
    }
}

// MARK: - App Version Info

/// AppVersion 요약 — `AppVersionResponseDto` 매핑.
struct AppVersionInfo: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let miniAppId: Int
    let miniAppName: String
    let publisherNickname: String
    let versionNumber: String
    let releaseNotes: String?
    let status: Status
    let buildFileUrl: String?
    let bundleSize: Int64?
    let testedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    /// Spring `VersionStatus` enum 그대로 매핑.
    enum Status: String, Codable, Sendable, Hashable {
        case draft = "DRAFT"
        case uploaded = "UPLOADED"
        case inReview = "IN_REVIEW"
        case accepted = "ACCEPTED"
        case rejected = "REJECTED"
        case deployed = "DEPLOYED"

        var displayLabel: String {
            switch self {
            case .draft: "초안"
            case .uploaded: "업로드 완료"
            case .inReview: "심사 중"
            case .accepted: "승인됨"
            case .rejected: "거절됨"
            case .deployed: "배포됨"
            }
        }

        /// 테스트 실행 가능 여부 — 번들이 GCS에 업로드된 모든 상태에서 가능.
        var isTestable: Bool {
            switch self {
            case .uploaded, .inReview, .accepted, .rejected, .deployed: true
            case .draft: false
            }
        }
    }
}
