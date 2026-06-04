import SwiftUI
import UserNotifications
import AVFoundation
import Photos
import CoreLocation

// MARK: - Permission Settings View

/// 권한 관리 — 미니앱별 권한(앱-동의 계층)을 직접 켜고 끄고, 기기 시스템 권한 상태를 함께 보여준다.
///
/// 2계층 모델 시각화:
/// - 상단 "미니앱 권한": 사용자×미니앱 동의 결정(백엔드 동기화). 토글 즉시 적용 + PermissionStore 반영.
/// - 하단 "기기 시스템 권한": iOS OS 권한 상태(읽기 전용). 변경은 iOS 설정에서만 가능.
struct PermissionSettingsView: View {

    // MARK: 미니앱 권한 상태
    @State private var groups: [MiniAppPermissionGroup] = []
    @State private var isLoadingApps = true
    @State private var loadFailed = false
    @State private var expanded: Set<Int> = []

    // MARK: 시스템 권한 상태
    @State private var systemItems: [SystemItem] = PermissionSettingsView.initialSystemItems

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UNSpacing.xxl) {
                Text("미니앱이 사용하는 권한을 직접 켜고 끌 수 있어요. 변경은 즉시 적용돼요.")
                    .font(UNFont.bodySmall())
                    .foregroundStyle(UNColor.textSecondary)

                miniAppSection
                systemSection
            }
            .padding(UNSpacing.xl)
        }
        .background(UNColor.bgPrimary)
        .navigationTitle("권한 관리")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadMiniAppPermissions() }
        .task { await refreshSystemStates() }
    }

    // MARK: - 미니앱 권한 섹션

    @ViewBuilder
    private var miniAppSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.md) {
            sectionTitle("미니앱 권한")

            if isLoadingApps {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(UNColor.interactive)
                    Spacer()
                }
                .padding(.vertical, UNSpacing.xxl)
            } else if groups.isEmpty {
                emptyAppsView
            } else {
                VStack(spacing: UNSpacing.md) {
                    ForEach(groups) { group in
                        appCard(group)
                    }
                }
            }
        }
    }

    private func appCard(_ group: MiniAppPermissionGroup) -> some View {
        let isExpanded = expanded.contains(group.miniAppId)
        let scopes = group.permissions.compactMap(\.permissionScope)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded { expanded.remove(group.miniAppId) }
                    else { expanded.insert(group.miniAppId) }
                }
            } label: {
                HStack(spacing: UNSpacing.lg) {
                    AppIconView(iconUrl: group.iconUrl, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.miniAppName)
                            .font(UNFont.bodyMedium(.semibold))
                            .foregroundStyle(UNColor.textPrimary)
                        Text(grantedSummary(group))
                            .font(UNFont.captionSmall())
                            .foregroundStyle(UNColor.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UNColor.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(UNSpacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.leading, UNSpacing.lg)
                VStack(spacing: UNSpacing.lg) {
                    ForEach(scopes, id: \.self) { scope in
                        scopeToggleRow(group: group, scope: scope)
                    }
                }
                .padding(UNSpacing.lg)
            }
        }
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    private func scopeToggleRow(group: MiniAppPermissionGroup, scope: PermissionScope) -> some View {
        HStack(spacing: UNSpacing.md) {
            Image(systemName: scope.iconName)
                .font(.system(size: 16))
                .foregroundStyle(UNColor.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(scope.title)
                    .font(UNFont.bodyMedium())
                    .foregroundStyle(UNColor.textPrimary)
                Text(scope.permissionDescription)
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: UNSpacing.sm)

            Toggle("", isOn: Binding(
                get: { currentGranted(group.miniAppId, scope) },
                set: { setGranted(group, scope, $0) }
            ))
            .labelsHidden()
            .tint(UNColor.interactive)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.miniAppName) \(scope.title) 권한")
        .accessibilityValue(currentGranted(group.miniAppId, scope) ? "허용" : "거부")
        .accessibilityHint(scope.permissionDescription)
    }

    private var emptyAppsView: some View {
        VStack(spacing: UNSpacing.md) {
            Image(systemName: loadFailed ? "exclamationmark.triangle" : "checkmark.shield")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(UNColor.textTertiary.opacity(0.6))
            Text(loadFailed ? "권한 정보를 불러오지 못했어요" : "아직 권한을 설정한 미니앱이 없어요")
                .font(UNFont.bodyMedium())
                .foregroundStyle(UNColor.textSecondary)
            Text(loadFailed ? "잠시 후 다시 시도해 주세요" : "미니앱에 처음 접속하면 권한 동의를 받아요")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UNSpacing.xxxl)
        .background(UNColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
        .unShadow(.subtle)
    }

    // MARK: - 기기 시스템 권한 섹션 (읽기 전용)

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: UNSpacing.md) {
            sectionTitle("기기 시스템 권한")

            Text("카메라·위치·알림은 미니앱이 기능을 사용할 때 iOS 가 별도로 묻습니다. 아래는 현재 상태예요.")
                .font(UNFont.captionLarge())
                .foregroundStyle(UNColor.textTertiary)

            VStack(spacing: 0) {
                ForEach(Array(systemItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().padding(.leading, 52) }
                    systemRow(item)
                }
            }
            .background(UNColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            .unShadow(.subtle)

            Button {
                openSystemSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("iOS 설정 열기")
                }
                .font(UNFont.bodyMedium(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, UNSpacing.lg)
                .background(UNColor.interactive)
                .clipShape(RoundedRectangle(cornerRadius: UNRadius.lg, style: .continuous))
            }
        }
    }

    private func systemRow(_ item: SystemItem) -> some View {
        HStack(spacing: UNSpacing.lg) {
            Image(systemName: item.icon)
                .font(.body)
                .foregroundStyle(UNColor.textSecondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(UNFont.bodyMedium())
                    .foregroundStyle(UNColor.textPrimary)
                Text(item.subtitle)
                    .font(UNFont.captionSmall())
                    .foregroundStyle(UNColor.textTertiary)
            }

            Spacer()

            Text(item.state.label)
                .font(UNFont.captionLarge(.semibold))
                .foregroundStyle(item.state.color)
        }
        .padding(.horizontal, UNSpacing.xl)
        .padding(.vertical, UNSpacing.lg)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(UNFont.headingSmall())
            .foregroundStyle(UNColor.textPrimary)
    }

    // MARK: - 미니앱 권한 로직

    private func loadMiniAppPermissions() async {
        isLoadingApps = true
        do {
            let result = try await MiniAppPermissionClient.liveValue.fetchAll()
            // 표시 가능한(해석되는) 스코프가 하나라도 있는 그룹만 노출.
            groups = result.filter { !$0.permissions.compactMap(\.permissionScope).isEmpty }
            loadFailed = false
        } catch {
            groups = []
            loadFailed = true
        }
        isLoadingApps = false
    }

    private func currentGranted(_ miniAppId: Int, _ scope: PermissionScope) -> Bool {
        groups.first { $0.miniAppId == miniAppId }?
            .permissions.first { $0.scope == scope.rawValue }?
            .granted ?? false
    }

    /// 토글 변경 — 낙관적 로컬 업데이트 + PermissionStore 반영(실행 중 세션 즉시 적용) + 백엔드 동기화.
    /// 실패 시 롤백.
    private func setGranted(_ group: MiniAppPermissionGroup, _ scope: PermissionScope, _ newValue: Bool) {
        UISelectionFeedbackGenerator().selectionChanged()
        // 롤백 대비 이전 값을 낙관적 업데이트 전에 캡처(빠른 더블탭 + 순서 뒤바뀐 실패에서도
        // 집행 진실원인 PermissionStore 가 stale 값으로 덮이지 않게).
        let prior = currentGranted(group.miniAppId, scope)
        applyLocal(miniAppId: group.miniAppId, scope: scope, granted: newValue)
        PermissionStore.shared.setDecisions(appId: group.miniAppId, [scope: newValue])

        Task {
            do {
                _ = try await MiniAppPermissionClient.liveValue.submit(group.miniAppId, [scope: newValue])
            } catch {
                applyLocal(miniAppId: group.miniAppId, scope: scope, granted: prior)
                PermissionStore.shared.setDecisions(appId: group.miniAppId, [scope: prior])
                print("[Permission] 권한 변경 동기화 실패 appId=\(group.miniAppId): \(error)")
            }
        }
    }

    private func applyLocal(miniAppId: Int, scope: PermissionScope, granted: Bool) {
        guard let gIdx = groups.firstIndex(where: { $0.miniAppId == miniAppId }) else { return }
        var perms = groups[gIdx].permissions
        guard let pIdx = perms.firstIndex(where: { $0.scope == scope.rawValue }) else { return }
        perms[pIdx] = PermissionItem(scope: scope.rawValue, hasDecision: true, granted: granted)
        let g = groups[gIdx]
        groups[gIdx] = MiniAppPermissionGroup(
            miniAppId: g.miniAppId, appId: g.appId,
            miniAppName: g.miniAppName, iconUrl: g.iconUrl, permissions: perms
        )
    }

    private func grantedSummary(_ group: MiniAppPermissionGroup) -> String {
        let resolved = group.permissions.filter { $0.permissionScope != nil }
        let grantedCount = resolved.filter(\.granted).count
        return "권한 \(resolved.count)개 중 \(grantedCount)개 허용"
    }

    // MARK: - 시스템 권한 상태

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func refreshSystemStates() async {
        let notification = await notificationState()
        let camera = mapAV(AVCaptureDevice.authorizationStatus(for: .video))
        let photo = mapPhoto(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        let location = mapLocation(CLLocationManager().authorizationStatus)

        let resolved: [String: PermissionState] = [
            "notification": notification,
            "camera": camera,
            "photo": photo,
            "location": location,
        ]
        systemItems = systemItems.map { item in
            var copy = item
            if let state = resolved[item.id] { copy.state = state }
            return copy
        }
    }

    private func notificationState() async -> PermissionState {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private func mapAV(_ status: AVAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private func mapPhoto(_ status: PHAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .granted
        case .limited: return .limited
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private func mapLocation(_ status: CLAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: return .granted
        case .denied, .restricted: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private static let initialSystemItems: [SystemItem] = [
        SystemItem(id: "notification", icon: "bell", title: "알림", subtitle: "푸시 알림 수신", state: .notDetermined),
        SystemItem(id: "camera", icon: "camera", title: "카메라", subtitle: "미니앱 카메라 사용", state: .notDetermined),
        SystemItem(id: "photo", icon: "photo", title: "사진", subtitle: "프로필 이미지·미니앱", state: .notDetermined),
        SystemItem(id: "location", icon: "location", title: "위치", subtitle: "미니앱 위치 기능", state: .notDetermined),
    ]
}

// MARK: - System Permission Models

extension PermissionSettingsView {
    enum PermissionState: Equatable {
        case granted, limited, denied, notDetermined

        var label: String {
            switch self {
            case .granted: "허용됨"
            case .limited: "일부 허용"
            case .denied: "거부됨"
            case .notDetermined: "미설정"
            }
        }

        var color: Color {
            switch self {
            case .granted: UNColor.success
            case .limited: UNColor.warning
            case .denied: UNColor.error
            case .notDetermined: UNColor.textTertiary
            }
        }
    }

    struct SystemItem: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        var state: PermissionState
    }
}
