import SwiftUI

struct ProfileView: View {
    private let user = MockData.currentUser

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UNSpacing.xxl) {
                    profileCard
                    menuSection
                    infoSection
                }
                .padding(UNSpacing.xl)
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("마이페이지")
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        HStack(spacing: UNSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: UNColor.gradientBluePurple,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text(user.profileEmoji)
                    .font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(user.nickname)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(UNColor.textPrimary)

                HStack(spacing: UNSpacing.sm) {
                    Text(user.university)
                        .font(.caption)
                        .foregroundStyle(UNColor.textSecondary)

                    if user.isVerified {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(UNColor.mint)
                            Text("인증됨")
                                .font(.caption2)
                                .foregroundStyle(UNColor.mint)
                        }
                    }
                }

                Text(user.department)
                    .font(.caption)
                    .foregroundStyle(UNColor.textTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(UNColor.textTertiary)
        }
        .padding(UNSpacing.xl)
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.card)
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "pencil", title: "프로필 수정", color: UNColor.brand)
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.shield", title: "권한 관리", color: UNColor.violet)
            Divider().padding(.leading, 52)
            menuRow(icon: "bell", title: "알림 설정", color: UNColor.amber)
            Divider().padding(.leading, 52)
            menuRow(icon: "star", title: "내 리뷰 관리", color: UNColor.coral)
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "info.circle", title: "앱 정보", color: UNColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(icon: "doc.text", title: "이용약관", color: UNColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(icon: "hand.raised", title: "개인정보 처리방침", color: UNColor.textTertiary)
            Divider().padding(.leading, 52)
            menuRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "로그아웃",
                color: UNColor.textSecondary
            )
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    // MARK: - Menu Row

    private func menuRow(icon: String, title: String, color: Color) -> some View {
        Button {} label: {
            HStack(spacing: UNSpacing.lg) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(UNColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(UNColor.textTertiary)
            }
            .padding(.horizontal, UNSpacing.xl)
            .padding(.vertical, UNSpacing.lg)
        }
    }
}
