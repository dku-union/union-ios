import Foundation

// MARK: - PermissionScope (정본 7개, 닷-표기)

/// 미니앱이 요청할 수 있는 권한 스코프.
/// SDK(union.config.json) · 백엔드 PermissionScope · 대시보드와 동일한 계약(닷-표기).
enum PermissionScope: String, Codable, Sendable, CaseIterable, Hashable {
    case userProfile = "user.profile"
    case userEmail = "user.email"
    case userUniversity = "user.university"
    case deviceLocation = "device.location"
    case deviceCamera = "device.camera"
    case deviceStorage = "device.storage"
    case notification = "notification"
}

extension PermissionScope {
    /// 동의 얼럿 / 권한 관리에서 사용할 SF Symbol 이름.
    var iconName: String {
        switch self {
        case .userProfile: "person.crop.circle"
        case .userEmail: "envelope"
        case .userUniversity: "graduationcap"
        case .deviceLocation: "location"
        case .deviceCamera: "camera"
        case .deviceStorage: "internaldrive"
        case .notification: "bell"
        }
    }

    /// 사용자에게 보여줄 권한 이름.
    var title: String {
        switch self {
        case .userProfile: "프로필"
        case .userEmail: "이메일"
        case .userUniversity: "학교 정보"
        case .deviceLocation: "위치"
        case .deviceCamera: "카메라"
        case .deviceStorage: "저장소"
        case .notification: "알림"
        }
    }

    /// 권한 설명 한 줄.
    var permissionDescription: String {
        switch self {
        case .userProfile: "이름·프로필 이미지 등 기본 정보를 사용해요"
        case .userEmail: "이메일 주소를 사용해요"
        case .userUniversity: "소속 대학교 정보를 사용해요"
        case .deviceLocation: "현재 위치를 사용해요"
        case .deviceCamera: "QR 스캔 등 카메라를 사용해요"
        case .deviceStorage: "미니앱 전용 저장 공간을 사용해요"
        case .notification: "알림을 보내요"
        }
    }

    /// 실제 iOS 시스템 권한 다이얼로그를 유발하는 스코프인지(2계층 모델의 OS 권한 계층).
    /// true 인 스코프는 동의(앱-계층) 후 기능을 처음 사용할 때 네이티브 다이얼로그가 추가로 뜬다.
    var requiresSystemPermission: Bool {
        switch self {
        case .deviceLocation, .deviceCamera, .notification: true
        default: false
        }
    }
}

// MARK: - Wire DTOs (백엔드 응답 매핑)

/// 단일 스코프에 대한 사용자 상태. 백엔드 `PermissionItemDto` 와 매핑.
/// `scope` 는 forward-compat 을 위해 String 으로 수신하고 `permissionScope` 로 해석한다
/// (iOS 가 모르는 신규 스코프가 와도 디코딩이 깨지지 않음 → 호출부에서 nil 필터).
struct PermissionItem: Codable, Sendable, Hashable, Identifiable {
    let scope: String
    let hasDecision: Bool
    let granted: Bool

    var id: String { scope }
    var permissionScope: PermissionScope? { PermissionScope(rawValue: scope) }
}

/// 특정 미니앱의 권한 상태. 백엔드 `MiniAppPermissionStateDto` 와 매핑.
struct MiniAppPermissionState: Codable, Sendable, Equatable {
    let miniAppId: Int
    let appId: String?
    let permissions: [PermissionItem]
}

/// 권한 관리 화면용 — 미니앱 단위 그룹. 백엔드 `UserPermissionGroupDto` 와 매핑.
struct MiniAppPermissionGroup: Codable, Sendable, Equatable, Identifiable {
    let miniAppId: Int
    let appId: String?
    let miniAppName: String
    let iconUrl: String?
    let permissions: [PermissionItem]

    var id: Int { miniAppId }
}

// MARK: - 요청 모델

struct PermissionDecisionRequest: Codable, Sendable {
    let scope: String
    let granted: Bool
}

struct UpdatePermissionsRequest: Codable, Sendable {
    let decisions: [PermissionDecisionRequest]
}
