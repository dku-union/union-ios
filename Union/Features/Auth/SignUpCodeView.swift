import SwiftUI
import ComposableArchitecture

// MARK: - Sign Up Step 3: Verification Code

struct SignUpCodeView: View {
    @Bindable var store: StoreOf<SignUpCodeFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            UNStepIndicator(currentStep: 3, totalSteps: 3)
                .padding(.horizontal, UNSpacing.xl)
                .padding(.top, UNSpacing.md)

            Spacer()

            VStack(spacing: UNSpacing.xxxl) {
                // Header
                VStack(spacing: UNSpacing.md) {
                    Text("인증번호 입력")
                        .font(UNFont.displaySmall())
                        .foregroundStyle(UNColor.textPrimary)

                    VStack(spacing: UNSpacing.xs) {
                        Text(store.email)
                            .font(UNFont.bodyMedium(.semibold))
                            .foregroundStyle(UNColor.interactive)
                        Text("으로 전송된 6자리 코드를 입력해주세요")
                            .font(UNFont.bodySmall())
                            .foregroundStyle(UNColor.textSecondary)
                    }

                    // 만료 타이머
                    Text(formattedTime(store.expirationSeconds))
                        .font(UNFont.headingMedium(.bold))
                        .foregroundStyle(store.expirationSeconds <= 60 ? UNColor.error : UNColor.interactive)
                        .monospacedDigit()
                }

                // Code input
                UNCodeField(
                    code: Binding(
                        get: { store.code },
                        set: { store.send(.codeChanged($0)) }
                    ),
                    length: 6,
                    error: store.codeError
                )
                .padding(.horizontal, UNSpacing.xl)

                // Loading
                if store.isLoading {
                    ProgressView()
                        .tint(UNColor.interactive)
                }

                // Resend
                VStack(spacing: UNSpacing.sm) {
                    Text("메일이 오지 않나요?")
                        .font(UNFont.captionLarge())
                        .foregroundStyle(UNColor.textTertiary)

                    if store.resendCooldown > 0 {
                        Text("\(store.resendCooldown)초 후 재전송 가능")
                            .font(UNFont.captionLarge(.semibold))
                            .foregroundStyle(UNColor.textTertiary)
                    } else {
                        Button("인증번호 재전송") {
                            store.send(.resendTapped)
                        }
                        .font(UNFont.bodySmall(.semibold))
                        .foregroundStyle(UNColor.interactive)
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .background(UNColor.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .task { store.send(.onAppear) }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
