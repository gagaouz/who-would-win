import Foundation
import Combine

/// Drives a melee (N-vs-M) battle. Mirrors BattleViewModel but team-aware.
@MainActor
final class MeleeViewModel: ObservableObject {
    enum Phase { case intro, animating, complete }

    @Published var phase: Phase = .intro
    @Published var result: MeleeResult? = nil
    @Published var animationComplete: Bool = false
    @Published var errorMessage: String? = nil

    let teamA: [Animal]
    let teamB: [Animal]
    let environment: BattleEnvironment
    let arenaEffectsEnabled: Bool

    init(teamA: [Animal], teamB: [Animal],
         environment: BattleEnvironment = .grassland,
         arenaEffectsEnabled: Bool = false) {
        self.teamA = teamA
        self.teamB = teamB
        self.environment = environment
        self.arenaEffectsEnabled = arenaEffectsEnabled
    }

    /// Environment for LOCAL stat math (fallback + sanity check). With arena
    /// effects off the stored environment is just an inert sentinel — score
    /// against grassland's neutral multipliers so no invisible arena decides
    /// the fight. (The network layer already omits env fields when off.)
    private var statEnvironment: BattleEnvironment {
        arenaEffectsEnabled ? environment : .grassland
    }

    func startBattle() async {
        phase = .animating
        do {
            let r = try await BattleService.shared.fetchMeleeResult(
                teamA: teamA, teamB: teamB,
                environment: environment,
                arenaEffectsEnabled: arenaEffectsEnabled)
            result = validatedMVP(sanityCheck(r))
        } catch {
            // Local fallback so the player isn't stuck if the backend is slow.
            let isTrueOffline = (error as? BattleError) == .networkUnavailable
            let fb = await BattleService.shared.generateMeleeFallback(
                teamA: teamA, teamB: teamB,
                environment: statEnvironment,
                arenaEffectsEnabled: arenaEffectsEnabled,
                markAsOffline: isTrueOffline)
            result = validatedMVP(sanityCheck(fb))
        }
    }

    /// The MVP id comes from the backend and is untrusted — if it isn't a
    /// member of the winning team (malformed response, junk id), every view
    /// that looks it up (result screen, share card) renders a hole. Repair it
    /// here, once, at the source.
    private func validatedMVP(_ r: MeleeResult) -> MeleeResult {
        let winners = r.winningTeam == .A ? teamA : teamB
        guard !winners.contains(where: { $0.id == r.mvp }),
              let fallbackMVP = winners.first else { return r }
        return MeleeResult(
            winningTeam: r.winningTeam,
            narration: r.narration,
            funFact: r.funFact,
            mvp: fallbackMVP.id,
            teamAHealth: r.teamAHealth,
            teamBHealth: r.teamBHealth,
            isOfflineFallback: r.isOfflineFallback
        )
    }

    func animationDidComplete() { animationComplete = true }

    /// Mirror of the 1v1 sanity check. Compute each team's env-adjusted
    /// score; if the *declared winner's* power is less than 30% of the
    /// loser's, flip. Conservative threshold — only blocks obvious upsets.
    private func sanityCheck(_ r: MeleeResult) -> MeleeResult {
        // Empty rosters can't be sanity-checked (and the flip path below
        // indexes [0] on the winning side). Shouldn't happen — setup requires
        // ≥1 per team — but never crash on a guardable condition.
        guard !teamA.isEmpty, !teamB.isEmpty else { return r }
        // All built-in creatures: the server decided from the same master
        // list the phone has, so don't second-guess it with rough local stats.
        if (teamA + teamB).allSatisfy({ OnDeviceTiers.isBuiltIn($0.id) }) { return r }
        let scoreFor: (Animal) -> Double = { a in
            let s = AnimalStats.generate(for: a, environment: self.statEnvironment)
            return Double(s.speed + s.power + s.agility + s.defense)
        }
        let coord: (Int) -> Double = { pow(0.92, Double($0 - 1)) }
        let pA = teamA.map(scoreFor).reduce(0, +) * coord(teamA.count)
        let pB = teamB.map(scoreFor).reduce(0, +) * coord(teamB.count)

        let declaredA = r.winningTeam == .A
        let winnerPower = declaredA ? pA : pB
        let loserPower  = declaredA ? pB : pA
        guard loserPower > 0 else { return r }
        let ratio = winnerPower / loserPower
        if ratio >= 0.30 { return r }

        // Flip — pick MVP from real winning team.
        let realWinningTeam: MeleeResult.Team = declaredA ? .B : .A
        let realWinners = declaredA ? teamB : teamA
        let realMvp = realWinners.max { scoreFor($0) < scoreFor($1) } ?? realWinners[0]
        return MeleeResult(
            winningTeam: realWinningTeam,
            narration: "Team \(realWinningTeam.rawValue) had the size and strength advantage and dominated the fight from start to finish. The \(realMvp.name) was simply too much for the other side.",
            funFact: "When one team has overwhelming power, even clever tactics can't turn the tide.",
            mvp: realMvp.id,
            teamAHealth: realWinningTeam == .A ? Int.random(in: 75...90) : Int.random(in: 8...20),
            teamBHealth: realWinningTeam == .B ? Int.random(in: 75...90) : Int.random(in: 8...20),
            isOfflineFallback: r.isOfflineFallback
        )
    }
}
