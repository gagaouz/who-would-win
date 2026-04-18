import Foundation
import SwiftUI

@MainActor
final class CoinStore: ObservableObject {
    static let shared = CoinStore()
    private let ud = UserDefaults.standard

    @Published private(set) var balance: Int = 0
    @Published var earnAnimationAmount: Int = 0
    @Published var showEarnAnimation: Bool = false

    // Earn rates
    let coinsPerBattle    = 10
    let coinsPerBattleSub = 20
    let dailyFirstBattleBonus = 25
    let coinsPerAd        = 75
    let maxDailyAds       = 8

    // Pack costs — calibrated to ~2 weeks casual play for the cheapest pack
    let prehistoricCost    =   300
    let fantasyCost        =   800
    let mythicCost         = 1_500
    let olympusCost        = 5_000
    let customCreatureCost =   150

    // Tournament costs and floors
    let tournamentBracketRerollCost     = 50
    let tournamentCustomCreatureCost    = 25   // charged once at bracket commit
    let tournamentMatchupWagerFloor     = 10
    let tournamentGrandChampionFloor    = 50
    let tournamentMatchupWagerMaxPct    = 0.10 // 10% of current balance
    let tournamentGrandChampionMaxPct   = 0.50 // 50% of balance at placement
    let tournamentSeedAmount            = 200  // one-time top-up on tournament unlock
    let tournamentDailyFreeLimit        = 2    // free tournaments per calendar day
    let tournamentExtraEntryCost        = 500  // coin cost for each tournament past the daily free limit

    // MARK: - Progress toward next pack

    struct PackProgress {
        let name: String
        let emoji: String
        let cost: Int
    }

    /// The cheapest pack the user hasn't unlocked yet, or nil if all unlocked.
    var nextPack: PackProgress? {
        let s = UserSettings.shared
        if !s.isPrehistoricUnlocked { return PackProgress(name: "Prehistoric", emoji: "🦕", cost: prehistoricCost) }
        if !s.isFantasyUnlocked     { return PackProgress(name: "Fantasy",     emoji: "🧙", cost: fantasyCost)    }
        if !s.isMythicUnlocked      { return PackProgress(name: "Mythic",      emoji: "🔱", cost: mythicCost)     }
        if !s.isOlympusUnlocked     { return PackProgress(name: "Gods",        emoji: "⚡", cost: olympusCost)    }
        return nil
    }

    /// 0.0–1.0 progress toward nextPack based on current balance.
    var nextPackProgress: Double {
        guard let pack = nextPack else { return 1.0 }
        return min(Double(balance) / Double(pack.cost), 1.0)
    }

    private init() {
        balance = ud.integer(forKey: "coin.balance")
        if !ud.bool(forKey: "coin.welcomed") {
            balance = 50
            ud.set(50, forKey: "coin.balance")
            ud.set(true, forKey: "coin.welcomed")
        }
    }

    var formattedBalance: String {
        if balance >= 1_000 {
            let k = Double(balance) / 1_000
            if k == Double(Int(k)) { return "\(Int(k))k" }
            return String(format: "%.1fk", k)
        }
        return "\(balance)"
    }

    // Daily ad tracking
    var dailyAdsWatched: Int {
        let last = ud.object(forKey: "coin.lastAdDate") as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(last) { return 0 }
        return ud.integer(forKey: "coin.dailyAdCount")
    }
    var canWatchAdForCoins: Bool { dailyAdsWatched < maxDailyAds }
    var adsRemainingToday: Int { max(0, maxDailyAds - dailyAdsWatched) }

    var isFirstBattleToday: Bool {
        let last = ud.object(forKey: "coin.lastBattleDate") as? Date ?? .distantPast
        return !Calendar.current.isDateInToday(last)
    }

    // Streak bonus tiers
    let streakBonus3Days  = 10   // +10 coins/battle at 3+ day streak
    let streakBonus7Days  = 20   // +20 coins/battle at 7+ day streak

    func earnBattleCoins() {
        let settings = UserSettings.shared
        let base = settings.isSubscribed ? coinsPerBattleSub : coinsPerBattle
        var total = base
        if isFirstBattleToday {
            total += dailyFirstBattleBonus
            ud.set(Date(), forKey: "coin.lastBattleDate")
        }
        // Streak bonus
        if settings.currentStreak >= 7 {
            total += streakBonus7Days
        } else if settings.currentStreak >= 3 {
            total += streakBonus3Days
        }
        earn(total)
    }

    /// Awards 50 bonus coins for the user's first-ever custom creature battle.
    /// Returns `true` if the bonus was actually awarded on this call (so the
    /// caller can show a one-time celebration banner).
    @discardableResult
    func earnFirstCustomBonus() -> Bool {
        guard !ud.bool(forKey: "coin.firstCustomAwarded") else { return false }
        ud.set(true, forKey: "coin.firstCustomAwarded")
        earn(50)
        return true
    }

    /// One-time top-up the moment Tournament Mode unlocks, so first-time players
    /// always have enough coins to actually wager. If the player already has more
    /// than the seed amount, this is a no-op (no coins added). Idempotent.
    func awardTournamentSeedIfNeeded() {
        guard !ud.bool(forKey: "coin.tournamentSeedAwarded") else { return }
        ud.set(true, forKey: "coin.tournamentSeedAwarded")
        let deficit = tournamentSeedAmount - balance
        if deficit > 0 {
            earn(deficit)
        }
    }

    /// Awards coins for an in-app purchase. Unlike ad rewards this is not
    /// subject to a daily cap — the player paid real money.
    func awardCoinPurchase(_ amount: Int) {
        earn(amount)
    }

    func recordAdWatched() {
        let current = dailyAdsWatched
        ud.set(current + 1, forKey: "coin.dailyAdCount")
        ud.set(Date(), forKey: "coin.lastAdDate")
        earn(coinsPerAd)
    }

    func earn(_ amount: Int) {
        balance += amount
        ud.set(balance, forKey: "coin.balance")
        earnAnimationAmount = amount
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            showEarnAnimation = true
        }
        HapticsService.shared.medium()
        AchievementTracker.shared.checkCoinAchievements(balance: balance)
        // Peak-coin leaderboard — Game Center keeps the max, so submitting balance is safe.
        GameCenterManager.shared.reportScore(.peakCoins, value: balance)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            withAnimation(.easeOut(duration: 0.4)) { self?.showEarnAnimation = false }
        }
    }

    func canAfford(_ cost: Int) -> Bool { balance >= cost }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        ud.set(balance, forKey: "coin.balance")
        HapticsService.shared.medium()
        AchievementTracker.shared.trackCoinsSpent(amount)
        return true
    }

    func resetForTesting() {
        balance = 50
        ud.set(50,  forKey: "coin.balance")
        ud.set(false, forKey: "coin.welcomed")
        ud.removeObject(forKey: "coin.lastAdDate")
        ud.removeObject(forKey: "coin.dailyAdCount")
        ud.removeObject(forKey: "coin.lastBattleDate")
        ud.removeObject(forKey: "coin.tournamentSeedAwarded")
    }
}
