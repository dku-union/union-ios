import Foundation
import ComposableArchitecture

// MARK: - Publisher Login: Email Step

/// 퍼블리셔 로그인 1/2 단계 — 이메일 입력 후 OTP 발송.
///
/// 세 진입점:
/// 1. 메인 로그인 화면의 "미니앱 개발자이신가요?" 진입
/// 2. 앱 스킴(QR) `union-app://<appId>?versionId=...` 진입 (`testContext` 로 컨텍스트 전달)
@Reducer
struct PublisherLoginEmailFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        /// QR 스킴으로 진입했을 때의 컨텍스트 — UI에 "어떤 앱을 테스트하기 위한 인증인지" 명시
        var testContext: PublisherTestContext?
        var email: String = ""
        var emailError: String?
        var isLoading: Bool = false

        /// 미등록 계정 안내 alert
        @Presents var alert: AlertState<Action.Alert>?
    }

    // MARK: - Action

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case sendCodeTapped
        case codeSent(maskedEmail: String, expiresInSeconds: Int)
        case sendFailed(PublisherAuthError)
        case alert(PresentationAction<Alert>)

        enum Alert: Equatable {
            case openWebsiteSignup
            case dismissed
        }
    }

    // MARK: - Dependencies

    @Dependency(\.publisherAuthClient) var publisherAuthClient
    @Dependency(\.openURL) var openURL

    // MARK: - Body

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.email):
                state.emailError = nil
                return .none

            case .binding:
                return .none

            case .sendCodeTapped:
                let email = state.email.trimmingCharacters(in: .whitespaces).lowercased()
                guard isValidEmail(email) else {
                    state.emailError = "올바른 이메일 형식이 아닙니다"
                    return .none
                }
                state.email = email
                state.isLoading = true
                state.emailError = nil

                return .run { send in
                    do {
                        let response = try await publisherAuthClient.sendCode(email: email)
                        await send(.codeSent(
                            maskedEmail: response.maskedEmail,
                            expiresInSeconds: response.expiresInSeconds
                        ))
                    } catch let error as PublisherAuthError {
                        await send(.sendFailed(error))
                    } catch {
                        await send(.sendFailed(.networkError))
                    }
                }

            case .codeSent:
                state.isLoading = false
                return .none

            case .sendFailed(.notRegistered):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("등록되지 않은 계정")
                } actions: {
                    ButtonState(role: .cancel, action: .dismissed) {
                        TextState("닫기")
                    }
                    ButtonState(action: .openWebsiteSignup) {
                        TextState("웹에서 회원가입")
                    }
                } message: {
                    TextState("유니온 웹사이트에서 먼저 회원가입을 진행해주세요.")
                }
                return .none

            case .sendFailed(let error):
                state.isLoading = false
                state.emailError = error.errorDescription
                return .none

            case .alert(.presented(.openWebsiteSignup)):
                return .run { _ in
                    if let url = URL(string: "https://union.app/signup") {
                        await openURL(url)
                    }
                }

            case .alert:
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

// MARK: - Test Context

/// QR(앱 스킴)로 진입했을 때의 테스트 세션 컨텍스트.
///
/// 백엔드는 `union-app://test-app?token=<uuid>` 형태의 1회용 토큰 링크를 발급한다.
/// `test-app`은 미니앱 ID가 아닌 고정 sentinel이며, 어떤 버전을 가리키는지는
/// 토큰 redeem(`GET /app-versions/test-bundle?token=...`)으로만 알 수 있다.
struct PublisherTestContext: Equatable, Sendable {
    /// `?token=...` — 정상 경로(권장).
    let token: String?
    /// `?versionId=...` — 구버전 dashboard가 발급한 영구 링크. backend에서 제거됐으나
    /// 이미 외부에 공유된 QR이 있을 수 있으므로 호환을 위해 기록만 한다(redeem 불가).
    let legacyVersionId: String?

    /// UI 표시용 식별자(없으면 nil 처리). 토큰은 8자리만 노출.
    var displayIdentifier: String? {
        if let token { return String(token.prefix(8)) }
        if let legacyVersionId { return String(legacyVersionId.prefix(8)) }
        return nil
    }

    /// 컨텍스트가 유효한 redeem 대상이 있는지.
    var isRedeemable: Bool { token != nil }
}
