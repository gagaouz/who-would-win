import SwiftUI

@main
struct WhoWouldWinApp: App {

    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.scenePhase) private var scenePhase

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

                    // Game Center — authenticate on launch
                    GameCenterManager.shared.authenticate()

                    // iCloud — restore any cloud-synced progress (e.g. after reinstall)
                    CloudSyncService.shared.restoreFromCloud()

                    // Reset per-session achievement counters
                    AchievementTracker.shared.resetSessionCount()
                }
        }
        .onChange(of: scenePhase) { phase in
            // If the user went to iOS Settings to sign into Game Center and
            // came back, re-check auth so leaderboards/achievements open cleanly.
            if phase == .active && !GameCenterManager.shared.isAuthenticated {
                GameCenterManager.shared.authenticate()
            }
        }
    }
}
