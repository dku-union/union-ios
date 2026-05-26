import Foundation
import ComposableArchitecture

// MARK: - Notifications Feature (TCA Reducer)

@Reducer
struct NotificationsFeature {

    @ObservableState
    struct State: Equatable {
        var items: [NotificationInboxItem] = []
        var isLoading = false
        var isLoadingMore = false
        var hasMore = true
        var oldestCursor: Int64?
        var unreadCount: Int = 0
        var errorMessage: String?
        var didLoad = false
    }

    enum Action {
        case onAppear
        case refresh
        case loadMore
        case itemsLoaded([NotificationInboxItem], appending: Bool)
        case unreadCountLoaded(Int)
        case loadFailed(String)
        case itemTapped(NotificationInboxItem)
        case markAllReadTapped
        case markRead(id: Int64)
        case markedReadLocally(id: Int64)
        case allMarkedReadLocally
    }

    private enum CancelID { case load }

    @Dependency(\.notificationClient) var notificationClient

    private static let pageSize: Int = 20

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.didLoad else { return .none }
                state.didLoad = true
                return .send(.refresh)

            case .refresh:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        async let inbox = notificationClient.fetchInbox(nil, Self.pageSize)
                        async let count = notificationClient.unreadCount()
                        let (items, unread) = try await (inbox, count)
                        await send(.itemsLoaded(items, appending: false))
                        await send(.unreadCountLoaded(unread))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.load, cancelInFlight: true)

            case .loadMore:
                guard state.hasMore, !state.isLoadingMore, let cursor = state.oldestCursor else {
                    return .none
                }
                state.isLoadingMore = true
                return .run { send in
                    do {
                        let items = try await notificationClient.fetchInbox(cursor, Self.pageSize)
                        await send(.itemsLoaded(items, appending: true))
                    } catch {
                        await send(.loadFailed(error.localizedDescription))
                    }
                }

            case let .itemsLoaded(items, appending):
                state.isLoading = false
                state.isLoadingMore = false
                if appending {
                    state.items.append(contentsOf: items)
                } else {
                    state.items = items
                }
                state.hasMore = items.count == Self.pageSize
                state.oldestCursor = state.items.last?.id
                return .none

            case let .unreadCountLoaded(count):
                state.unreadCount = count
                return .none

            case let .loadFailed(message):
                state.isLoading = false
                state.isLoadingMore = false
                state.errorMessage = message
                return .none

            case let .itemTapped(item):
                // 1) 로컬에서 즉시 읽음 표시 (낙관적 UI)
                let id = item.id
                let wasUnread = !item.read
                if wasUnread {
                    return .merge(
                        .send(.markedReadLocally(id: id)),
                        .send(.markRead(id: id))
                    )
                }
                return .none

            case let .markRead(id):
                return .run { _ in
                    try? await notificationClient.markRead(id)
                }

            case let .markedReadLocally(id):
                if let idx = state.items.firstIndex(where: { $0.id == id }) {
                    let item = state.items[idx]
                    if !item.read {
                        state.items[idx] = item.markedRead()
                        state.unreadCount = max(0, state.unreadCount - 1)
                    }
                }
                return .none

            case .markAllReadTapped:
                return .merge(
                    .send(.allMarkedReadLocally),
                    .run { _ in try? await notificationClient.markAllRead() }
                )

            case .allMarkedReadLocally:
                state.items = state.items.map { $0.read ? $0 : $0.markedRead() }
                state.unreadCount = 0
                return .none
            }
        }
    }
}

// MARK: - Helpers

private extension NotificationInboxItem {
    func markedRead() -> NotificationInboxItem {
        NotificationInboxItem(
            id: id,
            campaignId: campaignId,
            senderType: senderType,
            category: category,
            title: title,
            body: body,
            imageUrl: imageUrl,
            deeplinkType: deeplinkType,
            targetAppId: targetAppId,
            targetPath: targetPath,
            targetWebUrl: targetWebUrl,
            targetInternalRoute: targetInternalRoute,
            read: true,
            readAt: Date(),
            createdAt: createdAt
        )
    }
}
