import SwiftUI
import ComposableArchitecture

// MARK: - Sign Up Step 1: Credentials View

struct SignUpCredentialsView: View {
    @Bindable var store: StoreOf<SignUpCredentialsFeature>
    @FocusState private var focusedField: Field?

    enum Field { case email, password, confirm }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            UNStepIndicator(currentStep: 1, totalSteps: 3)
                .padding(.horizontal, UNSpacing.xl)
                .padding(.top, UNSpacing.md)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: UNSpacing.xxxl) {
                    // Header
                    VStack(alignment: .leading, spacing: UNSpacing.sm) {
                        Text("학교 이메일로\n시작해볼까요?")
                            .font(UNFont.displaySmall())
                            .foregroundStyle(UNColor.textPrimary)

                        Text("학교 인증을 위해 학교 이메일이 필요해요")
                            .font(UNFont.bodyMedium())
                            .foregroundStyle(UNColor.textSecondary)
                    }
                    .padding(.top, UNSpacing.xl)

                    // Form
                    VStack(spacing: UNSpacing.xl) {
                        UNFormField(
                            label: "학교 이메일",
                            placeholder: "name@dankook.ac.kr",
                            text: $store.email,
                            icon: "envelope",
                            error: store.emailError,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress
                        )
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }

                        UNSecureFormField(
                            label: "비밀번호",
                            placeholder: "8자 이상 입력",
                            text: $store.password,
                            error: store.passwordError
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit { focusedField = .confirm }

                        UNSecureFormField(
                            label: "비밀번호 확인",
                            placeholder: "비밀번호를 다시 입력",
                            text: $store.passwordConfirm,
                            error: store.passwordConfirmError
                        )
                        .focused($focusedField, equals: .confirm)
                        .onSubmit {
                            focusedField = nil
                            store.send(.nextTapped)
                        }

                        // Password requirements
                        passwordRequirements
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }

            // Next button
            VStack(spacing: 0) {
                UNDivider()
                Button {
                    focusedField = nil
                    store.send(.nextTapped)
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("다음")
                    }
                }
                .unPrimaryButton(.large, fullWidth: true)
                .disabled(store.isLoading)
                .padding(.horizontal, UNSpacing.xl)
                .padding(.vertical, UNSpacing.lg)
            }
            .background(UNColor.bgPrimary)
        }
        .background(UNColor.bgPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focusedField = .email }
    }

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: UNSpacing.sm) {
            requirementRow("8자 이상", met: store.password.count >= 8)
            requirementRow("비밀번호 일치", met: !store.passwordConfirm.isEmpty && store.password == store.passwordConfirm)
        }
    }

    private func requirementRow(_ text: String, met: Bool) -> some View {
        HStack(spacing: UNSpacing.sm) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(UNFont.captionLarge())
                .foregroundStyle(met ? UNColor.mint : UNColor.textTertiary)
            Text(text)
                .font(UNFont.captionLarge())
                .foregroundStyle(met ? UNColor.mint : UNColor.textTertiary)
        }
        .animation(.easeInOut(duration: 0.2), value: met)
    }
}
