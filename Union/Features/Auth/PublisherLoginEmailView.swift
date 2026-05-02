import SwiftUI
import ComposableArchitecture

// MARK: - Publisher Login: Email Step View

/// 퍼블리셔 로그인 1/2 — 이메일 입력.
///
/// 디자인 의도:
/// - 사용자(User) 로그인과 시각적으로 분명히 구분되는 "퍼블리셔 콘솔" 톤 (charcoal 헤더 + 모노스페이스 액센트).
/// - QR 스킴 진입 시 test context 카드를 상단에 명시 → "어떤 미니앱·버전을 위한 인증인지" 즉시 인식.
struct PublisherLoginEmailView: View {

    @Bindable var store: StoreOf<PublisherLoginEmailFeature>
    @FocusState private var emailFocused: Bool

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
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear { emailFocused = true }
    }

    // MARK: - Console Header

    /// 다크 테마 헤더 — 사용자 로그인의 라이트 톤과 즉시 구분되는 "개발자 콘솔" 시각언어.
    private var consoleHeader: some View {
        ZStack(alignment: .topLeading) {
            // 다크 배경 + 미세한 그리드 패턴
            UNColor.charcoal900
                .overlay(GridDotsPattern())
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, UNColor.charcoal900],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                HStack(spacing: UNSpacing.sm) {
                    Circle()
                        .fill(UNColor.red500)
                        .frame(width: 6, height: 6)
                    Text("PUBLISHER_AUTH · STEP 01/02")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(UNColor.ice200.opacity(0.7))
                        .tracking(0.5)
                }

                VStack(alignment: .leading, spacing: UNSpacing.sm) {
                    Text("미니앱 개발자\n인증")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(UNColor.ice100)
                        .lineSpacing(2)

                    Text("등록된 이메일로 일회용 인증번호를 보내드립니다.")
                        .font(UNFont.bodyMedium())
                        .foregroundStyle(UNColor.ice200.opacity(0.7))
                }

                if let context = store.testContext {
                    testContextCard(context)
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

    /// QR 컨텍스트 카드 — 1회용 테스트 토큰을 받았다는 사실을 명시.
    /// 미니앱 이름은 인증 후 `test-bundle` redeem 응답에서 받아오므로 여기엔 표시하지 않는다.
    private func testContextCard(_ context: PublisherTestContext) -> some View {
        HStack(alignment: .top, spacing: UNSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(UNColor.red500.opacity(0.18))
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UNColor.red400)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.isRedeemable ? "테스트 진입 요청" : "테스트 진입 요청 · 만료 가능")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UNColor.ice200.opacity(0.6))
                    .tracking(0.5)

                Text(context.isRedeemable ? "1회용 테스트 링크" : "구버전 링크")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UNColor.ice100)

                if let id = context.displayIdentifier {
                    Text(context.isRedeemable ? "token · \(id)" : "version · \(id)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(UNColor.ice200.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(UNSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Body Content

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: UNSpacing.xxl) {
                    UNFormField(
                        label: "퍼블리셔 이메일",
                        placeholder: "publisher@dankook.ac.kr",
                        text: $store.email,
                        icon: "envelope",
                        error: store.emailError,
                        keyboardType: .emailAddress,
                        textContentType: .username
                    )
                    .focused($emailFocused)
                    .onSubmit { store.send(.sendCodeTapped) }

                    InfoNote(
                        icon: "info.circle.fill",
                        text: "유니온 웹 대시보드에 등록된 퍼블리셔 계정 이메일을 입력하세요."
                    )
                }
                .padding(.horizontal, UNSpacing.xl)
                .padding(.top, UNSpacing.xxl)
            }

            UNDivider()
            Button {
                emailFocused = false
                store.send(.sendCodeTapped)
            } label: {
                if store.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text("인증번호 받기")
                }
            }
            .unPrimaryButton(.large, fullWidth: true)
            .disabled(store.isLoading || store.email.isEmpty)
            .padding(.horizontal, UNSpacing.xl)
            .padding(.vertical, UNSpacing.lg)
            .background(UNColor.bgPrimary)
        }
    }
}

// MARK: - Helper Subviews

private struct InfoNote: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: UNSpacing.sm) {
            Image(systemName: icon)
                .font(UNFont.bodySmall())
                .foregroundStyle(UNColor.textTertiary)
                .padding(.top, 1)
            Text(text)
                .font(UNFont.bodySmall())
                .foregroundStyle(UNColor.textSecondary)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(UNSpacing.md)
        .background(UNColor.bgPressed)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
    }
}

/// 헤더 배경의 미세한 도트 그리드 — "터미널/콘솔" 시각 메타포.
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

#Preview("Default") {
    NavigationStack {
        PublisherLoginEmailView(
            store: Store(initialState: PublisherLoginEmailFeature.State()) {
                PublisherLoginEmailFeature()
            } withDependencies: {
                $0.publisherAuthClient = .previewValue
            }
        )
    }
}

#Preview("From QR") {
    NavigationStack {
        PublisherLoginEmailView(
            store: Store(
                initialState: PublisherLoginEmailFeature.State(
                    testContext: PublisherTestContext(
                        token: "8f3a2c1b-19b2-4fa1-b503-7de2e1f0a8b9",
                        legacyVersionId: nil
                    )
                )
            ) {
                PublisherLoginEmailFeature()
            } withDependencies: {
                $0.publisherAuthClient = .previewValue
            }
        )
    }
}
