import SwiftUI
import ComposableArchitecture

// MARK: - App Root View (Auth 분기)

struct AppRootView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        Group {
            if store.isLoggedIn {
                MainTabView(
                    homeStore: store.scope(state: \.home, action: \.home),
                    searchStore: store.scope(state: \.search, action: \.search)
                )
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                WelcomeView(
                    store: store.scope(state: \.auth, action: \.auth)
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: store.isLoggedIn)
        .onAppear { store.send(.onAppear) }
    }
}
