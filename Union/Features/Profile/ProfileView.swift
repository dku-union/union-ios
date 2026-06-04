import SwiftUI

struct ProfileView: View {
    let onLogout: () -> Void

    @State private var user: UserProfile?
    @State private var showLogoutConfirm = false
    @State private var route: Route?
    @State private var webLink: WebLink?
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    private enum Route: Hashable { case edit, notificationSettings, permissions, appInfo }

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
                await loadMe()
            }
            .navigationDestination(item: $route) { route in
                switch route {
                case .edit:
                    if let user {
                        ProfileEditView(profile: user) { updated in
                            self.user = updated
                        }
                    }
                case .notificationSettings:
                    NotificationSettingsView()
                case .permissions:
                    PermissionSettingsView()
                case .appInfo:
                    AppInfoView()
                }
            }
            .sheet(item: $webLink) { link in
                SafariView(url: link.url)
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
            .confirmationDialog(
                "정말 탈퇴하시겠어요?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("회원 탈퇴", role: .destructive) {
                    deleteAccount()
                }
                Button("취소", role: .cancel) {}
            } message: {
                Text("계정과 알림 구독이 해지되고 다시 로그인할 수 없습니다. 이 작업은 되돌릴 수 없습니다.")
            }
            .alert("탈퇴 실패", isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
        }
    }

    // MARK: - Profile Card

    private var profileCard: some View {
        let display = user ?? placeholderUser
        return Button {
            if user != nil { route = .edit }
        } label: {
            HStack(spacing: UNSpacing.lg) {
                avatarView(display)

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
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func avatarView(_ display: UserProfile) -> some View {
        ZStack {
            if let urlString = display.profileImageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        emojiAvatar(display)
                    }
                }
            } else {
                emojiAvatar(display)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private func emojiAvatar(_ display: UserProfile) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: UNColor.gradientRedAccent,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(display.profileEmoji)
                .font(.system(size: 30))
        }
    }

    // MARK: - Menu Section

    private var menuSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "pencil", title: "프로필 수정", color: UNColor.interactive) {
                if user != nil { route = .edit }
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "lock.shield", title: "권한 관리", color: UNColor.violet) {
                route = .permissions
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "bell", title: "알림 설정", color: UNColor.warning) {
                route = .notificationSettings
            }
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: 0) {
            menuRow(icon: "info.circle", title: "앱 정보", color: UNColor.textTertiary) {
                route = .appInfo
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "doc.text", title: "이용약관", color: UNColor.textTertiary) {
                webLink = WebLink(LegalLinks.terms)
            }
            Divider().padding(.leading, 52)
            menuRow(icon: "hand.raised", title: "개인정보 처리방침", color: UNColor.textTertiary) {
                webLink = WebLink(LegalLinks.privacy)
            }
            Divider().padding(.leading, 52)
            menuRow(
                icon: "rectangle.portrait.and.arrow.right",
                title: "로그아웃",
                color: UNColor.textSecondary,
                action: { showLogoutConfirm = true }
            )
            Divider().padding(.leading, 52)
            if isDeleting {
                HStack(spacing: UNSpacing.lg) {
                    ProgressView().frame(width: 24)
                    Text("탈퇴 처리 중…")
                        .font(UNFont.bodyMedium())
                        .foregroundStyle(UNColor.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, UNSpacing.xl)
                .padding(.vertical, UNSpacing.lg)
            } else {
                menuRow(
                    icon: "person.crop.circle.badge.xmark",
                    title: "회원 탈퇴",
                    color: UNColor.error,
                    action: { showDeleteConfirm = true }
                )
            }
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

    // MARK: - Actions

    private func loadMe() async {
        do {
            let me = try await UserClient.liveValue.fetchMe()
            user = me.toUserProfile()
        } catch {
            // 미인증/네트워크 오류 시 placeholder 유지
        }
    }

    private func deleteAccount() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            do {
                try await UserClient.liveValue.deleteAccount()
                isDeleting = false
                // 서버가 토큰/푸시/구독을 정리. 로컬 세션도 동일 teardown 으로 정리하고 로그인 화면으로.
                onLogout()
            } catch {
                isDeleting = false
                deleteError = (error as? LocalizedError)?.errorDescription ?? "잠시 후 다시 시도해주세요."
            }
        }
    }
}
