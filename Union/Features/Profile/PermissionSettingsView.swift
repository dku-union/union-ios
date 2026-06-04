import SwiftUI
import UserNotifications
import AVFoundation
import Photos
import CoreLocation

// MARK: - Permission Settings View

/// 권한 관리 — 앱/미니앱이 사용하는 시스템 권한의 현재 상태를 보여주고,
/// iOS 설정 앱으로 이동해 변경할 수 있게 한다. (권한 부여/철회는 iOS 설정에서만 가능)
struct PermissionSettingsView: View {

    private enum PermissionState: Equatable {
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

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
        var state: PermissionState
    }

    @State private var items: [Item] = PermissionSettingsView.initialItems

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: UNSpacing.xxl) {
                Text("앱과 미니앱이 사용하는 권한의 현재 상태예요. 권한 변경은 iOS 설정에서 할 수 있어요.")
                    .font(UNFont.bodySmall())
                    .foregroundStyle(UNColor.textSecondary)

                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().padding(.leading, 52) }
                        permissionRow(item)
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

                Text("카메라·위치·사진 등은 미니앱이 기능을 요청할 때 사용돼요. 거부해도 앱 이용에는 문제가 없습니다.")
                    .font(UNFont.captionLarge())
                    .foregroundStyle(UNColor.textTertiary)
            }
            .padding(UNSpacing.xl)
        }
        .background(UNColor.bgPrimary)
        .navigationTitle("권한 관리")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshStates() }
    }

    private func permissionRow(_ item: Item) -> some View {
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

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Status loading

    private static let initialItems: [Item] = [
        Item(id: "notification", icon: "bell", title: "알림", subtitle: "푸시 알림 수신", state: .notDetermined),
        Item(id: "camera", icon: "camera", title: "카메라", subtitle: "미니앱 카메라 사용", state: .notDetermined),
        Item(id: "photo", icon: "photo", title: "사진", subtitle: "프로필 이미지·미니앱", state: .notDetermined),
        Item(id: "location", icon: "location", title: "위치", subtitle: "미니앱 위치 기능", state: .notDetermined),
    ]

    private func refreshStates() async {
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
        items = items.map { item in
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
}
