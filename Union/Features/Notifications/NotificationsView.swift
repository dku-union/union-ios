import SwiftUI

struct NotificationsView: View {
    private let notifications = MockData.notifications

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UBSpacing.md) {
                    ForEach(notifications) { notification in
                        NotificationRow(notification: notification)
                    }
                }
                .padding(UBSpacing.xl)
            }
            .background(UBColor.bgPrimary)
            .navigationTitle("알림")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("설정") {}
                        .font(.subheadline)
                        .foregroundStyle(UBColor.textSecondary)
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
        case .update: return UBColor.brand
        case .recommendation: return UBColor.amber
        case .announcement: return UBColor.coral
        }
    }

    private var iconBgColor: Color {
        switch notification.type {
        case .update: return UBColor.brandLight
        case .recommendation: return UBColor.amberLight
        case .announcement: return UBColor.coralLight
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: UBSpacing.lg) {
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        notification.isRead
                            ? UBColor.textSecondary
                            : UBColor.textPrimary
                    )

                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
                    .lineLimit(2)

                Text(notification.createdAt.timeAgoDisplay())
                    .font(.caption2)
                    .foregroundStyle(UBColor.textTertiary)
                    .padding(.top, 2)
            }

            Spacer()

            if !notification.isRead {
                Circle()
                    .fill(UBColor.coral)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(UBSpacing.lg)
        .background(notification.isRead ? UBColor.surface : UBColor.brandLight.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.md, style: .continuous))
        .ubShadow(.subtle)
    }
}

