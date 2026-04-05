import Foundation

// MARK: - Token Provider

/// 토큰 생명주기를 관리하는 중앙 액터
///
/// 세 가지 핵심 전략을 구현:
/// 1. **Proactive 갱신** — JWT exp 확인 후 만료 전 사전 갱신
/// 2. **직렬화** — 동시 다발 갱신 요청을 단일 네트워크 호출로 병합
/// 3. **세션 만료 브로드캐스트** — 갱신 불가 시 NotificationCenter로 앱 전체에 알림
actor TokenProvider {

    static let shared = TokenProvider()

    /// 세션이 만료되어 재로그인이 필요할 때 발송되는 Notification
    static let sessionExpiredNotification = Notification.Name("com.union.sessionExpired")

    // MARK: - Configuration

    private let session: URLSession
    private let refreshURL: URL
    private let decoder: JSONDecoder

    /// 만료 전 사전 갱신 기준 시간 (초)
    /// - accessToken 만료 60초 전부터 proactive refresh 대상
    private let proactiveThreshold: TimeInterval = 60

    /// refresh 요청 타임아웃 (초)
    private let requestTimeout: TimeInterval = 15

    // MARK: - Concurrency State

    /// 현재 진행 중인 갱신 Task (동시 요청 직렬화용)
    /// - 첫 번째 401을 받은 요청만 실제 네트워크 호출을 수행
    /// - 이후 요청들은 이 Task의 결과를 공유
    private var activeRefreshTask: Task<String, Error>?

    // MARK: - Init

    private init(
        session: URLSession = .shared,
        refreshURL: URL = APIConfig.authURL.appendingPathComponent("/refresh")
    ) {
        self.session = session
        self.refreshURL = refreshURL
        self.decoder = JSONDecoder()
    }

    // MARK: - Public API

    /// 유효한 accessToken을 반환
    /// - 만료 임박 시 자동으로 proactive refresh 수행
    /// - Throws: `TokenError` (토큰 없음, 갱신 실패 등)
    func validAccessToken() async throws -> String {
        guard let accessToken = KeychainStore.load(.accessToken) else {
            throw TokenError.noAccessToken
        }

        if let payload = JWTDecoder.decode(accessToken),
           payload.isExpiring(within: proactiveThreshold) {
            NetworkLogger.logProactiveRefresh(expiresIn: payload.expiresAt.timeIntervalSinceNow)
            return try await executeSerializedRefresh()
        }

        return accessToken
    }

    /// 강제 토큰 갱신 (401 응답 후 호출)
    /// - Returns: 갱신된 accessToken
    @discardableResult
    func forceRefresh() async throws -> String {
        try await executeSerializedRefresh()
    }

    // MARK: - Serialized Refresh

    /// 동시 갱신 요청을 단일 네트워크 호출로 병합
    ///
    /// 동작 원리:
    /// 1. `activeRefreshTask`가 존재하면 → 기존 Task의 결과를 await
    /// 2. 없으면 → 새 Task 생성, 이후 요청은 1번 경로로 합류
    /// 3. Task 완료 시 → `activeRefreshTask` 초기화, 다음 갱신은 새 Task 생성
    private func executeSerializedRefresh() async throws -> String {
        if let existingTask = activeRefreshTask {
            return try await existingTask.value
        }

        let task = Task<String, Error> {
            defer { self.activeRefreshTask = nil }

            guard let refreshToken = KeychainStore.load(.refreshToken) else {
                self.broadcastSessionExpired()
                throw TokenError.noRefreshToken
            }

            NetworkLogger.logTokenRefreshStart()
            let start = CFAbsoluteTimeGetCurrent()

            do {
                let response = try await self.performRefreshRequest(refreshToken: refreshToken)
                KeychainStore.save(response.accessToken, for: .accessToken)
                KeychainStore.save(response.refreshToken, for: .refreshToken)

                let duration = CFAbsoluteTimeGetCurrent() - start
                NetworkLogger.logTokenRefreshResult(success: true, duration: duration)

                return response.accessToken
            } catch let error as TokenError where error.requiresReAuthentication {
                let duration = CFAbsoluteTimeGetCurrent() - start
                NetworkLogger.logTokenRefreshResult(success: false, duration: duration, error: error)
                self.broadcastSessionExpired()
                throw error
            } catch {
                let duration = CFAbsoluteTimeGetCurrent() - start
                NetworkLogger.logTokenRefreshResult(success: false, duration: duration, error: error)
                throw error
            }
        }

        activeRefreshTask = task
        return try await task.value
    }

    // MARK: - Network

    private func performRefreshRequest(refreshToken: String) async throws -> TokenRefreshResponse {
        var request = URLRequest(url: refreshURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeout
        request.httpBody = try JSONEncoder().encode(RefreshRequestBody(refreshToken: refreshToken))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw TokenError.networkError
        }

        guard let http = response as? HTTPURLResponse else {
            throw TokenError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            do {
                return try decoder.decode(TokenRefreshResponse.self, from: data)
            } catch {
                throw TokenError.decodingFailed
            }
        case 401, 403:
            // refresh token 자체가 만료되었거나 무효화됨
            throw TokenError.refreshTokenExpired
        default:
            throw TokenError.serverError(statusCode: http.statusCode)
        }
    }

    // MARK: - Session Expiration

    /// 토큰을 모두 삭제하고 앱 전체에 세션 만료를 알림
    private func broadcastSessionExpired() {
        activeRefreshTask?.cancel()
        activeRefreshTask = nil
        KeychainStore.clearAll()
        NetworkLogger.logSessionExpired()

        Task { @MainActor in
            NotificationCenter.default.post(name: Self.sessionExpiredNotification, object: nil)
        }
    }
}

// MARK: - Internal DTOs

private struct RefreshRequestBody: Encodable {
    let refreshToken: String
}

private struct TokenRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

// MARK: - Token Error

enum TokenError: LocalizedError {
    /// Keychain에 accessToken이 없음
    case noAccessToken
    /// Keychain에 refreshToken이 없음 → 재로그인 필요
    case noRefreshToken
    /// 서버가 refreshToken을 거부 (401/403) → 재로그인 필요
    case refreshTokenExpired
    /// 서버 오류 (5xx 등) → 일시적 실패, 재시도 가능
    case serverError(statusCode: Int)
    /// 네트워크 연결 실패 → 일시적 실패, 재시도 가능
    case networkError
    /// 서버 응답을 파싱할 수 없음
    case invalidResponse
    /// 응답 JSON 디코딩 실패
    case decodingFailed

    /// 재인증(로그인)이 필요한 에러인지 여부
    /// - true: 토큰이 무효화되어 사용자가 다시 로그인해야 함
    /// - false: 일시적 실패이므로 재시도 가능
    var requiresReAuthentication: Bool {
        switch self {
        case .noAccessToken, .noRefreshToken, .refreshTokenExpired:
            true
        case .serverError, .networkError, .invalidResponse, .decodingFailed:
            false
        }
    }

    var errorDescription: String? {
        switch self {
        case .noAccessToken:
            "인증 토큰이 없습니다"
        case .noRefreshToken:
            "갱신 토큰이 없습니다. 다시 로그인해주세요"
        case .refreshTokenExpired:
            "세션이 만료되었습니다. 다시 로그인해주세요"
        case .serverError(let code):
            "서버 오류가 발생했습니다 (\(code))"
        case .networkError:
            "네트워크 연결을 확인해주세요"
        case .invalidResponse:
            "서버 응답을 처리할 수 없습니다"
        case .decodingFailed:
            "서버 응답 형식이 올바르지 않습니다"
        }
    }
}
