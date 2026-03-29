import SwiftUI
import ComposableArchitecture

// MARK: - Login View

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: UNSpacing.xxxl) {
                    // Header
                    VStack(alignment: .leading, spacing: UNSpacing.sm) {
                        Text("다시 만나서 반가워요")
                            .font(UNFont.displaySmall())
                            .foregroundStyle(UNColor.textPrimary)

                        Text("이메일과 비밀번호로 로그인하세요")
                            .font(UNFont.bodyMedium())
                            .foregroundStyle(UNColor.textSecondary)
                    }
                    .padding(.top, UNSpacing.xl)

                    // Form
                    VStack(spacing: UNSpacing.xl) {
                        UNFormField(
                            label: "이메일",
                            placeholder: "학교 이메일 입력",
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
                            placeholder: "비밀번호 입력",
                            text: $store.password,
                            error: store.passwordError
                        )
                        .focused($focusedField, equals: .password)
                        .onSubmit { store.send(.loginTapped) }
                    }

                    // Forgot password
                    HStack {
                        Spacer()
                        Button("비밀번호를 잊으셨나요?") {
                            store.send(.forgotPasswordTapped)
                        }
                        .font(UNFont.bodySmall(.medium))
                        .foregroundStyle(UNColor.textTertiary)
                    }
                }
                .padding(.horizontal, UNSpacing.xl)
            }

            // Login button (pinned to bottom)
            VStack(spacing: 0) {
                UNDivider()
                Button {
                    focusedField = nil
                    store.send(.loginTapped)
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("로그인")
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
}
