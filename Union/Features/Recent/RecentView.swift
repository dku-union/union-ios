import SwiftUI

struct RecentView: View {
    private let recentApps = MockData.recentApps

    var body: some View {
        NavigationStack {
            Group {
                if recentApps.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: UBSpacing.md) {
                            ForEach(recentApps) { app in
                                RecentAppRow(app: app)
                            }
                        }
                        .padding(UBSpacing.xl)
                    }
                }
            }
            .background(UBColor.bgPrimary)
            .navigationTitle("최근 사용")
        }
    }

    private var emptyState: some View {
        VStack(spacing: UBSpacing.lg) {
            Text("🕐")
                .font(.system(size: 48))
            Text("최근 사용한 미니앱이 없어요")
                .font(.headline)
                .foregroundStyle(UBColor.textPrimary)
            Text("홈에서 미니앱을 실행해보세요")
                .font(.subheadline)
                .foregroundStyle(UBColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Recent App Row

private struct RecentAppRow: View {
    let app: MiniApp

    var body: some View {
        HStack(spacing: UBSpacing.lg) {
            AppIconView(emoji: app.iconEmoji, colorHex: app.iconColorHex, size: 48)

            VStack(alignment: .leading, spacing: UBSpacing.xs) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(UBColor.textPrimary)

                Text(app.publisher)
                    .font(.caption)
                    .foregroundStyle(UBColor.textTertiary)
            }

            Spacer()

            Button {
                // Launch mini app
            } label: {
                Text("열기")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(UBColor.brand)
                    .padding(.horizontal, UBSpacing.lg)
                    .padding(.vertical, UBSpacing.sm)
                    .background(UBColor.brandLight)
                    .clipShape(Capsule())
            }
        }
        .padding(UBSpacing.lg)
        .background(UBColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UBRadius.md, style: .continuous))
        .ubShadow(.subtle)
    }
}
