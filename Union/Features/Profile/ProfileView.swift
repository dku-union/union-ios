import SwiftUI

struct ProfileView: View {
    private let user = MockData.currentUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UBSpacing.xxl) {
                    profileCard
                    menuSection
                    infoSection
                }
                .padding(UBSpacing.xl)
            }
            .background(UBColor.bgPrimary)
            .navigationTitle("마이페이지")
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: UBSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: UBColor.gradientBluePurple,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text(user.profileEmoji)
                    .font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(user.nickname)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(UBColor.textPrimary)

                HStack(spacing: UBSpacing.sm) {
                    Text(user.university)
                        .font(.caption)
                        .foregroundStyle(UBColor.textSecondary)

                    if user.isVerified {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(UBColor.mint)
                            Text("인증됨")
                                .font(.caption2)
                                .foregroundStyle(UBColor.mint)
                        }
                    }
                }

                Text(user.department)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(UBColor.textTertiary)
        }
        .padding(UBSpacing.xl)
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.lg, style: .continuous))
        .ubShadow(.card)
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "pencil", title: "프로필 수정", color: UBColor.brand)
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.shield", title: "권한 관리", color: UBColor.violet)
            Divider().padding(.leading, 52)
            menuRow(icon: "bell", title: "알림 설정", color: UBColor.amber)
            Divider().padding(.leading, 52)
            menuRow(icon: "star", title: "내 리뷰 관리", color: UBColor.coral)
        }
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.lg, style: .continuous))
        .ubShadow(.subtle)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "info.circle", title: "앱 정보", color: UBColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(icon: "doc.text", title: "이용약관", color: UBColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(icon: "hand.raised", title: "개인정보 처리방침", color: UBColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "로그아웃",
                color: UBColor.textSecondary
            )
        }
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.lg, style: .continuous))
        .ubShadow(.subtle)
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, title: String, color: Color) -> some View {
        Button {} label: {
            HStack(spacing: UBSpacing.lg) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(UBColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(UBColor.textTertiary)
            }
            .padding(.horizontal, UBSpacing.xl)
            .padding(.vertical, UBSpacing.lg)
        }
    }
}
