import Foundation

// MARK: - Bracket Size

enum BracketSize: Int, Codable, CaseIterable, Identifiable {
    case four    = 4
    case eight   = 8
    case sixteen = 16

    var id: Int { rawValue }

    /// Total number of rounds for this bracket size.
    /// 4-bracket = 2 rounds (semis, final)
    /// 8-bracket = 3 rounds (QF, SF, final)
    /// 16-bracket = 4 rounds (R16, QF, SF, final)
    var totalRounds: Int {
        switch self {
        case .four:    return 2
        case .eight:   return 3
        case .sixteen: return 4
        }
    }

    /// Display name for a given round index (0-based).
    /// e.g. for 16-bracket: 0 → "Round of 16", 1 → "Quarterfinals", ...
    func roundName(for roundIndex: Int) -> String {
        let remaining = totalRounds - roundIndex
        switch remaining {
        case 1: return "Final"
        case 2: return "Semifinals"
        case 3: return "Quarterfinals"
        case 4: return "Round of 16"
        default: return "Round \(roundIndex + 1)"
        }
    }
}

// MARK: - Selection Mode

enum SelectionMode: String, Codable {
    case random
    case manual
    case hybrid
}

// MARK: - Tournament Phase (state machine)

enum TournamentPhase: Codable, Equatable {
    case setup                          // choosing size + selection mode
    case picking                        // CreaturePickerView (manual / hybrid)
    case preview                        // BracketPreviewView — confirm or re-roll
    case grandWager                     // GrandChampionWagerView (one-time, before R1 wagers)
    case roundWager(roundIndex: Int)    // RoundWagerView for the round
    case roundBattles(roundIndex: Int, matchupIndex: Int) // playing battles in order
    case roundResults(roundIndex: Int)  // RoundResultsView, locks in payouts
    case complete                       // TournamentCompleteView
}

// MARK: - Wager records

struct MatchupWager: Codable, Equatable {
    let pickedFighterId: String   // Animal.id of the side bet on
    let amount: Int               // coins staked (already deducted from balance)
}

struct GrandChampionWager: Codable, Equatable {
    /// Currently picked fighter id. May change via buy-out.
    var pickedFighterId: String
    /// Original wager amount, fixed for the life of the tournament.
    let amount: Int
    /// Multiplier locked in at the moment of the most recent pick.
    /// Starts at 5.0, decays per buy-out: 5.0 → 3.5 → 2.5 → 1.75
    var multiplier: Double
    /// Round index at which the current pick was placed (for UI display).
    var lockedAtRoundIndex: Int
}

// MARK: - Matchup

struct Matchup: Codable, Identifiable, Equatable {
    let id: UUID
    let fighter1: Animal
    let fighter2: Animal
    let environment: BattleEnvironment
    var wager: MatchupWager?
    var result: BattleResult?

    /// Returns the winner Animal once a result is recorded.
    /// nil if no result yet, or if result is a draw.
    var winningFighter: Animal? {
        guard let r = result else { return nil }
        if r.winner == fighter1.id { return fighter1 }
        if r.winner == fighter2.id { return fighter2 }
        return nil // draw
    }

    /// Returns the loser Animal once a result is recorded.
    var losingFighter: Animal? {
        guard let r = result else { return nil }
        if r.winner == fighter1.id { return fighter2 }
        if r.winner == fighter2.id { return fighter1 }
        return nil
    }

    var isResolved: Bool { result != nil }
}

// MARK: - Bracket

struct Bracket: Codable, Equatable {
    /// rounds[0] = first round, rounds[totalRounds-1] = final.
    /// Empty arrays for future rounds; populated as previous rounds resolve.
    var rounds: [[Matchup]]

    /// All unique fighters across the entire current bracket (used for grand champion picker).
    var allFighters: [Animal] {
        var seen = Set<String>()
        var out: [Animal] = []
        for round in rounds {
            for m in round {
                if seen.insert(m.fighter1.id).inserted { out.append(m.fighter1) }
                if seen.insert(m.fighter2.id).inserted { out.append(m.fighter2) }
            }
        }
        return out
    }

    /// All fighters still alive (i.e. who have not lost a resolved matchup).
    var aliveFighters: [Animal] {
        let losers = Set(rounds.flatMap { $0 }.compactMap { $0.losingFighter?.id })
        return allFighters.filter { !losers.contains($0.id) }
    }
}

// MARK: - Coin Ledger

struct LedgerEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let description: String
    let delta: Int            // negative for spends, positive for earns
    let runningBalance: Int   // balance immediately after this entry
}

// MARK: - Tournament

struct Tournament: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let size: BracketSize
    let selectionMode: SelectionMode
    var phase: TournamentPhase
    var bracket: Bracket
    var grandChampion: GrandChampionWager?
    var rerollUsed: Bool
    var ledger: [LedgerEntry]
    let schemaVersion: Int    // for forward compatibility

    static let currentSchemaVersion = 1

    /// Convenience: which round's wager phase we're in, if any.
    var currentRoundIndex: Int? {
        switch phase {
        case .roundWager(let r), .roundBattles(let r, _), .roundResults(let r):
            return r
        default:
            return nil
        }
    }

    /// True if the player can still swap their grand champion pick.
    /// Allowed before any round's wager phase EXCEPT the final round.
    var canSwapGrandChampion: Bool {
        guard let r = currentRoundIndex else { return false }
        return r < size.totalRounds - 1
    }
}

// MARK: - Multiplier table

enum WagerMultipliers {
    /// Per-round-of-payout multiplier for a *matchup* wager.
    /// `roundIndex` is 0-based. Multiplier is determined by rounds-remaining, so
    /// "a semifinal" is always 2.5× and "a final" is always 3.0× regardless of size.
    /// 4-bracket:  R0=semi(2.5), R1=final(3.0)
    /// 8-bracket:  R0=QF(2.0), R1=semi(2.5), R2=final(3.0)
    /// 16-bracket: R0=R16(1.5), R1=QF(2.0), R2=semi(2.5), R3=final(3.0)
    static func matchup(for roundIndex: Int, in size: BracketSize) -> Double {
        let remaining = size.totalRounds - roundIndex // rounds left including this one
        switch remaining {
        case 1: return 3.0  // final
        case 2: return 2.5  // semis
        case 3: return 2.0  // quarterfinals
        case 4: return 1.5  // round of 16
        default: return 1.5
        }
    }

    /// Grand Champion multiplier locked at the round in which the pick was placed.
    /// 5.0 (initial, before R1) → 3.5 → 2.5 → 1.75
    /// `lockedAtRoundIndex` is the round about to be played when the pick was locked.
    static func grandChampion(lockedAtRoundIndex: Int) -> Double {
        switch lockedAtRoundIndex {
        case 0: return 5.0
        case 1: return 3.5
        case 2: return 2.5
        case 3: return 1.75
        default: return 1.75
        }
    }
}
