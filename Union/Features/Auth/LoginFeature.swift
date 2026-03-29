import Foundation
import ComposableArchitecture

// MARK: - Login Feature

@Reducer
struct LoginFeature {

    @ObservableState
    struct State: Equatable {
        var email = ""
        var password = ""
        var emailError: String?
        var passwordError: String?
        var isLoading = false
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case loginTapped
        case loginSucceeded
        case loginFailed(String)
        case forgotPasswordTapped
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

            case .binding:
                return .none

            case .loginTapped:
                var hasError = false
                if state.email.isEmpty {
                    state.emailError = "이메일을 입력해주세요"
                    hasError = true
                }
                if state.password.isEmpty {
                    state.passwordError = "비밀번호를 입력해주세요"
                    hasError = true
                }
                guard !hasError else { return .none }

                state.isLoading = true
                return .run { [email = state.email, password = state.password] send in
                    _ = try await authClient.login(email, password)
                    await send(.loginSucceeded)
                } catch: { error, send in
                    let message = (error as? AuthError)?.errorDescription ?? "로그인에 실패했습니다"
                    await send(.loginFailed(message))
                }

            case .loginSucceeded:
                state.isLoading = false
                return .none

            case .loginFailed(let message):
                state.isLoading = false
                state.passwordError = message
                return .none

            case .forgotPasswordTapped:
                return .none
            }
        }
    }
}
