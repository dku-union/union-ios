import SwiftUI

// MARK: - Notification Settings View

/// 알림 설정 — 구독 중인 미니앱 목록을 보여주고 앱별 푸시 on/off 및 구독 해지를 제공.
/// 기존 `NotificationClient` 의 구독 API(fetchSubscriptions/setPushEnabled/unsubscribe)를 UI 로 연결.
struct NotificationSettingsView: View {

    private struct Row: Identifiable, Equatable {
        let id: Int64
        let appId: String?
        let name: String
        let iconUrl: String?
        var pushEnabled: Bool
    }

    @State private var rows: [Row] = []
    @State private var phase: Phase = .loading
    @State private var errorBanner: String?
    /// 푸시 토글 요청이 진행 중인 행. 같은 행의 연타로 인한 out-of-order 응답을 막는다.
    @State private var inFlight: Set<Int64> = []

    private enum Phase: Equatable { case loading, loaded, failed(String) }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                errorView(message)
            case .loaded:
                if rows.isEmpty {
                    emptyView
                } else {
                    list
                }
            }
        }
        .navigationTitle("알림 설정")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("알림 설정 변경 실패", isPresented: Binding(
            get: { errorBanner != nil },
            set: { if !$0 { errorBanner = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorBanner ?? "")
        }
        .tint(UNColor.interactive)
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                ForEach(rows) { row in
                    rowView(row)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                unsubscribe(row)
                            } label: {
                                Label("구독 해지", systemImage: "bell.slash")
                            }
                        }
                }
            } footer: {
                Text("구독한 미니앱이 보내는 푸시 알림을 앱별로 켜고 끌 수 있어요. 왼쪽으로 밀면 구독을 해지합니다.")
            }
        }
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: UNSpacing.lg) {
            AppIconView(iconUrl: row.iconUrl, emoji: nil, colorHex: nil, size: 40)

            Text(row.name)
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textPrimary)

            Spacer()

            Toggle("", isOn: Binding(
                get: { row.pushEnabled },
                set: { setPush(row, enabled: $0) }
            ))
            .labelsHidden()
            .tint(UNColor.interactive)
            .disabled(row.appId == nil || inFlight.contains(row.id))
        }
    }

    private var emptyView: some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40))
                .foregroundStyle(UNColor.textTertiary)
            Text("구독 중인 미니앱이 없어요")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text("미니앱에서 알림을 구독하면 여기서 관리할 수 있어요.")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(UNSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UNColor.bgPrimary)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 40))
                .foregroundStyle(UNColor.textTertiary)
            Text("불러올 수 없습니다")
                .font(UNFont.headingSmall())
                .foregroundStyle(UNColor.textPrimary)
            Text(message)
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textSecondary)
                .multilineTextAlignment(.center)
            Button("다시 시도") { Task { await load() } }
                .font(UNFont.bodyMedium(.medium))
                .foregroundStyle(UNColor.interactive)
        }
        .padding(UNSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(UNColor.bgPrimary)
    }

    // MARK: - Actions

    private func load() async {
        phase = .loading
        do {
            let subs = try await NotificationClient.liveValue.fetchSubscriptions()
            rows = subs.map { Row(id: $0.id, appId: $0.appId, name: $0.miniAppName,
                                  iconUrl: $0.iconUrl, pushEnabled: $0.pushEnabled) }
            phase = .loaded
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "네트워크 오류가 발생했습니다")
        }
    }

    private func setPush(_ row: Row, enabled: Bool) {
        guard let appId = row.appId, !inFlight.contains(row.id) else { return }
        inFlight.insert(row.id)
        // 낙관적 업데이트
        updateRow(id: row.id) { $0.pushEnabled = enabled }
        Task {
            defer { inFlight.remove(row.id) }
            do {
                try await NotificationClient.liveValue.setPushEnabled(appId, enabled)
            } catch {
                // 실패 시 해당 행만 롤백
                updateRow(id: row.id) { $0.pushEnabled = !enabled }
                errorBanner = "푸시 설정을 변경하지 못했습니다."
            }
        }
    }

    private func unsubscribe(_ row: Row) {
        guard let appId = row.appId,
              let idx = rows.firstIndex(where: { $0.id == row.id }) else { return }
        let removed = rows[idx]
        rows.remove(at: idx)
        Task {
            do {
                try await NotificationClient.liveValue.unsubscribe(appId)
            } catch {
                // 실패 시 해당 행만 원래 위치에 복원 — 그 사이 다른 행 변경은 보존.
                rows.insert(removed, at: min(idx, rows.count))
                errorBanner = "구독 해지에 실패했습니다."
            }
        }
    }

    private func updateRow(id: Int64, _ mutate: (inout Row) -> Void) {
        guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
        mutate(&rows[idx])
    }
}
