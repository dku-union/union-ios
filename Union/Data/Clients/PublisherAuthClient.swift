import Foundation
import ComposableArchitecture

// MARK: - Publisher Auth Client (TCA Dependency)

/// 퍼블리셔 패스워드리스 로그인용 의존성.
///
/// 백엔드 endpoints:
/// - `POST /api/v1/auth/publisher/email/send`
/// - `POST /api/v1/auth/publisher/email/verify`
///
/// 토큰 저장은 `KeychainStore`를 직접 사용한다(=User 흐름과 동일한 keychain 슬롯 공유).
/// 이유: iOS 디바이스에는 한 번에 하나의 세션만 존재하고, 라우팅은 JWT의 `role` claim
/// 으로 분기하므로 별도 슬롯을 둘 필요가 없다.
@DependencyClient
struct PublisherAuthClient: Sendable {
    var sendCode: @Sendable (_ email: String) async throws -> PublisherSendCodeResponse
    var verifyCode: @Sendable (_ email: String, _ code: String) async throws -> PublisherTokenResponse
}

// MARK: - Response DTOs

struct PublisherSendCodeResponse: Codable, Sendable, Equatable {
    let expiresInSeconds: Int
    let maskedEmail: String
}

struct PublisherTokenResponse: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let publisherId: UUID
    let name: String
    let role: String
}

// MARK: - Errors

enum PublisherAuthError: LocalizedError, Equatable {
    /// 등록되지 않은 이메일 — UI는 가입 안내 alert을 띄운다
    case notRegistered(String)
    case inactive(String)
    case invalidCode(String)
    case networkError
    case httpError(Int, String?)

    var errorDescription: String? {
        switch self {
        case .notRegistered(let m), .inactive(let m), .invalidCode(let m): m
        case .networkError: "네트워크 연결을 확인해주세요"
        case .httpError(let code, let m): m ?? "서버 오류가 발생했습니다 (\(code))"
        }
    }
}

// MARK: - Live

extension PublisherAuthClient: DependencyKey {
    static let liveValue: PublisherAuthClient = {
        let baseURL = APIConfig.baseURL.appendingPathComponent("/api/v1/auth/publisher")
        let session = URLSession.shared
        let decoder = JSONDecoder()

        @Sendable func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
            let url = baseURL.appendingPathComponent(path)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 15
            request.httpBody = try JSONEncoder().encode(body)

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                throw PublisherAuthError.networkError
            }

            guard let http = response as? HTTPURLResponse else {
                throw PublisherAuthError.networkError
            }

            if (200...299).contains(http.statusCode) {
                return try decoder.decode(T.self, from: data)
            }

            // 백엔드 ErrorResponse: { status, error, code, message, timestamp }
            let server = try? JSONDecoder().decode(ServerErrorBody.self, from: data)
            switch server?.code {
            case "PUBLISHER_NOT_REGISTERED":
                throw PublisherAuthError.notRegistered(server?.message ?? "등록되지 않은 계정입니다.")
            case "PUBLISHER_INACTIVE":
                throw PublisherAuthError.inactive(server?.message ?? "활성 상태가 아닌 계정입니다.")
            case "BAD_REQUEST", "VALIDATION_ERROR":
                throw PublisherAuthError.invalidCode(server?.message ?? "인증번호가 올바르지 않습니다.")
            default:
                throw PublisherAuthError.httpError(http.statusCode, server?.message)
            }
        }

        return PublisherAuthClient(
            sendCode: { email in
                let body = SendBody(email: email)
                let response: PublisherSendCodeResponse = try await post("/email/send", body: body)
                return response
            },
            verifyCode: { email, code in
                let body = VerifyBody(email: email, code: code)
                let response: PublisherTokenResponse = try await post("/email/verify", body: body)

                KeychainStore.save(response.accessToken, for: .accessToken)
                KeychainStore.save(response.refreshToken, for: .refreshToken)

                return response
            }
        )
    }()
}

// MARK: - Preview / Test

extension PublisherAuthClient: TestDependencyKey {
    static let testValue = PublisherAuthClient()

    static let previewValue = PublisherAuthClient(
        sendCode: { _ in PublisherSendCodeResponse(expiresInSeconds: 300, maskedEmail: "ju****@dankook.ac.kr") },
        verifyCode: { _, _ in
            PublisherTokenResponse(
                accessToken: "preview_pub_access",
                refreshToken: "preview_pub_refresh",
                publisherId: UUID(uuidString: "66d1bf78-29b5-45d8-bba7-f08f88bffa23")!,
                name: "Union Dev",
                role: "ROLE_PUBLISHER"
            )
        }
    )
}

extension DependencyValues {
    var publisherAuthClient: PublisherAuthClient {
        get { self[PublisherAuthClient.self] }
        set { self[PublisherAuthClient.self] = newValue }
    }
}

// MARK: - Internal DTOs

private struct SendBody: Encodable { let email: String }
private struct VerifyBody: Encodable { let email: String; let code: String }
private struct ServerErrorBody: Decodable {
    let code: String?
    let message: String?
}
