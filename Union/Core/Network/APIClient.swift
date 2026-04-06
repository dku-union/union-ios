import Foundation

// MARK: - API Client

/// 인증이 필요한 API 요청을 처리하는 HTTP 클라이언트
///
/// 토큰 관리 전략:
/// 1. **Proactive 갱신** — 요청 전 TokenProvider를 통해 만료 임박 토큰 사전 갱신
/// 2. **401 자동 재시도** — 서버가 401을 반환하면 토큰 갱신 후 1회 재시도
/// 3. **세션 만료 전파** — 갱신 자체가 실패하면 `APIError.sessionExpired` throw
actor APIClient {
    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let tokenProvider: TokenProvider

    init(
        baseURL: URL = APIConfig.apiV1URL,
        session: URLSession = .shared,
        tokenProvider: TokenProvider = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Authenticated Request

    /// 인증이 필요한 API 요청 (토큰 자동 주입 + 401 재시도)
    ///
    /// 흐름:
    /// ```
    /// validAccessToken() → 요청 → 200 OK → 반환
    ///                       → 401 → forceRefresh() → 재시도(1회) → 반환 or throw
    /// ```
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let accessToken = try await resolveAccessToken()

        do {
            return try await performRequest(endpoint, accessToken: accessToken)
        } catch APIError.httpError(statusCode: 401, _) {
            let retryRequest = try endpoint.urlRequest(baseURL: baseURL)
            NetworkLogger.logRetry(retryRequest, reason: "401 Unauthorized → token refresh")
            let refreshedToken = try await handleUnauthorized()
            return try await performRequest(endpoint, accessToken: refreshedToken)
        }
    }

    // MARK: - Unauthenticated Request

    /// 인증이 필요 없는 공개 API 요청
    func requestWithoutAuth<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try endpoint.urlRequest(baseURL: baseURL)
        return try await execute(urlRequest)
    }

    // MARK: - Private

    private func resolveAccessToken() async throws -> String {
        do {
            return try await tokenProvider.validAccessToken()
        } catch let error as TokenError where error.requiresReAuthentication {
            throw APIError.sessionExpired
        }
    }

    private func performRequest<T: Decodable>(
        _ endpoint: APIEndpoint,
        accessToken: String
    ) async throws -> T {
        var urlRequest = try endpoint.urlRequest(baseURL: baseURL)
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await execute(urlRequest)
    }

    /// URLRequest 실행 및 응답 처리 (로깅 포함)
    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        NetworkLogger.logRequest(request)
        let start = CFAbsoluteTimeGetCurrent()

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - start
            NetworkLogger.logError(request, error: error, duration: duration)
            throw error
        }

        let duration = CFAbsoluteTimeGetCurrent() - start

        guard let http = response as? HTTPURLResponse else {
            NetworkLogger.logError(request, error: APIError.invalidResponse, duration: duration)
            throw APIError.invalidResponse
        }

        NetworkLogger.logResponse(request, status: http.statusCode, data: data, duration: duration)

        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func handleUnauthorized() async throws -> String {
        do {
            return try await tokenProvider.forceRefresh()
        } catch let error as TokenError where error.requiresReAuthentication {
            throw APIError.sessionExpired
        }
    }
}
