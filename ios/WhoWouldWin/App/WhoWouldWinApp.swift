import SwiftUI

@main
struct WhoWouldWinApp: App {

    @ObservedObject private var settings: UserSettings
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppConfig.prepareTestRuntime()
        _settings = ObservedObject(wrappedValue: UserSettings.shared)
        #if DEBUG
        if AppConfig.isUITesting && AppConfig.isIsolatedTestBuild {
            if let screen = AppConfig.fixtureScreen {
                RetroUIFixtureHost.prepare(screen: screen)
            }
            UpgradeFixtureAudit.captureIfRequested()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootContent
                .preferredColorScheme(.light)
                .overlay(alignment: .bottomLeading) {
                    #if DEBUG
                    if AppConfig.isUITesting {
                        Text("TEST: \(AppConfig.fixtureScenario)")
                            .font(.system(size: 9, design: .monospaced))
                            .padding(3)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .accessibilityIdentifier("uitest.fixtureMode")
                            .allowsHitTesting(false)
                    }
                    #endif
                }
                .onAppear {
                    guard AppConfig.externalServicesEnabled else { return }
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
            if AppConfig.externalServicesEnabled && phase == .active && !GameCenterManager.shared.isAuthenticated {
                GameCenterManager.shared.authenticate()
            }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        #if DEBUG
        if AppConfig.fixtureScreen == "melee" {
            MeleeBattleView(teamA: [Animals.lion, Animals.gorilla, Animals.wolf, Animals.tiger],
                            teamB: [Animals.elephant, Animals.great_white_shark, Animals.bald_eagle, Animals.t_rex])
        } else if AppConfig.fixtureScreen == "custom" {
            MeleeBattleView(teamA: [customFixture("blue_lion", "Blue Lion"), customFixture("ice_dragon", "Ice Dragon")],
                            teamB: [customFixture("robot", "Robot"), customFixture("glimmerflux", "Glimmerflux")])
        } else if AppConfig.fixtureScreen == "solo" {
            KidsBattleView(fighter1: Animals.lion, fighter2: Animals.gorilla,
                           environment: .grassland, arenaEffectsEnabled: true)
        } else if let screen = AppConfig.fixtureScreen, RetroUIFixtureHost.supports(screen) {
            RetroUIFixtureHost(screen: screen)
        } else {
            KidsHomeView()
        }
        #else
        KidsHomeView()
        #endif
    }

    #if DEBUG
    private func customFixture(_ identifier: String, _ name: String) -> Animal {
        Animal(id: "custom_qa_\(identifier)", name: name, emoji: "🐾", category: .fantasy,
               pixelColor: "#4E7E45", size: 3, isCustom: true)
    }
    #endif
}
