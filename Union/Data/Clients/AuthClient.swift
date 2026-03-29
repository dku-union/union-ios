import Foundation
import ComposableArchitecture

// MARK: - Auth Client (TCA Dependency)

@DependencyClient
struct AuthClient: Sendable {
    var login: @Sendable (_ email: String, _ password: String) async throws -> TokenResponse
    var signUp: @Sendable (_ email: String, _ password: String, _ nickname: String) async throws -> TokenResponse
    var refresh: @Sendable (_ refreshToken: String) async throws -> TokenResponse
    var logout: @Sendable () async throws -> Void
    var sendEmailCode: @Sendable (_ email: String) async throws -> EmailSendResponse
    var verifyEmailCode: @Sendable (_ email: String, _ code: String) async throws -> Void
}

// MARK: - Response DTOs

struct TokenResponse: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
}

struct EmailSendResponse: Codable, Sendable, Equatable {
    let universityName: String
}

// MARK: - Live

extension AuthClient: DependencyKey {
    static let liveValue: AuthClient = {
        let baseURL = APIConfig.authURL
        let session = URLSession.shared
        let decoder = JSONDecoder()

        @Sendable func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
            let url = baseURL.appendingPathComponent(path)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AuthError.networkError
            }

            guard (200...299).contains(http.statusCode) else {
                if let errorBody = try? JSONDecoder().decode(ServerError.self, from: data) {
                    throw AuthError.serverError(errorBody.message)
                }
                throw AuthError.httpError(http.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        }

        let emailBaseURL = APIConfig.emailURL

        @Sendable func postEmail<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
            let url = emailBaseURL.appendingPathComponent(path)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AuthError.networkError
            }

            guard (200...299).contains(http.statusCode) else {
                if let errorBody = try? JSONDecoder().decode(ServerError.self, from: data) {
                    throw AuthError.serverError(errorBody.message)
                }
                throw AuthError.httpError(http.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        }

        @Sendable func postVoid(_ url: URL, path: String, body: some Encodable) async throws {
            let requestURL = url.appendingPathComponent(path)
            var request = URLRequest(url: requestURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw AuthError.networkError
            }

            guard (200...299).contains(http.statusCode) else {
                if let errorBody = try? JSONDecoder().decode(ServerError.self, from: data) {
                    throw AuthError.serverError(errorBody.message)
                }
                throw AuthError.httpError(http.statusCode)
            }
        }

        return AuthClient(
            login: { email, password in
                let body = LoginRequest(email: email, password: password)
                let response: TokenResponse = try await post("/login", body: body)

                KeychainStore.save(response.accessToken, for: .accessToken)
                KeychainStore.save(response.refreshToken, for: .refreshToken)

                return response
            },
            signUp: { email, password, nickname in
                let body = SignUpRequest(
                    email: email, password: password, nickname: nickname
                )
                let response: TokenResponse = try await post("/signup", body: body)

                KeychainStore.save(response.accessToken, for: .accessToken)
                KeychainStore.save(response.refreshToken, for: .refreshToken)

                return response
            },
            refresh: { refreshToken in
                let body = RefreshRequest(refreshToken: refreshToken)
                let response: TokenResponse = try await post("/refresh", body: body)

                KeychainStore.save(response.accessToken, for: .accessToken)
                KeychainStore.save(response.refreshToken, for: .refreshToken)

                return response
            },
            logout: {
                KeychainStore.clearAll()
            },
            sendEmailCode: { email in
                let body = EmailSendRequest(email: email)
                let response: EmailSendResponse = try await postEmail("/send", body: body)
                return response
            },
            verifyEmailCode: { email, code in
                let body = EmailVerifyRequest(email: email, code: code)
                try await postVoid(emailBaseURL, path: "/verify", body: body)
            }
        )
    }()
}

// MARK: - Test / Preview

extension AuthClient: TestDependencyKey {
    static let testValue = AuthClient()

    static let previewValue = AuthClient(
        login: { _, _ in TokenResponse(accessToken: "preview_access", refreshToken: "preview_refresh") },
        signUp: { _, _, _ in TokenResponse(accessToken: "preview_access", refreshToken: "preview_refresh") },
        refresh: { _ in TokenResponse(accessToken: "preview_access", refreshToken: "preview_refresh") },
        logout: {},
        sendEmailCode: { _ in EmailSendResponse(universityName: "단국대학교") },
        verifyEmailCode: { _, _ in }
    )
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

// MARK: - Request DTOs

private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

private struct SignUpRequest: Encodable {
    let email: String
    let password: String
    let nickname: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

private struct ServerError: Decodable {
    let message: String
}

private struct EmailSendRequest: Encodable {
    let email: String
}

private struct EmailVerifyRequest: Encodable {
    let email: String
    let code: String
}

// MARK: - Auth Error

enum AuthError: LocalizedError, Equatable {
    case networkError
    case httpError(Int)
    case serverError(String)
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .networkError: "네트워크 연결을 확인해주세요"
        case .httpError(let code): "서버 오류가 발생했습니다 (\(code))"
        case .serverError(let msg): msg
        case .sessionExpired: "세션이 만료되었습니다. 다시 로그인해주세요"
        }
    }
}
