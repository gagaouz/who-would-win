import Foundation
import Combine

/// Central store for all user preferences. Persists to UserDefaults.
/// Observe via `@ObservedObject var settings = UserSettings.shared`.
final class UserSettings: ObservableObject {
    static let shared = UserSettings()
    private let ud = UserDefaults.standard

    // MARK: - Sound & Vibration
    @Published var soundEnabled: Bool     { didSet { ud.set(soundEnabled,     forKey: "pref.sound") } }
    @Published var narrationEnabled: Bool { didSet { ud.set(narrationEnabled, forKey: "pref.narration") } }
    @Published var hapticsEnabled: Bool   { didSet { ud.set(hapticsEnabled,   forKey: "pref.haptics") } }

    // MARK: - Battle Tracking (for ad gating)
    @Published var totalBattleCount: Int  { didSet { ud.set(totalBattleCount, forKey: "stat.battles") } }

    // MARK: - Purchases
    @Published var hasRemovedAds: Bool    { didSet { ud.set(hasRemovedAds,    forKey: "iap.noads") } }
    @Published var isSubscribed: Bool     { didSet { ud.set(isSubscribed,     forKey: "iap.sub") } }
    @Published var fantasyUnlocked: Bool  { didSet { ud.set(fantasyUnlocked,  forKey: "iap.fantasy") } }

    private init() {
        soundEnabled     = ud.object(forKey: "pref.sound")      as? Bool ?? true
        narrationEnabled = ud.object(forKey: "pref.narration")  as? Bool ?? true
        hapticsEnabled   = ud.object(forKey: "pref.haptics")    as? Bool ?? true
        totalBattleCount = ud.integer(forKey: "stat.battles")
        hasRemovedAds    = ud.bool(forKey: "iap.noads")
        isSubscribed     = ud.bool(forKey: "iap.sub")
        fantasyUnlocked  = ud.bool(forKey: "iap.fantasy")
    }

    // MARK: - Helpers

    /// Call after every completed battle.
    func recordBattle() {
        totalBattleCount += 1
    }

    /// Returns true when an interstitial ad should be shown.
    /// First 5 battles are always ad-free; then every 3rd battle.
    var shouldShowAd: Bool {
        guard !hasRemovedAds         else { return false }
        guard totalBattleCount >= 5  else { return false }
        return totalBattleCount % 3 == 0
    }

    // MARK: - Fantasy Access

    /// Number of battles required to unlock fantasy for free.
    static let fantasyBattleThreshold = 50

    /// True if the user has access to fantasy creatures via IAP, subscription, or free milestone.
    var isFantasyUnlocked: Bool {
        fantasyUnlocked || isSubscribed || totalBattleCount >= Self.fantasyBattleThreshold
    }

    /// Progress toward the free fantasy unlock (0.0 – 1.0).
    var fantasyUnlockProgress: Double {
        guard !isFantasyUnlocked else { return 1.0 }
        return min(Double(totalBattleCount) / Double(Self.fantasyBattleThreshold), 1.0)
    }

    /// True the very first time the battle threshold is crossed (used to trigger celebration).
    var justUnlockedFantasy: Bool {
        !fantasyUnlocked && !isSubscribed &&
        totalBattleCount == Self.fantasyBattleThreshold
    }
}
