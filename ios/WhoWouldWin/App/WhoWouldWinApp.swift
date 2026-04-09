import SwiftUI

@main
struct WhoWouldWinApp: App {

    @ObservedObject private var settings = UserSettings.shared

    init() {
        // Configure AdMob (sets COPPA/child-directed flags) before any ad is requested.
        AdManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(settings.isLightMode ? .light : .dark)
                .onAppear {
                    // Pre-load the first interstitial and rewarded ad so they're
                    // ready by the time the user finishes their first battle.
                    AdManager.shared.preloadAll()
                    // Restore any existing entitlements so reinstalled users
                    // don't lose their purchases until they hit "Restore".
                    Task { await StoreKitManager.shared.refreshEntitlements() }
                }
        }
    }
}
