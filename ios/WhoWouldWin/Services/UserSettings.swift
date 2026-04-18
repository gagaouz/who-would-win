import Foundation
import Combine

/// Central store for all user preferences. Persists to UserDefaults.
/// Observe via `@ObservedObject var settings = UserSettings.shared`.
final class UserSettings: ObservableObject {
    static let shared = UserSettings()
    private let ud = UserDefaults.standard

    // MARK: - Sound & Vibration
    @Published var soundEnabled: Bool               { didSet { ud.set(soundEnabled,               forKey: "pref.sound") } }
    @Published var narrationEnabled: Bool           { didSet { ud.set(narrationEnabled,           forKey: "pref.narration") } }
    @Published var hapticsEnabled: Bool             { didSet { ud.set(hapticsEnabled,             forKey: "pref.haptics") } }
    @Published var hasSeenVoiceQualityPrompt: Bool  { didSet { ud.set(hasSeenVoiceQualityPrompt,  forKey: "pref.voicePromptSeen") } }

    // MARK: - Appearance
    @Published var isLightMode: Bool      { didSet { ud.set(isLightMode,      forKey: "pref.lightMode") } }

    // MARK: - Battle Tracking (for ad gating)
    @Published var totalBattleCount: Int  { didSet { ud.set(totalBattleCount, forKey: "stat.battles") } }

    // MARK: - Tournament Unlock
    @Published var tournamentUnlocked: Bool          { didSet { ud.set(tournamentUnlocked,          forKey: "pref.tournamentUnlocked") } }
    @Published var hasSeenTournamentBanner: Bool     { didSet { ud.set(hasSeenTournamentBanner,     forKey: "pref.seenTournamentBanner") } }

    // MARK: - Purchases
    @Published var hasRemovedAds: Bool         { didSet { ud.set(hasRemovedAds,         forKey: "iap.noads") } }
    @Published var isSubscribed: Bool          { didSet { ud.set(isSubscribed,          forKey: "iap.sub") } }
    @Published var fantasyUnlocked: Bool       { didSet { ud.set(fantasyUnlocked,       forKey: "iap.fantasy") } }
    @Published var prehistoricUnlocked: Bool   { didSet { ud.set(prehistoricUnlocked,   forKey: "iap.prehistoric") } }
    @Published var mythicUnlocked: Bool        { didSet { ud.set(mythicUnlocked,        forKey: "iap.mythic") } }
    @Published var olympusUnlocked: Bool       { didSet { ud.set(olympusUnlocked,       forKey: "iap.olympus") } }
    @Published var environmentsUnlocked: Bool  { didSet { ud.set(environmentsUnlocked,  forKey: "iap.environments") } }

    // MARK: - Streak Tracking
    @Published var currentStreak: Int  { didSet { ud.set(currentStreak,  forKey: "stat.streak") } }
    @Published var longestStreak: Int  { didSet { ud.set(longestStreak,  forKey: "stat.longestStreak") } }

    private var lastBattleDateInterval: Double {
        get { ud.double(forKey: "stat.lastBattleDate") }
        set { ud.set(newValue, forKey: "stat.lastBattleDate") }
    }
    private var lastBattleDate: Date? {
        let t = lastBattleDateInterval
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    private init() {
        soundEnabled               = ud.object(forKey: "pref.sound")           as? Bool ?? true
        narrationEnabled           = ud.object(forKey: "pref.narration")       as? Bool ?? true
        hapticsEnabled             = ud.object(forKey: "pref.haptics")         as? Bool ?? true
        hasSeenVoiceQualityPrompt  = ud.object(forKey: "pref.voicePromptSeen") as? Bool ?? false
        isLightMode      = ud.object(forKey: "pref.lightMode")  as? Bool ?? false
        totalBattleCount = ud.integer(forKey: "stat.battles")
        hasRemovedAds        = ud.bool(forKey: "iap.noads")
        isSubscribed         = ud.bool(forKey: "iap.sub")
        fantasyUnlocked      = ud.bool(forKey: "iap.fantasy")
        prehistoricUnlocked  = ud.bool(forKey: "iap.prehistoric")
        mythicUnlocked       = ud.bool(forKey: "iap.mythic")
        olympusUnlocked      = ud.bool(forKey: "iap.olympus")
        environmentsUnlocked = ud.bool(forKey: "iap.environments")
        tournamentUnlocked       = ud.bool(forKey: "pref.tournamentUnlocked")
        hasSeenTournamentBanner  = ud.bool(forKey: "pref.seenTournamentBanner")
        currentStreak  = ud.integer(forKey: "stat.streak")
        longestStreak  = ud.integer(forKey: "stat.longestStreak")
    }

    // MARK: - Helpers

    /// Call after every completed battle.
    func recordBattle() {
        totalBattleCount += 1
        updateStreak()
        AchievementTracker.shared.checkStreakAchievements(streak: currentStreak)
        AchievementTracker.shared.checkPackAchievements()
        // Report to Game Center leaderboards
        GameCenterManager.shared.reportScore(.totalBattles, value: totalBattleCount)
        GameCenterManager.shared.reportScore(.longestStreak, value: longestStreak)
        CloudSyncService.shared.autoSync()
    }

    /// Wipes all progress and purchases — TestFlight testing only.
    func resetAllProgressForTesting() {
        totalBattleCount        = 0
        currentStreak           = 0
        longestStreak           = 0
        fantasyUnlocked         = false
        prehistoricUnlocked     = false
        mythicUnlocked          = false
        olympusUnlocked         = false
        hasRemovedAds           = false
        isSubscribed            = false
        tournamentUnlocked      = false
        hasSeenTournamentBanner = false
        ud.removeObject(forKey: "stat.lastBattleDate")
        Task { @MainActor in CoinStore.shared.resetForTesting() }
    }

    private func updateStreak() {
        let now = Date()
        let calendar = Calendar.current

        if let last = lastBattleDate {
            if calendar.isDateInToday(last) {
                // Already battled today — streak unchanged
            } else if calendar.isDateInYesterday(last) {
                // Consecutive day — extend streak
                currentStreak += 1
                if currentStreak > longestStreak { longestStreak = currentStreak }
                lastBattleDateInterval = now.timeIntervalSince1970
            } else {
                // Gap — reset
                currentStreak = 1
                lastBattleDateInterval = now.timeIntervalSince1970
            }
        } else {
            // First battle ever
            currentStreak = 1
            longestStreak = max(longestStreak, 1)
            lastBattleDateInterval = now.timeIntervalSince1970
        }
    }

    /// Returns true when an interstitial ad should be shown.
    /// First 5 battles are always ad-free; then every 3rd battle.
    var shouldShowAd: Bool {
        guard !hasRemovedAds         else { return false }
        guard totalBattleCount >= 3  else { return false }
        return totalBattleCount % 2 == 0
    }

    // MARK: - Fantasy Access

    /// Number of battles required to unlock each pack for free.
    static let fantasyBattleThreshold    = 250
    static let prehistoricBattleThreshold = 100
    static let mythicBattleThreshold      = 500
    static let olympusBattleThreshold     = 10_000

    /// True if the user has access to fantasy creatures via IAP, subscription, or free milestone.
    var isFantasyUnlocked: Bool {
        fantasyUnlocked || isSubscribed || totalBattleCount >= Self.fantasyBattleThreshold
    }

    /// True if the user has access to prehistoric creatures via IAP, subscription, or free milestone.
    var isPrehistoricUnlocked: Bool {
        prehistoricUnlocked || isSubscribed || totalBattleCount >= Self.prehistoricBattleThreshold
    }

    /// True if the user has access to mythic creatures via IAP, subscription, or free milestone.
    var isMythicUnlocked: Bool {
        mythicUnlocked || isSubscribed || totalBattleCount >= Self.mythicBattleThreshold
    }

    /// True once all three packs are unlocked — reveals the Gods pack as available.
    var isOlympusVisible: Bool {
        isFantasyUnlocked && isPrehistoricUnlocked && isMythicUnlocked
    }

    /// True if the user has access to the Olympus gods (IAP or 10,000 battles).
    var isOlympusUnlocked: Bool {
        olympusUnlocked || totalBattleCount >= Self.olympusBattleThreshold
    }

    /// Progress toward the free fantasy unlock (0.0 – 1.0).
    var fantasyUnlockProgress: Double {
        guard !isFantasyUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.fantasyBattleThreshold), 1.0)
    }

    var prehistoricUnlockProgress: Double {
        guard !isPrehistoricUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.prehistoricBattleThreshold), 1.0)
    }

    var mythicUnlockProgress: Double {
        guard !isMythicUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.mythicBattleThreshold), 1.0)
    }

    var olympusUnlockProgress: Double {
        guard !isOlympusUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.olympusBattleThreshold), 1.0)
    }

    /// True the very first time each battle threshold is crossed (used to trigger celebrations).
    var justUnlockedFantasy: Bool {
        !fantasyUnlocked && !isSubscribed && totalBattleCount == Self.fantasyBattleThreshold
    }
    var justUnlockedPrehistoric: Bool {
        !prehistoricUnlocked && !isSubscribed && totalBattleCount == Self.prehistoricBattleThreshold
    }
    var justUnlockedMythic: Bool {
        !mythicUnlocked && !isSubscribed && totalBattleCount == Self.mythicBattleThreshold
    }
    var justUnlockedOlympus: Bool {
        !olympusUnlocked && totalBattleCount == Self.olympusBattleThreshold
    }

    // MARK: - Tournament Access

    /// Battles required to unlock Tournament Mode for free.
    static let tournamentBattleThreshold = 30

    /// True if Tournament Mode is currently usable.
    var isTournamentUnlocked: Bool {
        tournamentUnlocked || isSubscribed || totalBattleCount >= Self.tournamentBattleThreshold
    }

    /// Progress toward the free tournament unlock (0.0 – 1.0).
    var tournamentUnlockProgress: Double {
        guard !isTournamentUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.tournamentBattleThreshold), 1.0)
    }

    /// True the very first time the threshold is crossed (used to trigger celebration).
    var justUnlockedTournament: Bool {
        !tournamentUnlocked && !isSubscribed && totalBattleCount == Self.tournamentBattleThreshold
    }

    // MARK: - Environment Access

    /// True if the user can access ALL environments (pack purchase or subscription).
    var hasAllEnvironments: Bool {
        environmentsUnlocked || isSubscribed
    }

    /// True if a specific environment is currently usable.
    func isEnvironmentUnlocked(_ env: BattleEnvironment) -> Bool {
        switch env.tier {
        case .free:    return true
        case .earned:  return hasAllEnvironments || (env.battleThreshold.map { totalBattleCount >= $0 } ?? false)
        case .premium: return hasAllEnvironments
        }
    }
}
