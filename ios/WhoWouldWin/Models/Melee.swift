import Foundation

/// Result of a team-vs-team melee battle (N-vs-M).
struct MeleeResult: Codable, Equatable {
    enum Team: String, Codable { case A, B }

    let winningTeam: Team
    let narration: String
    let funFact: String
    /// Animal.id of the MVP from the winning team — drives the result-screen
    /// portrait callout.
    let mvp: String
    /// 10–90 health bar for team A after the fight.
    let teamAHealth: Int
    /// 10–90 health bar for team B after the fight.
    let teamBHealth: Int
    /// Set client-side AFTER decoding when the result came from the local
    /// fallback. Excluded from CodingKeys so JSONDecoder doesn't look for it
    /// in the backend JSON (the backend never sends it). **Without this
    /// exclusion the decode fails every single response and the app falls
    /// back to local for every melee.**
    var isOfflineFallback: Bool = false

    enum CodingKeys: String, CodingKey {
        case winningTeam, narration, funFact, mvp, teamAHealth, teamBHealth
    }
}

/// One side of a melee — 1 to 4 (or up to 6) fighters.
struct MeleeTeam: Equatable {
    var fighters: [Animal]
    var count: Int { fighters.count }
}
