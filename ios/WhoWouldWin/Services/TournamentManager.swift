import Foundation
import SwiftUI

/// Single source of truth for the active tournament. All coin transactions during
/// a tournament route through here so the math is auditable in one file.
@MainActor
final class TournamentManager: ObservableObject {
    static let shared = TournamentManager()

    @Published var activeTournament: Tournament?

    private let ud = UserDefaults.standard
    private let storageKey = "tournament.active"

    // Daily tournament cap — keeps kids from chain-running tournaments all day
    // while preserving a coin-based "one more" pressure release valve.
    private let dailyCountKey = "tournament.dailyCount"
    private let dailyCountDateKey = "tournament.dailyCountDate"

    private init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = ud.data(forKey: storageKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(Tournament.self, from: data)
            // Schema mismatch → discard gracefully.
            if decoded.schemaVersion == Tournament.currentSchemaVersion {
                self.activeTournament = decoded
            } else {
                ud.removeObject(forKey: storageKey)
            }
        } catch {
            // Corrupt blob — discard quietly.
            ud.removeObject(forKey: storageKey)
        }
    }

    private func save() {
        guard let t = activeTournament else {
            ud.removeObject(forKey: storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(t) {
            ud.set(data, forKey: storageKey)
        }
    }

    private func mutate(_ block: (inout Tournament) -> Void) {
        guard var t = activeTournament else { return }
        block(&t)
        activeTournament = t
        save()
    }

    // MARK: - Daily cap

    /// Number of tournaments started today (including both free + coin-unlocked).
    /// Rolls over at midnight.
    var tournamentsStartedToday: Int {
        let last = ud.object(forKey: dailyCountDateKey) as? Date ?? .distantPast
        if !Calendar.current.isDateInToday(last) { return 0 }
        return ud.integer(forKey: dailyCountKey)
    }

    /// Remaining free tournaments for the day (before the coin gate kicks in).
    var freeTournamentsRemainingToday: Int {
        max(0, CoinStore.shared.tournamentDailyFreeLimit - tournamentsStartedToday)
    }

    /// True if the next tournament will require spending coins instead of being free.
    var nextTournamentRequiresCoins: Bool {
        tournamentsStartedToday >= CoinStore.shared.tournamentDailyFreeLimit
    }

    /// Bumps the daily counter for today. Called inside `startNew` after all
    /// gate checks pass.
    private func incrementDailyCount() {
        let count = tournamentsStartedToday + 1
        ud.set(count, forKey: dailyCountKey)
        ud.set(Date(), forKey: dailyCountDateKey)
    }

    /// TestFlight/debug helper: reset today's tournament count to zero.
    func resetDailyTournamentCountForTesting() {
        ud.removeObject(forKey: dailyCountKey)
        ud.removeObject(forKey: dailyCountDateKey)
    }

    // MARK: - Lifecycle

    /// Reason why startNew returned nil — lets the UI show the right prompt.
    enum StartBlockedReason {
        case dailyLimitReachedNeedCoins(cost: Int)
        case insufficientCoinsForExtra(cost: Int, balance: Int)
    }

    /// Creates a brand-new tournament. The player has already chosen size + selection mode
    /// (and provided manual picks if applicable). Returns the new tournament; also stored.
    /// Does NOT charge any coins yet — coin charges happen at bracket commit (Phase 7 wiring).
    ///
    /// Daily cap: the first `tournamentDailyFreeLimit` tournaments each day are free.
    /// Beyond that, pass `payWithCoinsIfOverLimit: true` to spend `tournamentExtraEntryCost`
    /// coins for an extra entry. If the gate would block start, returns nil and sets
    /// `lastStartBlockedReason` so the caller can prompt the user.
    @Published var lastStartBlockedReason: StartBlockedReason?

    func startNew(size: BracketSize,
                  selectionMode: SelectionMode,
                  manualPicks: [Animal] = [],
                  payWithCoinsIfOverLimit: Bool = false) -> Tournament? {
        let cost = CoinStore.shared.tournamentExtraEntryCost
        if nextTournamentRequiresCoins {
            guard payWithCoinsIfOverLimit else {
                lastStartBlockedReason = .dailyLimitReachedNeedCoins(cost: cost)
                return nil
            }
            let balance = CoinStore.shared.balance
            guard balance >= cost else {
                lastStartBlockedReason = .insufficientCoinsForExtra(cost: cost, balance: balance)
                return nil
            }
            guard CoinStore.shared.spend(cost) else {
                lastStartBlockedReason = .insufficientCoinsForExtra(cost: cost, balance: balance)
                return nil
            }
        }

        lastStartBlockedReason = nil
        incrementDailyCount()

        let bracket = generateBracket(size: size,
                                      selectionMode: selectionMode,
                                      manualPicks: manualPicks)
        let t = Tournament(
            id: UUID(),
            createdAt: Date(),
            size: size,
            selectionMode: selectionMode,
            phase: .preview,
            bracket: bracket,
            grandChampion: nil,
            rerollUsed: false,
            ledger: [],
            schemaVersion: Tournament.currentSchemaVersion
        )
        activeTournament = t
        save()
        return t
    }

    /// Wipes the active tournament. Used on completion or forfeit.
    /// No coin refund — already-deducted wagers stay deducted.
    func clear() {
        activeTournament = nil
        ud.removeObject(forKey: storageKey)
    }

    /// User explicitly forfeits an in-progress tournament.
    func forfeit() {
        clear()
    }

    /// True if there is an in-progress tournament that the user should be prompted to resume.
    var hasResumableTournament: Bool {
        guard let t = activeTournament else { return false }
        return t.phase != .complete
    }

    // MARK: - Phase transitions

    func setPhase(_ phase: TournamentPhase) {
        mutate { $0.phase = phase }
    }

    // MARK: - Re-roll

    /// Re-rolls bracket seeding and arena assignments. Same creature pool.
    /// Charges the re-roll cost from CoinStore and records it in the tournament ledger.
    /// Returns false if re-roll already used or balance insufficient.
    @discardableResult
    func rerollBracket() -> Bool {
        guard let t = activeTournament, !t.rerollUsed else { return false }
        let cost = CoinStore.shared.tournamentBracketRerollCost
        guard CoinStore.shared.spend(cost) else { return false }

        let pool = t.bracket.allFighters
        let newBracket = generateBracket(size: t.size,
                                         selectionMode: t.selectionMode,
                                         manualPicks: pool,
                                         forcePoolReuse: true)
        mutate {
            $0.bracket = newBracket
            $0.rerollUsed = true
            $0.ledger.append(LedgerEntry(
                id: UUID(),
                timestamp: Date(),
                description: "Bracket re-roll",
                delta: -cost,
                runningBalance: CoinStore.shared.balance
            ))
        }
        return true
    }

    // MARK: - Bracket generation (Phase 4)

    /// Builds a brand-new bracket. For `manual`/`hybrid` modes, manualPicks are seeded
    /// first; remaining slots are filled randomly from the unlocked roster.
    /// For `random`, manualPicks is ignored.
    /// `forcePoolReuse` skips pool generation and uses manualPicks as the entire pool
    /// (used by re-roll).
    func generateBracket(size: BracketSize,
                         selectionMode: SelectionMode,
                         manualPicks: [Animal],
                         forcePoolReuse: Bool = false) -> Bracket {
        // 1. Resolve creature pool
        let pool: [Animal]
        if forcePoolReuse {
            pool = manualPicks.shuffled()
        } else {
            pool = resolveCreaturePool(size: size,
                                       selectionMode: selectionMode,
                                       manualPicks: manualPicks)
        }

        // 2. Build first round of matchups, pairing fighters in order
        let unlockedEnvs = unlockedEnvironments()
        var round0: [Matchup] = []
        var envPool = unlockedEnvs.shuffled()
        var i = 0
        while i < pool.count - 1 {
            let env = nextEnvironment(envPool: &envPool, refill: unlockedEnvs)
            round0.append(Matchup(
                id: UUID(),
                fighter1: pool[i],
                fighter2: pool[i + 1],
                environment: env,
                wager: nil,
                result: nil
            ))
            i += 2
        }

        // 3. Build empty placeholder arrays for future rounds (populated as previous resolve)
        var rounds: [[Matchup]] = [round0]
        for _ in 1..<size.totalRounds {
            rounds.append([])
        }

        return Bracket(rounds: rounds)
    }

    /// Returns one environment from the shuffled pool. When the pool runs dry,
    /// it gets refilled with another shuffle of the full unlocked set.
    /// This guarantees no repeats within a round of ≤ unlockedEnvs.count matchups,
    /// and gracefully repeats if the player has very few unlocked environments.
    private func nextEnvironment(envPool: inout [BattleEnvironment],
                                 refill: [BattleEnvironment]) -> BattleEnvironment {
        if envPool.isEmpty { envPool = refill.shuffled() }
        return envPool.removeLast()
    }

    /// Resolves the full creature pool for a tournament based on selection mode.
    private func resolveCreaturePool(size: BracketSize,
                                     selectionMode: SelectionMode,
                                     manualPicks: [Animal]) -> [Animal] {
        let target = size.rawValue
        let unlockedRoster = unlockedRoster()

        switch selectionMode {
        case .random:
            return Array(unlockedRoster.shuffled().prefix(target))

        case .manual:
            // Trust the picker UI to enforce exact count; clamp defensively.
            let picks = Array(manualPicks.prefix(target))
            if picks.count == target { return picks.shuffled() }
            // Underfill (shouldn't happen) — fall through to hybrid behavior.
            fallthrough

        case .hybrid:
            var combined = manualPicks
            let pickedIds = Set(combined.map(\.id))
            let fillers = unlockedRoster.filter { !pickedIds.contains($0.id) }.shuffled()
            for f in fillers {
                if combined.count >= target { break }
                combined.append(f)
            }
            return Array(combined.prefix(target)).shuffled()
        }
    }

    /// Returns all built-in animals the user is currently entitled to use.
    /// (Custom creatures are not in this list — they enter via manual picks only.)
    private func unlockedRoster() -> [Animal] {
        let s = UserSettings.shared
        return Animals.all.filter { animal in
            switch animal.category {
            case .all, .land, .sea, .air, .insect: return true
            case .prehistoric: return s.isPrehistoricUnlocked
            case .fantasy:     return s.isFantasyUnlocked
            case .mythic:      return s.isMythicUnlocked
            case .olympus:     return s.isOlympusUnlocked
            }
        }
    }

    /// Returns all environments the user can currently use.
    private func unlockedEnvironments() -> [BattleEnvironment] {
        let s = UserSettings.shared
        let envs = BattleEnvironment.allCases.filter { s.isEnvironmentUnlocked($0) }
        // Always at least the 3 free ones — guaranteed by the model
        return envs.isEmpty ? [.grassland, .ocean, .sky] : envs
    }

    // MARK: - Wagering (Phase 5)

    /// Maximum wager allowed for a single matchup at the current balance.
    /// Floor of 10 coins (or 0 if balance < 10).
    var maxMatchupWager: Int {
        let bal = CoinStore.shared.balance
        let pct = Int(Double(bal) * CoinStore.shared.tournamentMatchupWagerMaxPct)
        return max(0, max(pct, bal >= CoinStore.shared.tournamentMatchupWagerFloor ? CoinStore.shared.tournamentMatchupWagerFloor : 0))
    }

    /// Maximum grand champion wager allowed at the current balance.
    var maxGrandChampionWager: Int {
        let bal = CoinStore.shared.balance
        let pct = Int(Double(bal) * CoinStore.shared.tournamentGrandChampionMaxPct)
        return max(0, max(pct, bal >= CoinStore.shared.tournamentGrandChampionFloor ? CoinStore.shared.tournamentGrandChampionFloor : 0))
    }

    /// Places a wager on a specific matchup. Deducts coins immediately.
    /// Returns false if balance insufficient or matchup not found / already wagered.
    @discardableResult
    func placeMatchupWager(matchupId: UUID,
                           pickedFighterId: String,
                           amount: Int) -> Bool {
        guard let t = activeTournament else { return false }
        guard let r = t.currentRoundIndex else { return false }
        guard let mIdx = t.bracket.rounds[r].firstIndex(where: { $0.id == matchupId }) else { return false }
        let matchup = t.bracket.rounds[r][mIdx]
        guard matchup.wager == nil else { return false }
        guard amount >= CoinStore.shared.tournamentMatchupWagerFloor else { return false }
        guard amount <= maxMatchupWager else { return false }
        guard CoinStore.shared.spend(amount) else { return false }

        mutate { tournament in
            tournament.bracket.rounds[r][mIdx].wager = MatchupWager(
                pickedFighterId: pickedFighterId,
                amount: amount
            )
            tournament.ledger.append(LedgerEntry(
                id: UUID(),
                timestamp: Date(),
                description: "Wager: \(matchup.fighter1.name) vs \(matchup.fighter2.name)",
                delta: -amount,
                runningBalance: CoinStore.shared.balance
            ))
        }
        return true
    }

    /// Places the initial grand champion wager. Locks at 5.0× multiplier.
    /// Deducts coins immediately. Returns false if invalid / already placed.
    @discardableResult
    func placeGrandChampion(pickedFighterId: String, amount: Int) -> Bool {
        guard var t = activeTournament else { return false }
        guard t.grandChampion == nil else { return false }
        guard amount >= CoinStore.shared.tournamentGrandChampionFloor else { return false }
        guard amount <= maxGrandChampionWager else { return false }
        guard CoinStore.shared.spend(amount) else { return false }

        let pick = t.bracket.allFighters.first(where: { $0.id == pickedFighterId })?.name ?? "?"
        t.grandChampion = GrandChampionWager(
            pickedFighterId: pickedFighterId,
            amount: amount,
            multiplier: WagerMultipliers.grandChampion(lockedAtRoundIndex: 0),
            lockedAtRoundIndex: 0
        )
        t.ledger.append(LedgerEntry(
            id: UUID(),
            timestamp: Date(),
            description: "Grand Champion: \(pick) (5.0×)",
            delta: -amount,
            runningBalance: CoinStore.shared.balance
        ))
        activeTournament = t
        save()
        return true
    }

    /// Swap the grand champion pick to a different alive fighter.
    /// Locks in the new (lower) multiplier based on the current round.
    /// Does NOT charge any additional coins.
    /// Returns false if not allowed (final round, or pick not alive).
    @discardableResult
    func swapGrandChampion(toPickedFighterId newId: String) -> Bool {
        guard let t = activeTournament, t.canSwapGrandChampion else { return false }
        guard let r = t.currentRoundIndex else { return false }
        guard t.grandChampion != nil else { return false }
        guard t.bracket.aliveFighters.contains(where: { $0.id == newId }) else { return false }

        let newMultiplier = WagerMultipliers.grandChampion(lockedAtRoundIndex: r)
        let pickName = t.bracket.allFighters.first(where: { $0.id == newId })?.name ?? "?"

        mutate { tournament in
            tournament.grandChampion?.pickedFighterId = newId
            tournament.grandChampion?.multiplier = newMultiplier
            tournament.grandChampion?.lockedAtRoundIndex = r
            tournament.ledger.append(LedgerEntry(
                id: UUID(),
                timestamp: Date(),
                description: "GC swap → \(pickName) (\(String(format: "%.2f", newMultiplier))×)",
                delta: 0,
                runningBalance: CoinStore.shared.balance
            ))
        }
        return true
    }

    // MARK: - Battle resolution (Phase 5 cont.)

    /// Records the result of a single matchup. Does NOT advance the phase —
    /// caller (TournamentBattleHostView) handles flow.
    func recordMatchupResult(matchupId: UUID, result: BattleResult) {
        guard let t = activeTournament else { return }
        guard let r = t.currentRoundIndex else { return }
        guard let mIdx = t.bracket.rounds[r].firstIndex(where: { $0.id == matchupId }) else { return }

        mutate { tournament in
            tournament.bracket.rounds[r][mIdx].result = result
        }
    }

    /// Resolves all wager payouts for the current round, builds the next round's matchups,
    /// and updates the ledger. Call this after all matchups in the current round are resolved.
    /// Returns the per-matchup payout breakdown for the results screen.
    @discardableResult
    func resolveRoundPayouts() -> [RoundPayoutLine] {
        guard let t = activeTournament else { return [] }
        guard let r = t.currentRoundIndex else { return [] }

        let round = t.bracket.rounds[r]
        var lines: [RoundPayoutLine] = []

        for matchup in round {
            guard let result = matchup.result else { continue }
            let winnerId = result.winner
            let winnerName = matchup.winningFighter?.name ?? "Draw"

            if let wager = matchup.wager {
                let won = wager.pickedFighterId == winnerId
                if won {
                    let multiplier = WagerMultipliers.matchup(for: r, in: t.size)
                    let payout = Int((Double(wager.amount) * multiplier).rounded(.down))
                    CoinStore.shared.earn(payout)
                    mutate { tournament in
                        tournament.ledger.append(LedgerEntry(
                            id: UUID(),
                            timestamp: Date(),
                            description: "Win: \(winnerName) (\(String(format: "%.1f", multiplier))×)",
                            delta: payout,
                            runningBalance: CoinStore.shared.balance
                        ))
                    }
                    lines.append(RoundPayoutLine(
                        matchupId: matchup.id,
                        winnerName: winnerName,
                        wagered: wager.amount,
                        delta: payout,
                        won: true
                    ))
                } else {
                    // Wager already deducted at placement; nothing to refund.
                    lines.append(RoundPayoutLine(
                        matchupId: matchup.id,
                        winnerName: winnerName,
                        wagered: wager.amount,
                        delta: -wager.amount,
                        won: false
                    ))
                }
            } else {
                lines.append(RoundPayoutLine(
                    matchupId: matchup.id,
                    winnerName: winnerName,
                    wagered: 0,
                    delta: 0,
                    won: false
                ))
            }
        }

        // Build next round (or finalize tournament)
        let nextRoundIndex = r + 1
        if nextRoundIndex < t.size.totalRounds {
            let winners = round.compactMap { $0.winningFighter }
            // Pair winners into next round's matchups, fresh environments
            let unlockedEnvs = unlockedEnvironments()
            var envPool = unlockedEnvs.shuffled()
            var nextMatchups: [Matchup] = []
            var i = 0
            while i < winners.count - 1 {
                let env = nextEnvironment(envPool: &envPool, refill: unlockedEnvs)
                nextMatchups.append(Matchup(
                    id: UUID(),
                    fighter1: winners[i],
                    fighter2: winners[i + 1],
                    environment: env,
                    wager: nil,
                    result: nil
                ))
                i += 2
            }
            mutate { tournament in
                tournament.bracket.rounds[nextRoundIndex] = nextMatchups
            }
        }

        return lines
    }

    /// Resolves the grand champion payout once the final is decided.
    /// Returns the payout amount (0 if wrong / no GC pick).
    @discardableResult
    func resolveGrandChampionPayout() -> Int {
        guard let t = activeTournament else { return 0 }
        guard let gc = t.grandChampion else { return 0 }
        // Find the champion: winner of the final round
        let finalRound = t.bracket.rounds.last ?? []
        guard let champion = finalRound.first?.winningFighter else { return 0 }

        if champion.id == gc.pickedFighterId {
            let payout = Int((Double(gc.amount) * gc.multiplier).rounded(.down))
            CoinStore.shared.earn(payout)
            mutate { tournament in
                tournament.ledger.append(LedgerEntry(
                    id: UUID(),
                    timestamp: Date(),
                    description: "Grand Champion correct! (\(String(format: "%.2f", gc.multiplier))×)",
                    delta: payout,
                    runningBalance: CoinStore.shared.balance
                ))
            }
            return payout
        } else {
            mutate { tournament in
                tournament.ledger.append(LedgerEntry(
                    id: UUID(),
                    timestamp: Date(),
                    description: "Grand Champion miss",
                    delta: 0,
                    runningBalance: CoinStore.shared.balance
                ))
            }
            return 0
        }
    }

    // MARK: - Tournament summary

    /// Net coin delta across the entire tournament (sum of all ledger entries).
    var netCoinDelta: Int {
        activeTournament?.ledger.reduce(0) { $0 + $1.delta } ?? 0
    }
}

// MARK: - Round payout summary (for results screen)

struct RoundPayoutLine: Identifiable, Equatable {
    let id = UUID()
    let matchupId: UUID
    let winnerName: String
    let wagered: Int
    let delta: Int     // positive = won that much, negative = lost wager
    let won: Bool
}
