import Foundation
import ComposableArchitecture

// MARK: - Sign Up Step 3: Verification Code

@Reducer
struct SignUpCodeFeature {

    @ObservableState
    struct State: Equatable {
        let email: String
        let password: String
        let schoolName: String
        var nickname = ""
        var code = ""
        var codeError: String?
        var isLoading = false
        var resendCooldown: Int = 0
        var expirationSeconds: Int = 300  // 5분
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case codeChanged(String)
        case verifyCode
        case verificationSucceeded
        case signUpCompleted
        case verificationFailed(String)
        case signUpFailed(String)
        case resendTapped
        case resendSucceeded
        case resendFailed(String)
        case timerTicked
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case timer }

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                state.expirationSeconds = 300
                return startTimer()

            case .codeChanged(let code):
                state.code = code
                state.codeError = nil
                if code.count == 6 {
                    return .send(.verifyCode)
                }
                return .none

            case .verifyCode:
                state.isLoading = true
                return .run { [email = state.email, code = state.code] send in
                    try await authClient.verifyEmailCode(email, code)
                    await send(.verificationSucceeded)
                } catch: { error, send in
                    let message = (error as? AuthError)?.errorDescription ?? "인증번호가 올바르지 않습니다"
                    await send(.verificationFailed(message))
                }

            case .verificationSucceeded:
                // 이메일 인증 성공 → signUp API 호출하여 토큰 발급
                return .run { [email = state.email, password = state.password, nickname = state.nickname] send in
                    let finalNickname = nickname.isEmpty ? String(email.split(separator: "@").first ?? "유저") : nickname
                    _ = try await authClient.signUp(email, password, finalNickname)
                    await send(.signUpCompleted)
                } catch: { error, send in
                    let message = (error as? AuthError)?.errorDescription ?? "회원가입에 실패했습니다"
                    await send(.signUpFailed(message))
                }

            case .signUpCompleted:
                state.isLoading = false
                return .cancel(id: CancelID.timer)

            case .verificationFailed(let message):
                state.isLoading = false
                state.codeError = message
                state.code = ""
                return .none

            case .signUpFailed(let message):
                state.isLoading = false
                state.codeError = message
                return .none

            case .resendTapped:
                state.resendCooldown = 60
                state.codeError = nil
                state.code = ""
                return .run { [email = state.email] send in
                    _ = try await authClient.sendEmailCode(email)
                    await send(.resendSucceeded)
                } catch: { error, send in
                    let message = (error as? AuthError)?.errorDescription ?? "재전송에 실패했습니다"
                    await send(.resendFailed(message))
                }

            case .resendSucceeded:
                state.expirationSeconds = 300
                return .none

            case .resendFailed(let message):
                state.codeError = message
                state.resendCooldown = 0
                return .none

            case .timerTicked:
                if state.resendCooldown > 0 {
                    state.resendCooldown -= 1
                }
                if state.expirationSeconds > 0 {
                    state.expirationSeconds -= 1
                }
                if state.expirationSeconds == 0 {
                    state.codeError = "인증 시간이 만료되었습니다. 재전송해주세요."
                    state.code = ""
                    return .cancel(id: CancelID.timer)
                }
                return .none
            }
        }
    }

    private func startTimer() -> Effect<Action> {
        .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.timerTicked)
            }
        }
        .cancellable(id: CancelID.timer, cancelInFlight: true)
    }
}
