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

    // MARK: - Engagement / progression
    /// Per-animal win counts (Animal.id → wins). Drives "⭐ N wins" badges and
    /// the personal champions story that keeps deterministic replays meaningful.
    @Published var animalWins: [String: Int]  { didSet { ud.set(animalWins, forKey: "stat.animalWins") } }
    /// True once the kid has seen (or skipped) the first-run "watch me" battle.
    @Published var hasSeenFirstBattle: Bool   { didSet { ud.set(hasSeenFirstBattle, forKey: "onboard.seenFirstBattle") } }
    /// One free "streak freeze" so a single missed day doesn't wipe a long streak.
    @Published var streakFreezeAvailable: Bool { didSet { ud.set(streakFreezeAvailable, forKey: "stat.streakFreeze") } }
    /// Day-stamp (yyyy-ddd) the daily challenge was last completed.
    @Published var lastDailyChallengeDay: Int { didSet { ud.set(lastDailyChallengeDay, forKey: "daily.challengeDay") } }
    /// Day-stamp the daily mystery sticker was last claimed.
    @Published var lastMysteryStickerDay: Int { didSet { ud.set(lastMysteryStickerDay, forKey: "daily.mysteryDay") } }
    /// Prediction-accuracy tracking — how often the kid's cheered pick won.
    /// Drives the "you've called N of M right!" stat parents see as proof of
    /// learning, and the kid's running accuracy.
    @Published var predictionsTotal: Int   { didSet { ud.set(predictionsTotal, forKey: "stat.predTotal") } }
    @Published var predictionsCorrect: Int { didSet { ud.set(predictionsCorrect, forKey: "stat.predCorrect") } }

    /// Today as a stable yyyy*1000+dayOfYear integer (local time).
    static var todayStamp: Int {
        let c = Calendar.current
        let now = Date()
        return c.component(.year, from: now) * 1000 + (c.ordinality(of: .day, in: .year, for: now) ?? 0)
    }
    var dailyChallengeAvailable: Bool { lastDailyChallengeDay != Self.todayStamp }
    var mysteryStickerAvailable: Bool { lastMysteryStickerDay != Self.todayStamp }

    /// Record a win for an animal and return its new total.
    @discardableResult
    func recordWin(for id: String) -> Int {
        let n = (animalWins[id] ?? 0) + 1
        animalWins[id] = n
        return n
    }
    func wins(for id: String) -> Int { animalWins[id] ?? 0 }

    /// Record whether the kid's cheered prediction was correct (only call when
    /// they actually cheered for a side).
    func recordPrediction(correct: Bool) {
        predictionsTotal += 1
        if correct { predictionsCorrect += 1 }
    }
    /// 0–100 accuracy, or nil if they've never predicted.
    var predictionAccuracy: Int? {
        guard predictionsTotal > 0 else { return nil }
        return Int((Double(predictionsCorrect) / Double(predictionsTotal) * 100).rounded())
    }

    // MARK: - Tournament Unlock
    @Published var tournamentUnlocked: Bool          { didSet { ud.set(tournamentUnlocked,          forKey: "pref.tournamentUnlocked") } }
    @Published var hasSeenTournamentBanner: Bool     { didSet { ud.set(hasSeenTournamentBanner,     forKey: "pref.seenTournamentBanner") } }

    // MARK: - Parental Controls
    /// When false, all coin wagering in tournament mode is hidden — wager phases are
    /// auto-skipped and result screens omit coin amounts. Default true.
    @Published var wageringEnabled: Bool             { didSet { ud.set(wageringEnabled,             forKey: "parental.wageringEnabled") } }
    /// Parent-enabled daily "come back and play" local notification. Default OFF
    /// (opt-in only, set from the parent-gated Grown-Up Zone).
    @Published var dailyReminderEnabled: Bool        { didSet { ud.set(dailyReminderEnabled,        forKey: "parental.dailyReminder") } }

    // MARK: - Experiments
    /// Developer tools (the Narration Lab + on-device experiment toggle) are
    /// visible in DEBUG builds and in TestFlight, but NEVER in an App Store
    /// production build — so the experiment can't surface to real users.
    /// TestFlight is detected by its sandbox receipt (same check AdManager uses).
    static var showDevTools: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    /// Single source of truth for the on-device-narration flag key, read both
    /// here (persisted) and raw via UserDefaults inside the BattleService actor.
    static let onDeviceNarrationKey = "experiment.onDeviceNarration"
    /// When true (and iOS 26+ with Apple Intelligence available), quick/tournament
    /// battle narration is generated ON DEVICE via Apple's Foundation Models instead
    /// of the Railway+Claude backend — instant, free, offline. Default OFF; this is a
    /// cost/quality experiment, not yet the shipping narrator. The deterministic
    /// resolver still decides every winner.
    @Published var onDeviceNarrationEnabled: Bool    { didSet { ud.set(onDeviceNarrationEnabled,    forKey: Self.onDeviceNarrationKey) } }

    // MARK: - Purchases
    @Published var hasRemovedAds: Bool         { didSet { ud.set(hasRemovedAds,         forKey: "iap.noads") } }
    @Published var isSubscribed: Bool          { didSet { ud.set(isSubscribed,          forKey: "iap.sub") } }
    @Published var fantasyUnlocked: Bool       { didSet { ud.set(fantasyUnlocked,       forKey: "iap.fantasy") } }
    @Published var prehistoricUnlocked: Bool   { didSet { ud.set(prehistoricUnlocked,   forKey: "iap.prehistoric") } }
    @Published var mythicUnlocked: Bool        { didSet { ud.set(mythicUnlocked,        forKey: "iap.mythic") } }
    @Published var olympusUnlocked: Bool       { didSet { ud.set(olympusUnlocked,       forKey: "iap.olympus") } }
    @Published var meleeUnlocked: Bool         { didSet { ud.set(meleeUnlocked,         forKey: "iap.melee") } }
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
        dailyReminderEnabled       = ud.object(forKey: "parental.dailyReminder") as? Bool ?? false
        soundEnabled               = ud.object(forKey: "pref.sound")           as? Bool ?? true
        narrationEnabled           = ud.object(forKey: "pref.narration")       as? Bool ?? true
        hapticsEnabled             = ud.object(forKey: "pref.haptics")         as? Bool ?? true
        hasSeenVoiceQualityPrompt  = ud.object(forKey: "pref.voicePromptSeen") as? Bool ?? false
        isLightMode      = ud.object(forKey: "pref.lightMode")  as? Bool ?? false
        totalBattleCount = ud.integer(forKey: "stat.battles")
        animalWins            = (ud.dictionary(forKey: "stat.animalWins") as? [String: Int]) ?? [:]
        hasSeenFirstBattle    = ud.bool(forKey: "onboard.seenFirstBattle")
        streakFreezeAvailable = ud.object(forKey: "stat.streakFreeze") as? Bool ?? true   // start with one
        lastDailyChallengeDay = ud.integer(forKey: "daily.challengeDay")
        lastMysteryStickerDay = ud.integer(forKey: "daily.mysteryDay")
        predictionsTotal      = ud.integer(forKey: "stat.predTotal")
        predictionsCorrect    = ud.integer(forKey: "stat.predCorrect")
        hasRemovedAds        = ud.bool(forKey: "iap.noads")
        isSubscribed         = ud.bool(forKey: "iap.sub")
        fantasyUnlocked      = ud.bool(forKey: "iap.fantasy")
        prehistoricUnlocked  = ud.bool(forKey: "iap.prehistoric")
        mythicUnlocked       = ud.bool(forKey: "iap.mythic")
        olympusUnlocked      = ud.bool(forKey: "iap.olympus")
        meleeUnlocked        = ud.bool(forKey: "iap.melee")
        environmentsUnlocked = ud.bool(forKey: "iap.environments")
        tournamentUnlocked       = ud.bool(forKey: "pref.tournamentUnlocked")
        hasSeenTournamentBanner  = ud.bool(forKey: "pref.seenTournamentBanner")
        wageringEnabled          = ud.object(forKey: "parental.wageringEnabled") as? Bool ?? true
        onDeviceNarrationEnabled = ud.bool(forKey: Self.onDeviceNarrationKey)   // default false
        currentStreak  = ud.integer(forKey: "stat.streak")
        longestStreak  = ud.integer(forKey: "stat.longestStreak")
    }

    // MARK: - Helpers

    /// Streak lengths that pay a bonus, keeping the reward curve climbing past
    /// the day-7 plateau (combats the day-7→30 retention cliff).
    static let streakMilestones: Set<Int> = [14, 30, 60, 100, 200, 365]

    /// Call after every completed battle. Returns the streak-milestone bonus the
    /// caller should award (0 when no milestone was crossed). The bonus is NOT
    /// paid here so the caller can fold it into the single battle-coin award —
    /// otherwise a second, async `earn()` would race the result screen's
    /// coins-earned chip and the chip would under-report the total.
    @discardableResult
    func recordBattle() -> Int {
        totalBattleCount += 1
        let priorStreak = currentStreak
        updateStreak()
        // Reward crossing a long-streak milestone with bonus coins.
        var milestoneBonus = 0
        if currentStreak > priorStreak, Self.streakMilestones.contains(currentStreak) {
            milestoneBonus = currentStreak   // e.g. 30-day streak → 30 bonus coins
        }
        AchievementTracker.shared.checkStreakAchievements(streak: currentStreak)
        AchievementTracker.shared.checkPackAchievements()
        // Report to Game Center leaderboards
        GameCenterManager.shared.reportScore(.totalBattles, value: totalBattleCount)
        GameCenterManager.shared.reportScore(.longestStreak, value: longestStreak)
        CloudSyncService.shared.autoSync()
        return milestoneBonus
    }

    /// Completely erases ALL on-device progress, stats, collections, purchases-
    /// state and iCloud-synced copies. Backs the parent-gated "Erase all data"
    /// control (COPPA / App Store data-deletion expectation) AND the TestFlight
    /// reset. Note: real purchases can always be restored via "Restore".
    @MainActor
    func eraseAllData() {
        // Core stats + unlocks
        totalBattleCount        = 0
        currentStreak           = 0
        longestStreak           = 0
        fantasyUnlocked         = false
        prehistoricUnlocked     = false
        mythicUnlocked          = false
        olympusUnlocked         = false
        meleeUnlocked           = false
        environmentsUnlocked    = false
        hasRemovedAds           = false
        isSubscribed            = false
        tournamentUnlocked      = false
        hasSeenTournamentBanner = false
        // Engagement / onboarding state (previously left behind on reset)
        animalWins              = [:]
        hasSeenFirstBattle      = false
        streakFreezeAvailable   = true
        lastDailyChallengeDay   = 0
        lastMysteryStickerDay   = 0
        dailyReminderEnabled    = false
        predictionsTotal        = 0
        predictionsCorrect      = 0
        ud.removeObject(forKey: "stat.lastBattleDate")
        // The grown-up PIN and ad-frequency counter are part of "everything" —
        // a parent erasing for a handoff/resale expects a truly clean slate.
        ParentalPIN.clear()
        ud.removeObject(forKey: "ads.interstitialShownCount")

        // Other on-device stores — all inline (we're @MainActor) so everything
        // is reset BEFORE the method returns and the UI reports success.
        AchievementTracker.shared.eraseAll()
        CoinStore.shared.resetForTesting()
        StickerCollection.shared.eraseAll()
        NotificationService.shared.cancelAll()
        // Wipe iCloud LAST — after the local resets — so the freshly-reset local
        // values (and the cancelled debounce inside wipeCloud) leave nothing to
        // restore. wipeCloud() also cancels any pending upload.
        CloudSyncService.shared.wipeCloud()
    }

    /// Back-compat alias for the existing TestFlight reset call sites.
    @MainActor
    func resetAllProgressForTesting() { eraseAllData() }

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
                // Gap. If exactly ONE day was missed and a streak freeze is
                // available, spend it to save the streak instead of resetting —
                // forgiving streaks keep kids from feeling punished for one off day.
                let missedDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 99
                if missedDays == 2, streakFreezeAvailable {
                    streakFreezeAvailable = false
                    currentStreak += 1
                    if currentStreak > longestStreak { longestStreak = currentStreak }
                } else {
                    currentStreak = 1
                    streakFreezeAvailable = true   // refresh the freeze on a fresh start
                }
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
    /// The first 2 battles are always ad-free; after that an ad shows once every
    /// 3rd battle (the 3rd, 6th, 9th, …) — never back-to-back. Kept deliberately
    /// gentle for the Kids audience.
    var shouldShowAd: Bool {
        guard !hasRemovedAds         else { return false }
        // Premium families never see ads — checked directly (not just via the
        // hasRemovedAds flag set at purchase) so the promise holds even if the
        // entitlement flag write was missed on an older build.
        guard !isSubscribed          else { return false }
        guard totalBattleCount >= 3  else { return false }
        return totalBattleCount % 3 == 0
    }

    // MARK: - Fantasy Access

    /// Number of battles required to unlock each pack for free.
    /// Re-paced 2026-06 so the first pack (Dinos) feels reachable for a young
    /// kid — 100 battles was far enough that nobody hit it. Ramp now interleaves
    /// with Tournament (30) and Melee (50): Dinos 40 → Fantasy 100 → Mythic 200
    /// → Olympus 500. Packs are still buyable; this is the long-tail free reward.
    static let fantasyBattleThreshold    = 100
    static let prehistoricBattleThreshold = 40
    static let mythicBattleThreshold      = 200
    static let olympusBattleThreshold     = 500

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

    /// Olympus is always visible — players see the locked pack from day 1 so
    /// they know it exists and can work toward / buy it. (Previously gated
    /// behind unlocking the other three packs first, which meant new users
    /// never saw the gods even existed.)
    var isOlympusVisible: Bool { true }

    /// True if the user has access to the Olympus gods (IAP, Premium, or the battle milestone).
    var isOlympusUnlocked: Bool {
        olympusUnlocked || isSubscribed || totalBattleCount >= Self.olympusBattleThreshold
    }

    /// Whether the given built-in animal is currently playable (its pack is
    /// unlocked). Custom creatures and the always-free packs are always available.
    /// Used by king-of-the-hill "Next Challenger" to only queue real opponents.
    func isAvailable(_ animal: Animal) -> Bool {
        switch animal.category {
        case .prehistoric: return isPrehistoricUnlocked
        case .fantasy:     return isFantasyUnlocked
        case .mythic:      return isMythicUnlocked
        case .olympus:     return isOlympusUnlocked
        default:           return true   // all, land, sea, air, insect, pets, farm
        }
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

    // MARK: - Melee Access

    static let meleeBattleThreshold = 50

    var isMeleeUnlocked: Bool {
        meleeUnlocked || isSubscribed || totalBattleCount >= Self.meleeBattleThreshold
    }

    var meleeUnlockProgress: Double {
        guard !isMeleeUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.meleeBattleThreshold), 1.0)
    }

    // MARK: - Environment Access

    /// True if the user can access ALL environments (pack purchase or subscription).
    var hasAllEnvironments: Bool {
        environmentsUnlocked || isSubscribed
    }

    /// True if ads are removed — by the Remove-Ads IAP / Everything Bundle OR by
    /// an active Premium subscription. Read this instead of the raw hasRemovedAds
    /// bool so Premium subscribers correctly see no ads (Premium no longer writes
    /// the permanent hasRemovedAds bool).
    var adsRemoved: Bool {
        hasRemovedAds || isSubscribed
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
