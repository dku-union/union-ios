import SwiftUI
import ComposableArchitecture

// MARK: - Publisher View

/// 퍼블리셔 전용 페이지 — "내가 업로드 한 앱" 목록.
/// Tap 시 버전 리스트로 push.
struct PublisherView: View {
    @Bindable var store: StoreOf<PublisherFeature>

    var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(alignment: .leading, spacing: UNSpacing.lg) {
                    header
                        .padding(.horizontal, UNSpacing.xl)
                        .padding(.top, UNSpacing.lg)

                    if store.isLoading && store.apps.isEmpty {
                        loadingState
                    } else if let error = store.error, store.apps.isEmpty {
                        errorState(message: error)
                    } else if store.apps.isEmpty {
                        emptyState
                    } else {
                        appList
                    }

                    Spacer(minLength: UNSpacing.xxxl)
                }
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("퍼블리셔")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await refresh() }
            .task { store.send(.onAppear) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            store.send(.logoutTapped)
                        } label: {
                            Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(UNColor.textSecondary)
                    }
                }
            }
        } destination: { store in
            switch store.case {
            case .appDetail(let detailStore):
                PublisherAppDetailView(store: detailStore)
            }
        }
    }

    @MainActor
    private func refresh() async {
        store.send(.refresh)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: UNSpacing.xs) {
            Text("내가 업로드 한 앱")
                .font(UNFont.headingLarge())
                .foregroundStyle(UNColor.textPrimary)
            Text("앱을 선택해 버전별 테스트 빌드를 실행할 수 있어요.")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
        }
    }

    // MARK: - App List

    private var appList: some View {
        VStack(spacing: UNSpacing.md) {
            ForEach(store.apps) { app in
                Button {
                    store.send(.appTapped(app))
                } label: {
                    PublisherAppRow(app: app)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, UNSpacing.xl)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: UNSpacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous)
                    .fill(UNColor.bgPressed)
                    .frame(height: 80)
            }
        }
        .padding(.horizontal, UNSpacing.xl)
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36))
                .foregroundStyle(UNColor.textTertiary)
            Text("아직 업로드한 앱이 없어요")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text("Union 대시보드에서 앱을 업로드해 주세요.")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UNSpacing.jumbo)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(UNColor.warning)
            Text("불러오기 실패")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text(message)
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                store.send(.refresh)
            }
            .unPrimaryButton(.medium)
            .padding(.top, UNSpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, UNSpacing.xl)
        .padding(.vertical, UNSpacing.xxxl)
    }
}

// MARK: - Row

private struct PublisherAppRow: View {
    let app: PublisherMiniApp

    var body: some View {
        HStack(spacing: UNSpacing.md) {
            iconView

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(app.name)
                    .font(UNFont.bodyLarge(.semibold))
                    .foregroundStyle(UNColor.textPrimary)

                HStack(spacing: UNSpacing.xs) {
                    statusBadge
                    Text(app.workspaceName)
                        .font(UNFont.captionSmall())
                        .foregroundStyle(UNColor.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(UNColor.textTertiary)
        }
        .padding(UNSpacing.lg)
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    private var iconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                .fill(UNColor.bgAccent)
                .frame(width: 48, height: 48)
            Image(systemName: "app.fill")
                .font(.system(size: 22))
                .foregroundStyle(UNColor.interactive)
        }
    }

    private var statusBadge: some View {
        Text(app.status.displayLabel)
            .font(UNFont.captionSmall(.semibold))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, UNSpacing.sm)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .clipShape(Capsule())
    }

    private var badgeForeground: Color {
        switch app.status {
        case .approved: UNColor.success
        case .pending:  UNColor.warning
        case .suspended: UNColor.error
        }
    }

    private var badgeBackground: Color {
        switch app.status {
        case .approved: UNColor.success.opacity(0.12)
        case .pending:  UNColor.warning.opacity(0.12)
        case .suspended: UNColor.error.opacity(0.12)
        }
    }
}

#Preview {
    PublisherView(
        store: Store(initialState: PublisherFeature.State()) { PublisherFeature() } withDependencies: {
            $0.publisherAppsClient = .previewValue
        }
    )
}
