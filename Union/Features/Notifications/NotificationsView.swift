import SwiftUI
import ComposableArchitecture

struct NotificationsView: View {
    @Bindable var store: StoreOf<NotificationsFeature>

    var body: some View {
        NavigationStack {
            content
                .background(UNColor.bgPrimary)
                .navigationTitle("알림")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("전부 읽음") {
                            store.send(.markAllReadTapped)
                        }
                        .font(UNFont.bodyMedium())
                        .foregroundStyle(
                            store.unreadCount > 0
                                ? UNColor.interactive
                                : UNColor.textSecondary
                        )
                        .disabled(store.unreadCount == 0)
                    }
                }
                .task { store.send(.onAppear) }
                .refreshable { await refreshAsync() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.items.isEmpty {
            loadingPlaceholder
        } else if let message = store.errorMessage, store.items.isEmpty {
            errorView(message: message)
        } else if store.items.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: UNSpacing.md) {
                ForEach(store.items) { item in
                    Button {
                        store.send(.itemTapped(item))
                    } label: {
                        NotificationRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == store.items.last?.id {
                            store.send(.loadMore)
                        }
                    }
                }
                if store.isLoadingMore {
                    ProgressView().padding()
                }
            }
            .padding(UNSpacing.xl)
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: UNSpacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                NotificationRowSkeleton()
            }
            Spacer()
        }
        .padding(UNSpacing.xl)
    }

    private var emptyState: some View {
        VStack(spacing: UNSpacing.lg) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(UNColor.textTertiary)
            Text("받은 알림이 없습니다")
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(UNColor.warning)
            Text(message)
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { store.send(.refresh) }
                .font(UNFont.bodyMedium(.semibold))
                .foregroundStyle(UNColor.interactive)
        }
        .padding(UNSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func refreshAsync() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            store.send(.refresh)
            // 단순화: refresh effect 가 끝나는 시점을 별도 awaitable 로 노출하지 않으므로
            // 즉시 resume — refreshable indicator 는 짧게만 표시되고, UI 는 itemsLoaded 후 갱신.
            continuation.resume()
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let item: NotificationInboxItem

    private var icon: String {
        switch item.category {
        case .UPDATE, .PUBLISHER_BUILD: return "arrow.down.app.fill"
        case .RECOMMENDATION: return "star.fill"
        case .ANNOUNCEMENT, .REVIEW_RESULT: return "megaphone.fill"
        case .MINIAPP_GENERIC: return "app.badge.fill"
        }
    }

    private var iconColor: Color {
        switch item.category {
        case .UPDATE, .PUBLISHER_BUILD: return UNColor.interactive
        case .RECOMMENDATION: return UNColor.warning
        case .ANNOUNCEMENT, .REVIEW_RESULT: return UNColor.error
        case .MINIAPP_GENERIC: return UNColor.interactive
        }
    }

    private var iconBgColor: Color {
        switch item.category {
        case .UPDATE, .PUBLISHER_BUILD: return UNColor.bgAccent
        case .RECOMMENDATION: return Color(hex: "FFF8EB")
        case .ANNOUNCEMENT, .REVIEW_RESULT: return UNColor.red100
        case .MINIAPP_GENERIC: return UNColor.bgAccent
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: UNSpacing.lg) {
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(UNFont.bodyLarge())
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(item.title)
                    .font(UNFont.bodyMedium(.semibold))
                    .foregroundStyle(item.read ? UNColor.textSecondary : UNColor.textPrimary)

                Text(item.body)
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textTertiary)
                    .lineLimit(2)

                Text(item.createdAt.timeAgoDisplay())
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
                    .padding(.top, 2)
            }

            Spacer()

            if !item.read {
                Circle()
                    .fill(UNColor.interactive)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(UNSpacing.lg)
        .background(item.read ? UNColor.surface : UNColor.bgAccent.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
        .unShadow(.subtle)
    }
}

// MARK: - Skeleton

private struct NotificationRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: UNSpacing.lg) {
            SkeletonRect(cornerRadius: UNRadius.full)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: UNSpacing.sm) {
                SkeletonRect()
                    .frame(width: 150, height: 13)
                SkeletonRect()
                    .frame(height: 11)
                SkeletonRect()
                    .frame(width: 70, height: 10)
            }
        }
        .padding(UNSpacing.lg)
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
        .unShadow(.subtle)
    }
}
