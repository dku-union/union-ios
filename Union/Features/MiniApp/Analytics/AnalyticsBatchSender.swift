import Foundation

// MARK: - Analytics Batch Sender

/// Analytics 이벤트 배치를 백엔드로 HTTP POST 하는 전송 레이어 (Actor).
///
/// ### 전송 스펙
/// ```
/// POST /api/v1/analytics/events
/// Authorization: Bearer <access_token>
/// X-Request-ID: <UUID>           (멱등성)
/// X-Union-AppId: <appId>
/// X-Union-SDKVersion: 1.0.0
/// Content-Type: application/json
/// Body: { "events": [...] }
/// ```
///
/// ### 응답 처리
/// | HTTP | 처리 |
/// |------|------|
/// | 200/207 | 성공 (207 = 일부 거절, 로그만 기록) |
/// | 401 | 토큰 갱신 후 1회 재시도 |
/// | 5xx | `AnalyticsSendError.serverError` throw → Disk Queue 저장 |
actor AnalyticsBatchSender {

    // MARK: - Configuration

    private let session: URLSession
    private let sdkVersion = "1.0.0"
    private let requestTimeout: TimeInterval = 30

    // MARK: - Init

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Computed URL

    private var analyticsURL: URL {
        APIConfig.apiV1URL.appendingPathComponent("analytics/events")
    }

    // MARK: - Public API

    /// 이벤트 배치를 전송한다.
    ///
    /// - Parameters:
    ///   - events: 전송할 이벤트 목록 (최대 100개)
    ///   - appId:  미니앱 식별자
    /// - Throws: `AnalyticsSendError` on unrecoverable failure
    func send(events: [AnalyticsEventModel], appId: String) async throws {
        let requestId = UUID().uuidString

        // 1차 시도
        do {
            let token = try await TokenProvider.shared.validAccessToken()
            try await performRequest(events: events, appId: appId, token: token, requestId: requestId)
            return
        } catch AnalyticsSendError.unauthorized {
            // 2차 시도 (토큰 갱신 후)
        } catch {
            throw wrapError(error)
        }

        // 토큰 갱신 후 1회 재시도
        do {
            let refreshed = try await TokenProvider.shared.forceRefresh()
            try await performRequest(events: events, appId: appId, token: refreshed, requestId: requestId)
        } catch {
            throw wrapError(error)
        }
    }

    // MARK: - Private

    private func performRequest(
        events: [AnalyticsEventModel],
        appId: String,
        token: String,
        requestId: String
    ) async throws {
        var request = URLRequest(url: analyticsURL, timeoutInterval: requestTimeout)
        request.httpMethod  = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",  forHTTPHeaderField: "Authorization")
        request.setValue(requestId,          forHTTPHeaderField: "X-Request-ID")
        request.setValue(appId,              forHTTPHeaderField: "X-Union-AppId")
        request.setValue(sdkVersion,         forHTTPHeaderField: "X-Union-SDKVersion")
        request.httpBody = try JSONEncoder().encode(AnalyticsBatchRequest(events: events))

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AnalyticsSendError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            break

        case 207:
            // 일부 거절 — 로그 기록 후 성공으로 처리 (재전송 불필요)
            if let batchResp = try? JSONDecoder().decode(AnalyticsBatchResponse.self, from: data),
               batchResp.rejected > 0 {
                print("[Analytics] Partial reject: accepted=\(batchResp.accepted) rejected=\(batchResp.rejected)")
            }

        case 401:
            throw AnalyticsSendError.unauthorized

        case 429:
            throw AnalyticsSendError.rateLimited

        case 500...599:
            throw AnalyticsSendError.serverError(statusCode: http.statusCode)

        default:
            // 4xx 기타 → 이벤트 폐기 (재시도 무의미)
            print("[Analytics] Batch rejected HTTP \(http.statusCode)")
        }
    }

    private func wrapError(_ error: Error) -> AnalyticsSendError {
        if let e = error as? AnalyticsSendError { return e }
        return .networkError(error)
    }
}

// MARK: - Analytics Send Error

enum AnalyticsSendError: Error {
    case serverError(statusCode: Int)
    case rateLimited
    case networkError(Error)
    case invalidResponse
    case unauthorized

    /// true 이면 Disk Queue 에 저장하여 이후 재전송
    var shouldSaveToDiskQueue: Bool {
        switch self {
        case .serverError, .rateLimited, .networkError:
            return true
        case .invalidResponse, .unauthorized:
            return false
        }
    }
}
