import Foundation
import ComposableArchitecture

// MARK: - Auth Feature

@Reducer
struct AuthFeature {

    // MARK: - State

    @ObservableState
    struct State {
        var path = StackState<Path.State>()
    }

    // MARK: - Navigation Path

    @Reducer
    enum Path {
        case login(LoginFeature)
        case signUpCredentials(SignUpCredentialsFeature)
        case signUpVerify(SignUpVerifyFeature)
        case signUpCode(SignUpCodeFeature)
    }

    // MARK: - Action

    enum Action {
        case path(StackActionOf<Path>)
        case loginTapped
        case signUpTapped
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .loginTapped:
                state.path.append(.login(LoginFeature.State()))
                return .none

            case .signUpTapped:
                state.path.append(.signUpCredentials(SignUpCredentialsFeature.State()))
                return .none

            case .path(.element(let id, action: .signUpCredentials(.schoolVerified(let email, let school)))):
                guard case .signUpCredentials(let credState) = state.path[id: id] else {
                    return .none
                }
                state.path.append(.signUpVerify(SignUpVerifyFeature.State(
                    email: email,
                    password: credState.password,
                    schoolName: school
                )))
                return .none

            case .path(.element(let id, action: .signUpVerify(.codeSent))):
                guard case .signUpVerify(let verifyState) = state.path[id: id] else {
                    return .none
                }
                state.path.append(.signUpCode(SignUpCodeFeature.State(
                    email: verifyState.email,
                    password: verifyState.password,
                    schoolName: verifyState.schoolName
                )))
                return .none

            case .path(.element(_, action: .signUpCode(.signUpCompleted))):
                state.path.removeAll()
                return .none

            case .path(.element(_, action: .login(.loginSucceeded))):
                state.path.removeAll()
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
