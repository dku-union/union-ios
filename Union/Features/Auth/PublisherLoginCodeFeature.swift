import Foundation
import ComposableArchitecture

// MARK: - Publisher Login: OTP Step

/// 퍼블리셔 로그인 2/2 단계 — 이메일로 받은 6자리 OTP 검증 후 토큰 발급.
@Reducer
struct PublisherLoginCodeFeature {

    private enum CancelID { case timer }

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        let email: String
        let maskedEmail: String
        let testContext: PublisherTestContext?

        var code: String = ""
        var codeError: String?
        var expirationSeconds: Int
        var resendCooldown: Int = 30
        var isLoading: Bool = false

        init(
            email: String,
            maskedEmail: String,
            expiresInSeconds: Int,
            testContext: PublisherTestContext? = nil
        ) {
            self.email = email
            self.maskedEmail = maskedEmail
            self.expirationSeconds = expiresInSeconds
            self.testContext = testContext
        }
    }

    // MARK: - Action

    enum Action {
        case onAppear
        case codeChanged(String)
        case verifyTapped
        case loginSucceeded(PublisherTokenResponse)
        case verifyFailed(PublisherAuthError)
        case resendTapped
        case resent(maskedEmail: String, expiresInSeconds: Int)
        case resendFailed(PublisherAuthError)
        case timerTicked
    }

    // MARK: - Dependencies

    @Dependency(\.publisherAuthClient) var publisherAuthClient
    @Dependency(\.continuousClock) var clock

    // MARK: - Body

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.timerTicked)
                    }
                }
                .cancellable(id: CancelID.timer, cancelInFlight: true)

            case .timerTicked:
                if state.expirationSeconds > 0 { state.expirationSeconds -= 1 }
                if state.resendCooldown > 0 { state.resendCooldown -= 1 }
                return .none

            case .codeChanged(let new):
                let digits = String(new.prefix(6).filter(\.isNumber))
                state.code = digits
                state.codeError = nil

                if digits.count == 6 && !state.isLoading {
                    return .send(.verifyTapped)
                }
                return .none

            case .verifyTapped:
                guard state.code.count == 6 else { return .none }
                guard state.expirationSeconds > 0 else {
                    state.codeError = "인증번호가 만료되었습니다. 재전송해주세요."
                    return .none
                }
                state.isLoading = true
                let email = state.email
                let code = state.code

                return .run { send in
                    do {
                        let response = try await publisherAuthClient.verifyCode(email: email, code: code)
                        await send(.loginSucceeded(response))
                    } catch let error as PublisherAuthError {
                        await send(.verifyFailed(error))
                    } catch {
                        await send(.verifyFailed(.networkError))
                    }
                }

            case .loginSucceeded:
                state.isLoading = false
                return .cancel(id: CancelID.timer)

            case .verifyFailed(let error):
                state.isLoading = false
                state.code = ""
                state.codeError = error.errorDescription
                return .none

            case .resendTapped:
                guard state.resendCooldown == 0 else { return .none }
                state.resendCooldown = 30
                state.codeError = nil
                let email = state.email

                return .run { send in
                    do {
                        let response = try await publisherAuthClient.sendCode(email: email)
                        await send(.resent(
                            maskedEmail: response.maskedEmail,
                            expiresInSeconds: response.expiresInSeconds
                        ))
                    } catch let error as PublisherAuthError {
                        await send(.resendFailed(error))
                    } catch {
                        await send(.resendFailed(.networkError))
                    }
                }

            case .resent(_, let expiresInSeconds):
                state.expirationSeconds = expiresInSeconds
                state.code = ""
                return .none

            case .resendFailed(let error):
                state.codeError = error.errorDescription
                state.resendCooldown = 0
                return .none
            }
        }
    }
}
