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
        case publisherLoginEmail(PublisherLoginEmailFeature)
        case publisherLoginCode(PublisherLoginCodeFeature)
    }

    // MARK: - Action

    enum Action {
        case path(StackActionOf<Path>)
        case loginTapped
        case signUpTapped
        /// 메인 로그인 화면의 "미니앱 개발자이신가요?" 버튼
        case publisherLoginTapped
        /// QR(앱 스킴) 진입 — 외부에서 컨텍스트와 함께 호출
        case publisherLoginRequested(PublisherTestContext)
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

            case .publisherLoginTapped:
                state.path.append(
                    .publisherLoginEmail(PublisherLoginEmailFeature.State())
                )
                return .none

            case .publisherLoginRequested(let context):
                // 이미 publisher 로그인 단계라면 컨텍스트만 갱신, 아니면 새로 push
                state.path.removeAll()
                state.path.append(
                    .publisherLoginEmail(PublisherLoginEmailFeature.State(testContext: context))
                )
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

            // Publisher: 1단계에서 코드 발송 성공 → 2단계 OTP 화면 push
            case .path(.element(let id, action: .publisherLoginEmail(.codeSent(let masked, let expiresInSeconds)))):
                guard case .publisherLoginEmail(let emailState) = state.path[id: id] else {
                    return .none
                }
                state.path.append(
                    .publisherLoginCode(
                        PublisherLoginCodeFeature.State(
                            email: emailState.email,
                            maskedEmail: masked,
                            expiresInSeconds: expiresInSeconds,
                            testContext: emailState.testContext
                        )
                    )
                )
                return .none

            // Publisher: 2단계에서 검증 성공 → AppFeature가 isLoggedIn 처리. 여기서는 stack 정리.
            case .path(.element(_, action: .publisherLoginCode(.loginSucceeded))):
                state.path.removeAll()
                return .none

            case .path:
                return .none
            }
        }
        .forEach(\.path, action: \.path)
    }
}
