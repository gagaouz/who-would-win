// Compile with the exact 1.1.7 model source from commit 107bf7327f1c82e85282101e2294fb6f9ded3639.
// This produces synthetic compatibility fixtures, never reads a user's save.
import Foundation
import SwiftUI

// Required only to compile BattleEnvironment's UI color accessors on macOS.
// Colors are not part of the Codable payload exercised by this capture.
extension Color { init(hex: String) { self = .clear } }

@main
struct Capture117Fixtures {
    static func main() throws {
        let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let custom = Animal(id: "custom_legacy_mossback", name: "Mossback Dragon", emoji: "🐉",
                            category: .fantasy, pixelColor: "#4E7E45", size: 5, isCustom: true)
        let lion = Animal(id: "lion", name: "Lion", emoji: "🦁", category: .land, pixelColor: "#D4A017", size: 4)
        let gorilla = Animal(id: "gorilla", name: "Gorilla", emoji: "🦍", category: .land, pixelColor: "#2F2F2F", size: 4)
        let tiger = Animal(id: "tiger", name: "Tiger", emoji: "🐯", category: .land, pixelColor: "#FF6B00", size: 4)
        let matchup = Matchup(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                              fighter1: custom, fighter2: lion, environment: .grassland,
                              wager: MatchupWager(pickedFighterId: custom.id, amount: 100),
                              result: BattleResult(winner: custom.id, narration: "A saved 1.1.7 story.",
                                                   funFact: "Dragons are imaginary.", winnerHealthPercent: 72,
                                                   loserHealthPercent: 14))
        let secondMatchup = Matchup(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                                    fighter1: gorilla, fighter2: tiger, environment: .grassland, wager: nil,
                                    result: BattleResult(winner: tiger.id, narration: "Another saved story.",
                                                         funFact: "Tigers are cats.", winnerHealthPercent: 68,
                                                         loserHealthPercent: 15))
        var tournament = Tournament(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                                    createdAt: Date(timeIntervalSince1970: 1_790_000_000),
                                    size: .four, selectionMode: .manual,
                                    phase: .roundResults(roundIndex: 0),
                                    bracket: Bracket(rounds: [[matchup, secondMatchup], []]),
                                    grandChampion: GrandChampionWager(pickedFighterId: custom.id, amount: 100,
                                                                      multiplier: 5, lockedAtRoundIndex: 0),
                                    rerollUsed: false, ledger: [], schemaVersion: Tournament.currentSchemaVersion)
        tournament.markRoundResolved(0)
        tournament.grandChampionResolved = false
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let settled = try encoder.encode(tournament)
        try settled.write(to: directory.appendingPathComponent("tournament-settled-1.1.7.json"))
        tournament.phase = .roundBattles(roundIndex: 0, matchupIndex: 0)
        tournament.resolvedRounds = []
        tournament.bracket.rounds[0][0].result = nil
        tournament.bracket.rounds[0][1].result = nil
        let pending = try encoder.encode(tournament)
        try pending.write(to: directory.appendingPathComponent("tournament-pending-1.1.7.json"))
        let preferences: [String: Any] = [
            "coin.balance": 1234, "coin.welcomed": true,
            "stat.battles": 87, "stat.streak": 6, "stat.longestStreak": 12,
            "stat.predTotal": 20, "stat.predCorrect": 13,
            "stat.animalWins": ["lion": 11, custom.id: 4],
            "collected.animals": ["lion", "gorilla", custom.id],
            "achievement.earned": ["com.whowouldin.achievement.firstFight", "com.whowouldin.achievement.tenBattles"],
            "achievement.customCreaturesUsed": [custom.name],
            "iap.fantasy": true, "iap.melee": true, "iap.sub": false,
            "iap.processedConsumableTxIDs": ["fixture-transaction-1"],
            "pref.tournamentUnlocked": true, "parental.wageringEnabled": false,
            "pref.sound": false, "pref.narration": false, "pref.haptics": false,
            "onboard.seenFirstBattle": true, "paywall.shownOnce": true,
            "tournament.active": settled
        ]
        try PropertyListSerialization.data(fromPropertyList: preferences, format: .xml, options: 0)
            .write(to: directory.appendingPathComponent("progress-1.1.7.plist"))
        print("Captured synthetic 1.1.7 Codable and preference fixtures at \(directory.path)")
    }
}
