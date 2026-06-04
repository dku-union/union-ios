import SwiftUI

struct ProfileView: View {
    let onLogout: () -> Void

    @State private var user: UserProfile?
    @State private var showLogoutConfirm = false

    /// /api/v1/users/me 응답이 도착하기 전 보여줄 폴백 프로필.
    /// nickname/university 는 빈 상태로 표시하지 않기 위해 placeholder.
    private var placeholderUser: UserProfile {
        UserProfile(
            id: UUID(),
            nickname: "—",
            university: "",
            department: "",
            isVerified: false,
            profileEmoji: "👤"
        )
    }

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
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard user == nil else { return }
                do {
                    let me = try await UserClient.liveValue.fetchMe()
                    user = me.toUserProfile()
                } catch {
                    // 미인증/네트워크 오류 시 placeholder 유지
                }
            }
            .confirmationDialog(
                "로그아웃 하시겠어요?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("로그아웃", role: .destructive) {
                    onLogout()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("저장된 로그인 정보와 미니앱 세션이 모두 삭제됩니다.")
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        let display = user ?? placeholderUser
        return HStack(spacing: UNSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: UNColor.gradientRedAccent,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Text(display.profileEmoji)
                    .font(.system(size: 30))
            }

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(display.nickname)
                    .font(UNFont.headingLarge())
                    .foregroundStyle(UNColor.textPrimary)

                HStack(spacing: UNSpacing.sm) {
                    if !display.university.isEmpty {
                        Text(display.university)
                            .font(UNFont.captionLarge())
                            .foregroundStyle(UNColor.textSecondary)
                    }

                    if display.isVerified {
                        HStack(spacing: 2) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(UNFont.captionSmall())
                                .foregroundStyle(UNColor.success)
                            Text("인증됨")
                                .font(UNFont.captionSmall())
                                .foregroundStyle(UNColor.success)
                        }
                    }
                }

                if !display.department.isEmpty {
                    Text(display.department)
                        .font(UNFont.captionLarge())
                        .foregroundStyle(UNColor.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(UNFont.captionSmall())
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
            menuRow(icon: "pencil", title: "프로필 수정", color: UNColor.interactive)
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.shield", title: "권한 관리", color: UNColor.violet)
            Divider().padding(.leading, 52)
            menuRow(icon: "bell", title: "알림 설정", color: UNColor.warning)
            Divider().padding(.leading, 52)
            menuRow(icon: "star", title: "내 리뷰 관리", color: UNColor.error)
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
                color: UNColor.textSecondary,
                action: { showLogoutConfirm = true }
            )
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    // MARK: - Menu Row

    private func menuRow(
        icon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            HStack(spacing: UNSpacing.lg) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(title)
                    .font(UNFont.bodyMedium())
                    .foregroundStyle(UNColor.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
            }
            .padding(.horizontal, UNSpacing.xl)
            .padding(.vertical, UNSpacing.lg)
        }
    }
}
