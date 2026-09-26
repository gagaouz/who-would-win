#if DEBUG
import Foundation

/// Only invoked after the explicit UI-test flag. Resolver unit tests remain real.
enum RetroTestFixtures {
    static func battle(_ fighter1: Animal, _ fighter2: Animal) throws -> BattleResult {
        if AppConfig.fixtureScenario == "offline" { throw BattleError.networkUnavailable }
        let draw = AppConfig.fixtureScenario == "battle-draw"
        return BattleResult(winner: draw ? "draw" : fighter1.id,
            narration: "Fixture battle completed.",
            funFact: "This deterministic result is used only by automated UI tests.",
            winnerHealthPercent: 72, loserHealthPercent: 18)
    }

    static func melee(_ teamA: [Animal], _ teamB: [Animal]) throws -> MeleeResult {
        if AppConfig.fixtureScenario == "offline" { throw BattleError.networkUnavailable }
        guard let mvp = teamA.first else { throw BattleError.serverError }
        return MeleeResult(winningTeam: .A, narration: "Fixture battle completed.",
            funFact: "Team fixtures do not contact external services.", mvp: mvp.id,
            teamAHealth: 72, teamBHealth: 18)
    }
}
#endif
