import SwiftUI
import ComposableArchitecture

// MARK: - Publisher Login: OTP Step View

/// 퍼블리셔 로그인 2/2 — 6자리 OTP 입력.
///
/// 이메일 step과 동일한 콘솔 톤 헤더를 유지해 단계 전환에서도 시각적 일관성을 보존한다.
struct PublisherLoginCodeView: View {

    let store: StoreOf<PublisherLoginCodeFeature>

    var body: some View {
        ZStack(alignment: .top) {
            UNColor.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                consoleHeader
                content
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(UNColor.charcoal900, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { store.send(.onAppear) }
    }

    private var consoleHeader: some View {
        ZStack(alignment: .topLeading) {
            UNColor.charcoal900
                .overlay(GridDotsPattern())
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, UNColor.charcoal900],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                HStack(spacing: UNSpacing.sm) {
                    Circle().fill(UNColor.red500).frame(width: 6, height: 6)
                    Text("PUBLISHER_AUTH · STEP 02/02")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(UNColor.ice200.opacity(0.7))
                        .tracking(0.5)
                }

                VStack(alignment: .leading, spacing: UNSpacing.sm) {
                    Text("인증번호 입력")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(UNColor.ice100)

                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                        Text(store.maskedEmail)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(UNColor.ice200.opacity(0.8))
                    .padding(.horizontal, UNSpacing.md)
                    .padding(.vertical, UNSpacing.xs)
                    .background(
                        Capsule().fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }

                if let context = store.testContext, let id = context.displayIdentifier {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 11))
                        Text(context.isRedeemable ? "TOKEN" : "VERSION")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(0.5)
                        Text(id)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(UNColor.ice200.opacity(0.7))
                }
            }
            .padding(.horizontal, UNSpacing.xl)
            .padding(.top, UNSpacing.xl)
            .padding(.bottom, UNSpacing.xxxl)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: UNRadius.xxl,
                bottomTrailingRadius: UNRadius.xxl,
                style: .continuous
            )
        )
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: UNSpacing.xxxl) {
                    // 만료 카운트다운
                    HStack(spacing: UNSpacing.xs) {
                        Image(systemName: "clock")
                            .font(UNFont.bodySmall())
                        Text(formattedTime(store.expirationSeconds))
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                        Text("후 만료")
                            .font(UNFont.bodySmall())
                    }
                    .foregroundStyle(
                        store.expirationSeconds <= 60 ? UNColor.error : UNColor.textSecondary
                    )
                    .padding(.top, UNSpacing.xxl)

                    // OTP 입력 박스
                    UNCodeField(
                        code: Binding(
                            get: { store.code },
                            set: { store.send(.codeChanged($0)) }
                        ),
                        length: 6,
                        error: store.codeError
                    )
                    .padding(.horizontal, UNSpacing.xl)

                    if store.isLoading {
                        ProgressView()
                            .tint(UNColor.interactive)
                    }

                    // 재전송 영역
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
                .frame(maxWidth: .infinity)
                .padding(.bottom, UNSpacing.xxxl)
            }
        }
    }

    private func formattedTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

private struct GridDotsPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let spacing: CGFloat = 16
            let radius: CGFloat = 0.7
            let dotColor = Color.white.opacity(0.06)

            var y: CGFloat = spacing
            while y < size.height {
                var x: CGFloat = spacing
                while x < size.width {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(dotColor))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

#Preview {
    NavigationStack {
        PublisherLoginCodeView(
            store: Store(
                initialState: PublisherLoginCodeFeature.State(
                    email: "publisher@dankook.ac.kr",
                    maskedEmail: "pu*****@dankook.ac.kr",
                    expiresInSeconds: 287,
                    testContext: PublisherTestContext(
                        token: "8f3a2c1b-19b2-4fa1-b503-7de2e1f0a8b9",
                        legacyVersionId: nil
                    )
                )
            ) {
                PublisherLoginCodeFeature()
            } withDependencies: {
                $0.publisherAuthClient = .previewValue
            }
        )
    }
}
