import SwiftUI
import ComposableArchitecture

// MARK: - App Root View (Auth/Role 분기)

struct AppRootView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isLoggedIn {
                if store.isPublisher {
                    // 퍼블리셔(또는 admin)는 자기 앱 테스트 화면만 노출.
                    // 일반 사용자용 탭(홈/검색/알림/마이)은 보이지 않는다.
                    PublisherView(
                        store: store.scope(state: \.publisher, action: \.publisher)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    MainTabView(
                        homeStore: store.scope(state: \.home, action: \.home),
                        searchStore: store.scope(state: \.search, action: \.search)
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            } else {
                WelcomeView(
                    store: store.scope(state: \.auth, action: \.auth)
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.isLoggedIn)
        .animation(.easeInOut(duration: 0.3), value: store.isPublisher)
        .onAppear { store.send(.onAppear) }
    }
}
