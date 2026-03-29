import Foundation

struct BattleResult: Codable {
    let winner: String           // Animal ID of winner, or "draw"
    let narration: String        // 2-sentence battle narration
    let funFact: String          // One fun fact about the winner
    let winnerHealthPercent: Int // 10–90, how dominant the win was
    let loserHealthPercent: Int  // 0–25, how much fight the loser put up
    var isOfflineFallback: Bool = false  // true when using local fallback result

    enum CodingKeys: String, CodingKey {
        case winner, narration, funFact, winnerHealthPercent, loserHealthPercent
    }
}
