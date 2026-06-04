import SwiftUI
import ComposableArchitecture

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    // TCA Stores
    let homeStore: StoreOf<HomeFeature>
    let searchStore: StoreOf<SearchFeature>
    let notificationsStore: StoreOf<NotificationsFeature>
    let onLogout: () -> Void

    init(
        homeStore: StoreOf<HomeFeature>,
        searchStore: StoreOf<SearchFeature>,
        notificationsStore: StoreOf<NotificationsFeature>,
        onLogout: @escaping () -> Void
    ) {
        self.homeStore = homeStore
        self.searchStore = searchStore
        self.notificationsStore = notificationsStore
        self.onLogout = onLogout

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = .white
        // 기본 그림자/헤어라인 제거 후, 1px 옅은 회색 라인으로 상단 구분선 교체.
        appearance.shadowColor = nil
        appearance.shadowImage = Self.tabBarTopLine(
            color: UIColor(UNColor.charcoal400).withAlphaComponent(0.5),
            height: 1
        )
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(UNColor.textTertiary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(UNColor.textTertiary)
        ]
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // 네비게이션 바: 흰 배경 + 하단 구분선/그림자 제거. (charcoal 툴바 화면은 .toolbarBackground 로 자체 override)
        // shadowColor 만으론 라인이 남을 수 있어 shadowImage 도 빈 이미지로 지정해 완전히 제거.
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = .white
        navAppearance.shadowColor = .clear
        navAppearance.shadowImage = UIImage()
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    /// 탭바 상단 구분선용 단색 라인 이미지. 가로로 늘어나며 height(pt) 만큼의 두께를 가진다.
    private static func tabBarTopLine(color: UIColor, height: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: height))
        }
        .withRenderingMode(.alwaysOriginal)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(store: homeStore)
                .tabItem {
                    Label(Tab.home.title, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            SearchView(store: searchStore)
                .tabItem {
                    Label(Tab.search.title, systemImage: Tab.search.icon)
                }
                .tag(Tab.search)

            NotificationsView(store: notificationsStore)
                .tabItem {
                    Label(Tab.notifications.title, systemImage: Tab.notifications.icon)
                }
                .tag(Tab.notifications)
                .badge(notificationsStore.unreadCount > 0 ? notificationsStore.unreadCount : 0)

            ProfileView(onLogout: onLogout)
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(UNColor.interactive)
        .onReceive(NotificationCenter.default.publisher(for: .unionDeeplinkReceived)) { _ in
            // 알림 탭/콜드런치로 들어온 deeplink → 알림 탭으로 전환.
            // 사용자가 인박스에서 한 번 더 탭하면 NotificationsFeature 가 미니앱으로 push.
            selectedTab = .notifications
        }
    }
}

// MARK: - Tab Definition

extension MainTabView {
    enum Tab: Hashable {
        case home, search, notifications, profile

        var title: String {
            switch self {
            case .home: "홈"
            case .search: "검색"
            case .notifications: "알림"
            case .profile: "마이"
            }
        }

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .search: "magnifyingglass"
            case .notifications: "bell.fill"
            case .profile: "person.fill"
            }
        }
    }
}
