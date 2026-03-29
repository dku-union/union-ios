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
        .tint(UNColor.brand)
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
