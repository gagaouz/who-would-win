import SwiftUI

@main
struct WhoWouldWinApp: App {

    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            KidsHomeView()
                .preferredColorScheme(.light)
                .onAppear {
                    // Wake the Railway backend NOW so a cold-start doesn't time
                    // out the first battle (which would drop to the generic
                    // offline template — bad, especially for custom creatures).
                    BattleService.shared.warmUp()

                    // Restore any existing entitlements so reinstalled users
                    // don't lose their purchases until they hit "Restore". AdMob
                    // is initialized only after this check and only for free users.
                    Task {
                        await StoreKitManager.shared.refreshEntitlements()
                        guard !AdManager.shared.userHasPaidForAdRemoval() else { return }
                        AdManager.configure()
                        AdManager.shared.preloadAll()
                    }

                    // Game Center — authenticate on launch
                    GameCenterManager.shared.authenticate()

                    // iCloud — restore any cloud-synced progress (e.g. after reinstall)
                    CloudSyncService.shared.restoreFromCloud()

                    // Reset per-session achievement counters
                    AchievementTracker.shared.resetSessionCount()

                    // Warm the sound-effect players so the first tap/clash/win
                    // plays with no latency.
                    SoundService.shared.prepare()

                    // First-party crash/hang reporting (MetricKit) so we're no
                    // longer blind to what breaks in the field.
                    CrashReportingService.shared.start()

                    // Re-arm the parent-enabled daily reminder (refreshes the
                    // rotating message; no-op if the parent never turned it on).
                    if UserSettings.shared.dailyReminderEnabled {
                        Task { await NotificationService.shared.setDailyReminder(true) }
                    }
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
