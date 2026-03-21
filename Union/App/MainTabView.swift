import SwiftUI
import ComposableArchitecture

// MARK: - Main Tab View

struct MainTabView: View {
    @State private var selectedTab: Tab = .home

    // TCA Stores
    let homeStore: StoreOf<HomeFeature>
    let searchStore: StoreOf<SearchFeature>

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

            RecentView()
                .tabItem {
                    Label(Tab.recent.title, systemImage: Tab.recent.icon)
                }
                .tag(Tab.recent)

            NotificationsView()
                .tabItem {
                    Label(Tab.notifications.title, systemImage: Tab.notifications.icon)
                }
                .tag(Tab.notifications)

            ProfileView()
                .tabItem {
                    Label(Tab.profile.title, systemImage: Tab.profile.icon)
                }
                .tag(Tab.profile)
        }
        .tint(UBColor.brand)
    }
}

// MARK: - Tab Definition

extension MainTabView {
    enum Tab: Hashable {
        case home, search, recent, notifications, profile

        var title: String {
            switch self {
            case .home: "홈"
            case .search: "검색"
            case .recent: "최근"
            case .notifications: "알림"
            case .profile: "마이"
            }
        }

        var icon: String {
            switch self {
            case .home: "house.fill"
            case .search: "magnifyingglass"
            case .recent: "clock.arrow.circlepath"
            case .notifications: "bell.fill"
            case .profile: "person.fill"
            }
        }
    }
}
