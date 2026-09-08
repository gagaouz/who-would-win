import Foundation

struct BattleResult: Codable, Equatable {
    let winner: String           // Animal ID of winner, or "draw"
    let narration: String        // 2-sentence battle narration
    let funFact: String          // One fun fact about the winner
    let winnerHealthPercent: Int // 10–90, how dominant the win was
    let loserHealthPercent: Int  // 0–25, how much fight the loser put up
    /// Optional one-line, kid-friendly reason the winner won (specific weapon/
    /// ability/size). Supplied by the cloud backend; nil for older/offline
    /// results. The result screen prefers this over the local BattleInsight.why.
    var why: String? = nil
    var isOfflineFallback: Bool = false  // true when using local fallback result

    enum CodingKeys: String, CodingKey {
        case winner, narration, funFact, winnerHealthPercent, loserHealthPercent, why
    }
}
