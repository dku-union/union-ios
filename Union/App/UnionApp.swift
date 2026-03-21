import SwiftUI
import ComposableArchitecture

@main
struct UnionApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // TCA Stores — App-level creation
    let homeStore = Store(initialState: HomeFeature.State()) {
        HomeFeature()
    }
    let searchStore = Store(initialState: SearchFeature.State()) {
        SearchFeature()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(
                homeStore: homeStore,
                searchStore: searchStore
            )
        }
    }
}
