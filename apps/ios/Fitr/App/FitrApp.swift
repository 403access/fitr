import SwiftUI

@main
struct FitrApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(store.settings)
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
        }
    }
}
