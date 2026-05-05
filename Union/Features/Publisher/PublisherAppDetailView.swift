import SwiftUI
import ComposableArchitecture

// MARK: - Publisher App Detail View

/// 특정 미니앱의 버전 리스트. 테스트 가능한 버전(=업로드 이상 상태)을 탭하면
/// 즉시 테스트 세션 발급 → 번들 다운로드 → MiniAppWebView 로 전환된다.
struct PublisherAppDetailView: View {
    @Bindable var store: StoreOf<PublisherAppDetailFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UNSpacing.lg) {
                appHeader

                if store.isLoading && store.versions.isEmpty {
                    loadingState
                } else if let error = store.error, store.versions.isEmpty {
                    errorState(message: error)
                } else if store.versions.isEmpty {
                    emptyState
                } else {
                    versionList
                }
            }
            .padding(.horizontal, UNSpacing.xl)
            .padding(.vertical, UNSpacing.lg)
        }
        .background(UNColor.bgPrimary)
        .navigationTitle(store.miniApp.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { store.send(.refresh) }
        .task { store.send(.onAppear) }
        .alert(
            "테스트 실행 실패",
            isPresented: Binding(
                get: { store.testError != nil },
                set: { if !$0 { store.send(.dismissTestError) } }
            ),
            actions: {
                Button("확인", role: .cancel) { store.send(.dismissTestError) }
            },
            message: { Text(store.testError ?? "") }
        )
        .fullScreenCover(
            isPresented: Binding(
                get: { store.runningTest != nil },
                set: { if !$0 { store.send(.dismissTest) } }
            )
        ) {
            if let run = store.runningTest {
                NavigationStack {
                    MiniAppWebView(miniApp: run.miniApp)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: UNSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                    .fill(UNColor.bgAccent)
                    .frame(width: 56, height: 56)
                Image(systemName: "app.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(UNColor.interactive)
            }

            VStack(alignment: .leading, spacing: UNSpacing.xs) {
                Text(store.miniApp.workspaceName)
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
                Text(store.miniApp.description)
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    // MARK: - Version List

    private var versionList: some View {
        VStack(alignment: .leading, spacing: UNSpacing.sm) {
            Text("버전")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
                .padding(.top, UNSpacing.sm)

            VStack(spacing: UNSpacing.sm) {
                ForEach(store.versions) { version in
                    VersionRow(
                        version: version,
                        isPreparing: store.preparingVersionId == version.id,
                        action: { store.send(.versionTapped(version)) }
                    )
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: UNSpacing.sm) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous)
                    .fill(UNColor.bgPressed)
                    .frame(height: 72)
            }
        }
        .redacted(reason: .placeholder)
    }

    private var emptyState: some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "shippingbox")
                .font(.system(size: 32))
                .foregroundStyle(UNColor.textTertiary)
            Text("아직 등록된 버전이 없어요")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text("CLI나 대시보드에서 앱을 업로드해 주세요.")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UNSpacing.jumbo)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(UNColor.warning)
            Text("버전을 불러오지 못했어요")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text(message)
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { store.send(.refresh) }
                .unPrimaryButton(.medium)
                .padding(.top, UNSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UNSpacing.xxxl)
    }
}

// MARK: - Version Row

private struct VersionRow: View {
    let version: AppVersionInfo
    let isPreparing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if version.status.isTestable { action() } }) {
            HStack(spacing: UNSpacing.md) {
                VStack(alignment: .leading, spacing: UNSpacing.xs) {
                    HStack(spacing: UNSpacing.sm) {
                        Text("v\(version.versionNumber)")
                            .font(UNFont.bodyLarge(.semibold))
                            .foregroundStyle(UNColor.textPrimary)
                        statusBadge
                    }
                    if let notes = version.releaseNotes, !notes.isEmpty {
                        Text(notes)
                            .font(UNFont.captionLarge())
                            .foregroundStyle(UNColor.textSecondary)
                            .lineLimit(2)
                    }
                    metaLine
                }

                Spacer()

                trailing
            }
            .padding(UNSpacing.lg)
            .background(UNColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.md, style: .continuous))
            .unShadow(.subtle)
            .opacity(version.status.isTestable ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!version.status.isTestable || isPreparing)
    }

    private var statusBadge: some View {
        Text(version.status.displayLabel)
            .font(UNFont.captionSmall(.semibold))
            .foregroundStyle(badgeForeground)
            .padding(.horizontal, UNSpacing.sm)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .clipShape(Capsule())
    }

    private var metaLine: some View {
        HStack(spacing: UNSpacing.sm) {
            Text(version.createdAt.timeAgoDisplay())
                .font(UNFont.captionSmall())
                .foregroundStyle(UNColor.textTertiary)
            if let size = version.bundleSize {
                Text("·")
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
                Text(formatBytes(size))
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if isPreparing {
            ProgressView().scaleEffect(0.9)
        } else if version.status.isTestable {
            VStack(spacing: 2) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(UNColor.interactive)
                Text("실행")
                    .font(UNFont.captionSmall(.semibold))
                    .foregroundStyle(UNColor.interactive)
            }
        } else {
            Image(systemName: "lock")
                .font(.system(size: 16))
                .foregroundStyle(UNColor.textTertiary)
        }
    }

    private var badgeForeground: Color {
        switch version.status {
        case .deployed, .accepted: UNColor.success
        case .inReview: UNColor.warning
        case .rejected: UNColor.error
        case .uploaded: UNColor.interactive
        case .draft: UNColor.textTertiary
        }
    }

    private var badgeBackground: Color {
        switch version.status {
        case .deployed, .accepted: UNColor.success.opacity(0.12)
        case .inReview: UNColor.warning.opacity(0.12)
        case .rejected: UNColor.error.opacity(0.12)
        case .uploaded: UNColor.interactive.opacity(0.12)
        case .draft: UNColor.textTertiary.opacity(0.12)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var idx = 0
        while value >= 1024 && idx < units.count - 1 {
            value /= 1024
            idx += 1
        }
        return String(format: idx == 0 ? "%.0f %@" : "%.1f %@", value, units[idx])
    }
}

#Preview {
    NavigationStack {
        PublisherAppDetailView(
            store: Store(
                initialState: PublisherAppDetailFeature.State(
                    miniApp: PublisherMiniApp(
                        id: 1, name: "단짝", description: "친구 매칭",
                        iconUrl: nil, workspaceName: "Dankook Union",
                        status: .approved, createdAt: Date()
                    )
                )
            ) { PublisherAppDetailFeature() } withDependencies: {
                $0.publisherAppsClient = .previewValue
            }
        )
    }
}
