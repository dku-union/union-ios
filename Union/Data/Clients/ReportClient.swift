import Foundation
import ComposableArchitecture

// MARK: - Report Client (TCA Dependency)

/// 신고 접수를 담당하는 의존성. 백엔드: `POST /reports` (201 Created).
/// 현재 iOS 에서는 미니앱 신고(targetType=MINI_APP)만 사용한다.
@DependencyClient
struct ReportClient: Sendable {
    var reportMiniApp: @Sendable (_ miniAppId: Int, _ reason: ReportReason, _ detail: String?) async throws -> Void
}

// MARK: - Report Reason (Spring ReportReason enum 과 1:1)

enum ReportReason: String, Codable, Sendable, CaseIterable, Identifiable {
    case POLICY_VIOLATION
    case HARASSMENT
    case SCAM
    case SPAM
    case INAPPROPRIATE_CONTENT
    case COPYRIGHT
    case OTHER

    var id: String { rawValue }

    /// 사용자에게 보여줄 한글 사유.
    var displayName: String {
        switch self {
        case .POLICY_VIOLATION: "정책 위반"
        case .HARASSMENT: "괴롭힘/폭언"
        case .SCAM: "사기/기만"
        case .SPAM: "스팸/도배"
        case .INAPPROPRIATE_CONTENT: "부적절한 콘텐츠"
        case .COPYRIGHT: "저작권 침해"
        case .OTHER: "기타"
        }
    }
}

// MARK: - DTOs

private struct CreateReportRequest: Encodable {
    let targetType: String
    let targetMiniAppId: Int?
    let reason: String
    let detail: String?
}

// MARK: - Error

enum ReportError: LocalizedError, Equatable {
    /// 이미 처리 중인 동일 신고가 있음 (서버 409).
    case alreadyReported
    /// 신고 대상이 존재하지 않음 (서버 404).
    case targetNotFound
    case failed

    var errorDescription: String? {
        switch self {
        case .alreadyReported: "이미 접수된 신고가 있습니다"
        case .targetNotFound: "신고 대상을 찾을 수 없습니다"
        case .failed: "신고 접수에 실패했습니다"
        }
    }
}

// MARK: - Live

extension ReportClient: DependencyKey {
    static let liveValue: ReportClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)
        let encoder = JSONEncoder()

        return ReportClient(
            reportMiniApp: { miniAppId, reason, detail in
                let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
                let body = try encoder.encode(CreateReportRequest(
                    targetType: "MINI_APP",
                    targetMiniAppId: miniAppId,
                    reason: reason.rawValue,
                    detail: (trimmed?.isEmpty == false) ? trimmed : nil
                ))
                do {
                    try await apiClient.send(.createReport(body: body))
                } catch APIError.httpError(let statusCode, _) {
                    switch statusCode {
                    case 409: throw ReportError.alreadyReported
                    case 404: throw ReportError.targetNotFound
                    default: throw ReportError.failed
                    }
                }
            }
        )
    }()
}

// MARK: - Test / Preview

extension ReportClient: TestDependencyKey {
    static let testValue = ReportClient()
    static let previewValue = ReportClient(reportMiniApp: { _, _, _ in })
}

extension DependencyValues {
    var reportClient: ReportClient {
        get { self[ReportClient.self] }
        set { self[ReportClient.self] = newValue }
    }
}
