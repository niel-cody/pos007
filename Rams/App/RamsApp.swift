import SwiftUI

@main
struct RamsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}
