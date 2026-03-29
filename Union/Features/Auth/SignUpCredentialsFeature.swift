import Foundation
import ComposableArchitecture

// MARK: - Sign Up Step 1: Credentials

@Reducer
struct SignUpCredentialsFeature {

    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var passwordConfirm = ""
        var emailError: String?
        var passwordError: String?
        var passwordConfirmError: String?
        var isLoading = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case nextTapped
        case schoolVerified(email: String, schoolName: String)
        case verificationFailed(String)
    }

    @Dependency(\.authClient) var authClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.email):
                state.emailError = nil
                return .none

            case .binding(\.password):
                state.passwordError = nil
                return .none

            case .binding(\.passwordConfirm):
                state.passwordConfirmError = nil
                return .none

            case .binding:
                return .none

            case .nextTapped:
                var hasError = false

                // Email validation
                if state.email.isEmpty {
                    state.emailError = "학교 이메일을 입력해주세요"
                    hasError = true
                } else if !state.email.contains("@") || (!state.email.contains(".ac.kr") && !state.email.hasSuffix(".edu")) {
                    state.emailError = "학교 이메일 형식이 아닙니다 (예: name@dankook.ac.kr)"
                    hasError = true
                }

                // Password validation
                if state.password.count < 8 {
                    state.passwordError = "비밀번호는 8자 이상이어야 합니다"
                    hasError = true
                }

                // Confirm validation
                if state.password != state.passwordConfirm {
                    state.passwordConfirmError = "비밀번호가 일치하지 않습니다"
                    hasError = true
                }

                guard !hasError else { return .none }

                state.isLoading = true
                return .run { [email = state.email] send in
                    let response = try await authClient.sendEmailCode(email)
                    await send(.schoolVerified(email: email, schoolName: response.universityName))
                } catch: { error, send in
                    let message = (error as? AuthError)?.errorDescription ?? "학교 인증에 실패했습니다"
                    await send(.verificationFailed(message))
                }

            case .schoolVerified:
                state.isLoading = false
                return .none

            case .verificationFailed(let message):
                state.isLoading = false
                state.emailError = message
                return .none
            }
        }
    }
}
