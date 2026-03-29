import Foundation
import ComposableArchitecture

// MARK: - Sign Up Step 2: School Verification Confirm

@Reducer
struct SignUpVerifyFeature {

    @ObservableState
    struct State: Equatable {
        let email: String
        let password: String
        let schoolName: String
        var isLoading = false
        var error: String?
    }

    enum Action {
        case sendCodeTapped
        case codeSent
        case sendFailed(String)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .sendCodeTapped:
                state.isLoading = true
                state.error = nil
                // Step 1에서 이미 인증코드가 발송되었으므로, 바로 다음 단계로 이동
                return .run { send in
                    await send(.codeSent)
                }

            case .codeSent:
                state.isLoading = false
                return .none

            case .sendFailed(let message):
                state.isLoading = false
                state.error = message
                return .none
            }
        }
    }
}
