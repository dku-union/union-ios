import SwiftUI

// MARK: - App Info View

/// 앱 정보 — 버전/빌드, 약관·개인정보처리방침 링크, 문의처, 운영 주체.
struct AppInfoView: View {
    @State private var webLink: WebLink?
    @Environment(\.openURL) private var openURL

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: UNSpacing.xxl) {
                identitySection
                linksSection
                Text("© 2026 Union · 단국대학교 캡스톤디자인 2026")
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textTertiary)
            }
            .padding(UNSpacing.xl)
        }
        .background(UNColor.bgPrimary)
        .navigationTitle("앱 정보")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $webLink) { link in
            SafariView(url: link.url)
        }
    }

    private var identitySection: some View {
        VStack(spacing: UNSpacing.sm) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: UNColor.gradientRedAccent, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 76, height: 76)
                .overlay(
                    Text("U")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                )
                .unShadow(.subtle)

            Text("유니온")
                .font(UNFont.headingLarge())
                .foregroundStyle(UNColor.textPrimary)

            Text("버전 \(versionText)")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textTertiary)
        }
        .padding(.top, UNSpacing.lg)
    }

    private var linksSection: some View {
        VStack(spacing: 0) {
            row(icon: "doc.text", title: "이용약관") { webLink = WebLink(LegalLinks.terms) }
            Divider().padding(.leading, 52)
            row(icon: "hand.raised", title: "개인정보 처리방침") { webLink = WebLink(LegalLinks.privacy) }
            Divider().padding(.leading, 52)
            row(icon: "envelope", title: "문의하기", detail: "union@dankook.ac.kr") {
                if let url = URL(string: "mailto:union@dankook.ac.kr") { openURL(url) }
            }
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    private func row(
        icon: String,
        title: String,
        detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: UNSpacing.lg) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(UNColor.textSecondary)
                    .frame(width: 24)

                Text(title)
                    .font(UNFont.bodyMedium())
                    .foregroundStyle(UNColor.textPrimary)

                Spacer()

                if let detail {
                    Text(detail)
                        .font(UNFont.captionLarge())
                        .foregroundStyle(UNColor.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
            }
            .padding(.horizontal, UNSpacing.xl)
            .padding(.vertical, UNSpacing.lg)
        }
    }
}
