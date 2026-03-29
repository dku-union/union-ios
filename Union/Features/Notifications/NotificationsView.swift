import SwiftUI

struct NotificationsView: View {
    private let notifications = MockData.notifications

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UNSpacing.md) {
                    ForEach(notifications) { notification in
                        NotificationRow(notification: notification)
                    }
                }
                .padding(UNSpacing.xl)
            }
            .background(UNColor.bgPrimary)
            .navigationTitle("알림")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정") {}
                        .font(.subheadline)
                        .foregroundStyle(UNColor.textSecondary)
                }
            }
        }
    }
}

// MARK: - Notification Row

private struct NotificationRow: View {
    let notification: AppNotification

    private var icon: String {
        switch notification.type {
        case .update: return "arrow.down.app.fill"
        case .recommendation: return "star.fill"
        case .announcement: return "megaphone.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .update: return UNColor.brand
        case .recommendation: return UNColor.amber
        case .announcement: return UNColor.coral
        }
    }

    private var iconBgColor: Color {
        switch notification.type {
        case .update: return UNColor.brandLight
        case .recommendation: return UNColor.amberLight
        case .announcement: return UNColor.coralLight
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: UNSpacing.lg) {
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        notification.isRead
                            ? UNColor.textSecondary
                            : UNColor.textPrimary
                    )

                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(UNColor.textTertiary)
                    .lineLimit(2)

                Text(notification.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundStyle(UNColor.textTertiary)
                    .padding(.top, 2)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(UNColor.coral)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(UNSpacing.lg)
        .background(notification.isRead ? UNColor.surface : UNColor.brandLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
        .unShadow(.subtle)
    }
}

