import Foundation
import ComposableArchitecture

// MARK: - Notification Client (TCA Dependency)

/// 알림 도메인의 모든 사용자측 API를 담당.
///
/// 백엔드 endpoints:
/// - `PUT /notifications/token` — APNs/FCM 토큰 등록 (upsert)
/// - `GET /notifications/inbox` — 인박스 (cursor 페이징)
/// - `POST /notifications/inbox/{id}/read` — 읽음 처리
/// - `POST /notifications/inbox/read-all` — 전부 읽음
/// - `GET /notifications/unread-count` — 미읽음 카운트
/// - `POST /api/v1/users/me/miniapps/{appId}/subscription` — 구독
/// - `PATCH /api/v1/users/me/miniapps/{appId}/subscription` — pushEnabled 토글
/// - `DELETE /api/v1/users/me/miniapps/{appId}/subscription` — 구독 해지
/// - `GET /api/v1/users/me/subscriptions` — 내 구독 목록
@DependencyClient
struct NotificationClient: Sendable {
    var registerDeviceToken: @Sendable (_ deviceId: String, _ token: String, _ appVersion: String?, _ osVersion: String?) async throws -> Void
    var fetchInbox: @Sendable (_ cursor: Int64?, _ limit: Int) async throws -> [NotificationInboxItem]
    var markRead: @Sendable (_ id: Int64) async throws -> Void
    var markAllRead: @Sendable () async throws -> Void
    var unreadCount: @Sendable () async throws -> Int
    var subscribe: @Sendable (_ appId: String) async throws -> Void
    var setPushEnabled: @Sendable (_ appId: String, _ enabled: Bool) async throws -> Void
    var unsubscribe: @Sendable (_ appId: String) async throws -> Void
    var fetchSubscriptions: @Sendable () async throws -> [SubscriptionItem]
}

// MARK: - DTOs

/// Spring `InboxResponseDto`와 1:1 매칭.
struct NotificationInboxItem: Codable, Sendable, Equatable, Identifiable {
    let id: Int64
    let campaignId: Int64
    let senderType: SenderType
    let category: NotificationCategory
    let title: String
    let body: String
    let imageUrl: String?
    let deeplinkType: DeeplinkType
    let targetAppId: String?
    let targetPath: String?
    let targetWebUrl: String?
    let targetInternalRoute: String?
    let read: Bool
    let readAt: Date?
    let createdAt: Date

    enum SenderType: String, Codable, Sendable, Equatable {
        case SYSTEM, MINIAPP, PUBLISHER_SYSTEM
    }

    enum NotificationCategory: String, Codable, Sendable, Equatable {
        case UPDATE, RECOMMENDATION, ANNOUNCEMENT
        case MINIAPP_GENERIC, PUBLISHER_BUILD, REVIEW_RESULT
    }

    enum DeeplinkType: String, Codable, Sendable, Equatable {
        case MINIAPP, WEB, INTERNAL, NONE
    }
}

struct SubscriptionItem: Codable, Sendable, Equatable, Identifiable {
    let id: Int64
    let miniAppId: Int64
    let appId: String?
    let miniAppName: String
    let iconUrl: String?
    let pushEnabled: Bool
    let subscribedAt: Date
}

private struct RegisterTokenRequest: Encodable {
    let deviceId: String
    let platform: String   // "IOS"
    let token: String
    let appVersion: String?
    let osVersion: String?
}

private struct UpdatePushEnabledRequest: Encodable {
    let pushEnabled: Bool
}

private struct UnreadCountResponse: Decodable {
    let count: Int
}

// MARK: - Live

extension NotificationClient: DependencyKey {
    static let liveValue: NotificationClient = {
        let apiClient = APIClient(baseURL: APIConfig.baseURL)
        let encoder = JSONEncoder()

        return NotificationClient(
            registerDeviceToken: { deviceId, token, appVersion, osVersion in
                let body = try encoder.encode(RegisterTokenRequest(
                    deviceId: deviceId,
                    platform: "IOS",
                    token: token,
                    appVersion: appVersion,
                    osVersion: osVersion
                ))
                try await apiClient.send(.registerFcmToken(body: body))
            },
            fetchInbox: { cursor, limit in
                let items: [NotificationInboxItem] = try await apiClient.request(
                    .notificationInbox(cursor: cursor, limit: limit)
                )
                return items
            },
            markRead: { id in
                try await apiClient.send(.markNotificationRead(id: id))
            },
            markAllRead: {
                try await apiClient.send(.markAllNotificationsRead)
            },
            unreadCount: {
                let resp: UnreadCountResponse = try await apiClient.request(.notificationUnreadCount)
                return resp.count
            },
            subscribe: { appId in
                try await apiClient.send(.subscribeMiniApp(appId: appId))
            },
            setPushEnabled: { appId, enabled in
                let body = try encoder.encode(UpdatePushEnabledRequest(pushEnabled: enabled))
                try await apiClient.send(.updateMiniAppSubscription(appId: appId, body: body))
            },
            unsubscribe: { appId in
                try await apiClient.send(.unsubscribeMiniApp(appId: appId))
            },
            fetchSubscriptions: {
                let subs: [SubscriptionItem] = try await apiClient.request(.mySubscriptions)
                return subs
            }
        )
    }()
}

// MARK: - Test / Preview

extension NotificationClient: TestDependencyKey {
    static let testValue = NotificationClient()

    static let previewValue = NotificationClient(
        registerDeviceToken: { _, _, _, _ in },
        fetchInbox: { _, _ in [] },
        markRead: { _ in },
        markAllRead: {},
        unreadCount: { 0 },
        subscribe: { _ in },
        setPushEnabled: { _, _ in },
        unsubscribe: { _ in },
        fetchSubscriptions: { [] }
    )
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}
