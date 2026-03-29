import SwiftUI
import ComposableArchitecture

// MARK: - Welcome View (Auth Entry)

struct WelcomeView: View {
    @Bindable var store: StoreOf<AuthFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            VStack(spacing: 0) {
                Spacer()

                // Logo & Branding
                VStack(spacing: UNSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: UNColor.gradientBluePurple,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 88, height: 88)
                            .unShadow(.elevated)

                        Text("U")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: UNSpacing.sm) {
                        Text("Union")
                            .font(UNFont.displayLarge(.black))
                            .foregroundStyle(UNColor.textPrimary)

                        Text("대학생을 위한 미니앱 플랫폼")
                            .font(UNFont.bodyMedium())
                            .foregroundStyle(UNColor.textSecondary)
                    }
                }

                Spacer()

                // Features highlight
                VStack(spacing: UNSpacing.lg) {
                    featureRow(icon: "sparkles", text: "학교 인증 기반 안전한 커뮤니티")
                    featureRow(icon: "square.grid.2x2", text: "다양한 미니앱을 하나의 앱에서")
                    featureRow(icon: "bolt.fill", text: "설치 없이 바로 실행")
                }
                .padding(.horizontal, UNSpacing.xxxxl)

                Spacer()

                // CTA Buttons
                VStack(spacing: UNSpacing.md) {
                    Button("시작하기") {
                        store.send(.signUpTapped)
                    }
                    .unPrimaryButton(.large, fullWidth: true)

                    Button {
                        store.send(.loginTapped)
                    } label: {
                        HStack(spacing: UNSpacing.xs) {
                            Text("이미 계정이 있으신가요?")
                                .foregroundStyle(UNColor.textTertiary)
                            Text("로그인")
                                .foregroundStyle(UNColor.brand)
                                .fontWeight(.semibold)
                        }
                        .font(UNFont.bodyMedium())
                    }
                    .frame(height: 44)
                }
                .padding(.horizontal, UNSpacing.xl)
                .padding(.bottom, UNSpacing.xxxl)
            }
            .background(UNColor.bgPrimary)
        } destination: { store in
            switch store.case {
            case .login(let loginStore):
                LoginView(store: loginStore)
            case .signUpCredentials(let credStore):
                SignUpCredentialsView(store: credStore)
            case .signUpVerify(let verifyStore):
                SignUpVerifyView(store: verifyStore)
            case .signUpCode(let codeStore):
                SignUpCodeView(store: codeStore)
            }
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: UNSpacing.md) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(UNColor.brand)
                .frame(width: 32, height: 32)
                .background(UNColor.brandLight)
                .clipShape(RoundedRectangle(cornerRadius: UNRadius.sm, style: .continuous))

            Text(text)
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textSecondary)

            Spacer()
        }
    }
}

#Preview {
    WelcomeView(store: Store(initialState: AuthFeature.State()) { AuthFeature() })
}
