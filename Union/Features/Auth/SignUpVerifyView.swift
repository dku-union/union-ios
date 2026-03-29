import SwiftUI
import ComposableArchitecture

// MARK: - Sign Up Step 2: School Verification Confirm

struct SignUpVerifyView: View {
    let store: StoreOf<SignUpVerifyFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            UNStepIndicator(currentStep: 2, totalSteps: 3)
                .padding(.horizontal, UNSpacing.xl)
                .padding(.top, UNSpacing.md)

            Spacer()

            // Content
            VStack(spacing: UNSpacing.xxxl) {
                // School icon
                ZStack {
                    Circle()
                        .fill(UNColor.mintLight)
                        .frame(width: 80, height: 80)

                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(UNColor.mint)
                }

                // Info
                VStack(spacing: UNSpacing.md) {
                    Text("학교가 확인되었어요!")
                        .font(UNFont.displaySmall())
                        .foregroundStyle(UNColor.textPrimary)

                    Text(store.schoolName)
                        .font(UNFont.headingLarge())
                        .foregroundStyle(UNColor.brand)

                    Text(store.email)
                        .font(UNFont.bodyMedium())
                        .foregroundStyle(UNColor.textSecondary)
                }

                // Explanation card
                VStack(alignment: .leading, spacing: UNSpacing.md) {
                    HStack(spacing: UNSpacing.sm) {
                        Image(systemName: "envelope.badge")
                            .foregroundStyle(UNColor.brand)
                        Text("인증 메일을 보내드릴게요")
                            .font(UNFont.headingSmall())
                            .foregroundStyle(UNColor.textPrimary)
                    }

                    Text("학교 이메일로 6자리 인증번호를 보내드립니다.\n메일함을 확인해주세요.")
                        .font(UNFont.bodySmall())
                        .foregroundStyle(UNColor.textSecondary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(UNSpacing.xl)
                .background(UNColor.brandLight)
                .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
                .padding(.horizontal, UNSpacing.xl)
            }

            Spacer()

            // Error
            if let error = store.error {
                Text(error)
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.coral)
                    .padding(.horizontal, UNSpacing.xl)
            }

            // CTA
            VStack(spacing: 0) {
                UNDivider()
                Button {
                    store.send(.sendCodeTapped)
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("인증번호 받기")
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
    }
}
