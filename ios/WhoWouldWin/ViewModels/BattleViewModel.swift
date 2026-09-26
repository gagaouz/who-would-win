import Foundation
import Combine

final class BattleViewModel: ObservableObject {

    // MARK: - Battle Phase

    enum BattlePhase {
        case intro, animating, fetchingResult, revealing, complete
    }

    // MARK: - State

    @Published var phase: BattlePhase = .intro
    @Published var battleResult: BattleResult? = nil
    @Published var errorMessage: String? = nil
    @Published var narrationDisplayed: String = ""   // Accepted full narration
    @Published var animationComplete: Bool = false

    let fighter1: Animal
    let fighter2: Animal
    var environment: BattleEnvironment
    var arenaEffectsEnabled: Bool
    /// Optional server-trusted tournament context line (e.g. "This battle is a Quarterfinal in an 8-creature tournament. Build drama accordingly.")
    /// When set, the backend skips its result cache so each round gets fresh narration.
    let tournamentContext: String?
    /// Quick battles use the lightweight result endpoint with a local fallback,
    /// then reveal immediately without waiting for an arena animation.
    let isQuickMode: Bool

    /// When set, the next `startBattle()` run will skip the server fetch and use this result instead.
    /// Consumed (cleared) on use. Used by tournament mode to inject a client-side tiebreaker
    /// result after two consecutive draws so the bracket can advance.
    var forcedResult: BattleResult? = nil

    private var lifecycle = RetroBattleLifecycle<BattleResult>()
    @Published private(set) var presentationID = UUID()
    private var deadlineTask: Task<Void, Never>?

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = false, isQuickMode: Bool = false, tournamentContext: String? = nil) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.environment = environment
        self.arenaEffectsEnabled = arenaEffectsEnabled
        self.isQuickMode = isQuickMode
        self.tournamentContext = tournamentContext
        self.presentationID = lifecycle.id
    }

    // MARK: - Result-bound battle flow

    /// Fetching and presentation have independent lifetimes. Once accepted, an
    /// answer is immutable; a renderer callback can only reveal that answer.
    @MainActor
    func startBattle() async {
        guard let session = lifecycle.begin() else { return }
        phase = .fetchingResult
        animationComplete = false
        deadlineTask?.cancel()
        deadlineTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 25_000_000_000) }
            catch { return }
            guard let self, !Task.isCancelled, self.lifecycle.id == session,
                  self.lifecycle.result == nil, !self.lifecycle.cancelled else { return }
            let fallback = await self.localFallback(markAsOffline: false)
            guard !Task.isCancelled else { return }
            self.accept(fallback, session: session)
        }

        if let forced = forcedResult {
            forcedResult = nil
            accept(forced, session: session)
            return
        }
        do {
            let result: BattleResult
            if isQuickMode {
                result = try await BattleService.shared.fetchQuickBattleResult(
                    fighter1: fighter1, fighter2: fighter2, environment: environment,
                    arenaEffectsEnabled: arenaEffectsEnabled)
            } else {
                result = try await BattleService.shared.fetchBattleResult(
                    fighter1: fighter1, fighter2: fighter2, environment: environment,
                    arenaEffectsEnabled: arenaEffectsEnabled, tournamentContext: tournamentContext)
            }
            guard !Task.isCancelled, lifecycle.id == session, !lifecycle.cancelled else { return }
            if result.winner == "draw" || result.winner == fighter1.id || result.winner == fighter2.id {
                accept(sanityCheckResult(result), session: session)
            } else {
                let fallback = await localFallback(markAsOffline: false)
                guard !Task.isCancelled else { return }
                accept(fallback, session: session)
            }
        } catch {
            guard !Task.isCancelled, lifecycle.id == session, !lifecycle.cancelled else { return }
            let offline = (error as? BattleError) == .networkUnavailable
            let fallback = await localFallback(markAsOffline: offline)
            guard !Task.isCancelled else { return }
            accept(fallback, session: session)
        }
    }

    @MainActor
    private func localFallback(markAsOffline: Bool) async -> BattleResult {
        await BattleService.shared.generateFallbackResult(
            fighter1: fighter1, fighter2: fighter2,
            environment: arenaEffectsEnabled ? environment : .grassland,
            arenaEffectsEnabled: arenaEffectsEnabled, markAsOffline: markAsOffline)
    }

    @MainActor
    private func accept(_ result: BattleResult, session: UUID) {
        guard lifecycle.id == session, !lifecycle.cancelled, lifecycle.result == nil else { return }
        let finalResult = tournamentContext != nil ? breakDrawIfNeeded(result) : result
        guard lifecycle.accept(finalResult, for: session) else { return }
        deadlineTask?.cancel()
        deadlineTask = nil
        battleResult = finalResult
        narrationDisplayed = finalResult.narration
        phase = .animating
        if isQuickMode { animationDidComplete(for: session) }
    }

    @MainActor
    func animationDidComplete(for session: UUID? = nil) {
        guard lifecycle.finish(session ?? presentationID) else { return }
        animationComplete = true
        phase = .complete
    }

    @MainActor
    func cancelBattle() {
        deadlineTask?.cancel()
        deadlineTask = nil
        lifecycle.cancel()
    }

    @MainActor
    func rematch() {
        deadlineTask?.cancel()
        deadlineTask = nil
        lifecycle.reset()
        presentationID = lifecycle.id
        battleResult = nil
        narrationDisplayed = ""
        animationComplete = false
        errorMessage = nil
        phase = .intro
    }

    // MARK: - Sanity Check

    /// Guard against absurd upsets from the API. Two checks:
    ///  1. **Stat mismatch** — if the declared winner has <35% of the loser's
    ///     env-adjusted stat total (a >2.8× gap), that's almost certainly a
    ///     bad model output (e.g. army ant beating a pteranodon).
    ///  2. **Environment impossibility** — if the declared winner physically
    ///     cannot function in this arena (sea creature on land, land creature
    ///     in deep ocean, non-flier in the sky), flip the result. This catches
    ///     things like "orca wins on grassland" where stats alone don't reveal
    ///     the absurdity.
    ///
    /// We don't apply this in the other direction (don't override "expected"
    /// wins) and we don't override draws.
    private func sanityCheckResult(_ result: BattleResult) -> BattleResult {
        guard result.winner != "draw" else { return result }
        // Two built-in creatures: the server picked the winner from the same
        // master creature list the phone has — nothing to second-guess, and
        // the rough local stats below would only flip correct answers.
        if OnDeviceTiers.isBuiltIn(fighter1.id) && OnDeviceTiers.isBuiltIn(fighter2.id) {
            return result
        }

        // Identify the declared winner / loser within this matchup.
        let winnerAnimal: Animal
        let loserAnimal: Animal
        if result.winner == fighter1.id {
            winnerAnimal = fighter1; loserAnimal = fighter2
        } else if result.winner == fighter2.id {
            winnerAnimal = fighter2; loserAnimal = fighter1
        } else {
            return result
        }

        // --- Check 2: environment incompatibility ---
        // ONLY when an arena was actually chosen. A "quick fight" has no arena
        // (arenaEffectsEnabled == false); its `.grassland` environment is just a
        // sentinel default, NOT a real grassland battlefield. With no terrain in
        // play, nothing can be "out of its element," so a sea creature must never
        // be flipped for being "on land" in a no-arena fight (e.g. Orca vs Lion).
        // Mirrors OnDeviceResolver, which zeroes the env modifier when arena
        // effects are off.
        if arenaEffectsEnabled,
           isEnvIncompatible(winnerAnimal, environment: environment),
           !isEnvIncompatible(loserAnimal, environment: environment) {
            return flipResult(result, realWinner: loserAnimal, realLoser: winnerAnimal,
                              reason: .environment)
        }

        // --- Check 1: stat mismatch ---
        // Compare env-adjusted stat totals AND raw size ratings — both matter,
        // because env multipliers can paper over a 100,000× mass difference
        // that real biology cares about a LOT.
        // Stats use the EFFECTIVE arena: with effects off, the stored
        // environment is an inert sentinel (quick-mode tournaments carry a real
        // random arena here that must not sway anything), so score against
        // grassland's neutral multipliers instead.
        let statEnv: BattleEnvironment = arenaEffectsEnabled ? environment : .grassland
        let winnerStats = AnimalStats.generate(for: winnerAnimal, environment: statEnv)
        let loserStats  = AnimalStats.generate(for: loserAnimal,  environment: statEnv)
        let winnerScore = Double(winnerStats.speed + winnerStats.power + winnerStats.agility + winnerStats.defense)
        let loserScore  = Double(loserStats.speed  + loserStats.power  + loserStats.agility  + loserStats.defense)

        guard loserScore > 0 else { return result }
        let statRatio  = winnerScore / loserScore
        // Size is 1-5; treat it like a tier (2-tier gap should be very strong).
        let sizeGap    = loserAnimal.size - winnerAnimal.size

        // Flip on EITHER condition:
        //  • Stat ratio under 0.45 (winner ≤ 45% of loser — was 0.35, too lenient)
        //  • Size gap of 3+ (e.g. size-1 ant beating a size-4 raptor)
        let absurdStats = statRatio < 0.45
        let absurdSize  = sizeGap >= 3

        guard absurdStats || absurdSize else { return result }

        return flipResult(result, realWinner: loserAnimal, realLoser: winnerAnimal,
                          reason: .statMismatch)
    }

    private enum FlipReason { case statMismatch, environment }

    /// Replace the result with a sensible winner-narration. Used by both sanity
    /// checks; the narration varies slightly based on why we flipped.
    private func flipResult(_ original: BattleResult,
                            realWinner: Animal,
                            realLoser: Animal,
                            reason: FlipReason) -> BattleResult {
        let narration: String
        let funFact: String
        switch reason {
        case .environment:
            narration = "The \(realLoser.name) was completely out of its element in the \(environment.name.lowercased()) — beached, blinded, or struggling to even move. The \(realWinner.name), right at home here, took control of the battle from the very first moment and never gave up the advantage."
            funFact = "Environment matters! The \(realLoser.name) is incredible in its native habitat — but no creature wins outside of its element."
        case .statMismatch:
            narration = "The \(realWinner.name) used its overwhelming size and strength to dominate the \(realLoser.name) from start to finish! It was no contest — the arena erupted as the champion stood tall."
            funFact = "The \(realWinner.name) is a true giant of the animal kingdom — sheer size and strength like that is almost impossible to beat in a head-to-head clash!"
        }

        var flipped = BattleResult(
            winner: realWinner.id,
            narration: narration,
            funFact: funFact,
            winnerHealthPercent: Int.random(in: 75...95),
            loserHealthPercent: Int.random(in: 5...20)
        )
        flipped.isOfflineFallback = original.isOfflineFallback
        return flipped
    }

    /// True when this animal physically cannot function in this arena. Used
    /// only for the most clear-cut cases — a sea creature on land, a land
    /// creature in deep ocean, a non-flying land creature in the sky. We
    /// deliberately keep the rules conservative so we don't override edge
    /// cases the AI might be getting right.
    private func isEnvIncompatible(_ animal: Animal, environment: BattleEnvironment) -> Bool {
        // Categories with built-in environment flexibility (mythical creatures,
        // gods, prehistoric flyers/swimmers) — skip the check, let the AI decide.
        switch animal.category {
        case .fantasy, .mythic, .olympus, .prehistoric:
            return false
        case .all:
            return false
        case .sea:
            // Beached/immobile on any LAND arena.
            switch environment {
            case .grassland, .jungle, .volcano, .desert, .arctic:
                return true
            case .sky:
                return true   // Can't fly, can't breathe air efficiently
            case .ocean, .night, .storm:
                return false
            }
        case .land:
            // Land animals drown in deep ocean (most), fall from the sky.
            switch environment {
            case .ocean:
                return true
            case .sky:
                return true
            default:
                return false
            }
        case .air:
            // Air animals are mostly fine — they can land. Only the ocean is
            // genuinely deadly (drowning), but most birds can swim briefly,
            // so we don't auto-flip — trust the AI.
            return false
        case .insect:
            // Insects struggle in deep ocean but are otherwise broadly OK.
            return environment == .ocean
        case .pets:
            // Pets — mostly land-bound. Goldfish/betta could survive ocean briefly
            // but trust the AI for nuance; only flip on clearly-fatal mismatches.
            switch environment {
            case .ocean: return true   // dogs and hamsters drown
            case .sky:   return true   // can't fly (parakeet/canary aside, trust AI)
            default:     return false
            }
        case .farm:
            // Farm animals — barnyard creatures, all land-bound.
            switch environment {
            case .ocean: return true   // cows, pigs, sheep drown
            case .sky:   return true   // can't fly (ducks/geese aside, trust AI)
            default:     return false
            }
        }
    }

    // MARK: - Draw Breaking

    /// Tournament matches must always have a winner. If the upstream result is
    /// a draw, pick a random fighter and — crucially — replace any draw-flavoured
    /// narration/funFact so the UI doesn't show "neither could claim victory"
    /// text above a declared winner.
    private func breakDrawIfNeeded(_ result: BattleResult) -> BattleResult {
        guard result.winner == "draw" else { return result }

        let winnerFirst = Bool.random()
        let winner = winnerFirst ? fighter1 : fighter2
        let loser  = winnerFirst ? fighter2 : fighter1

        // A small pool of kid-friendly winner lines — picked at random so it
        // doesn't feel like a canned response.
        let narrationPool = [
            "The \(winner.name) edged out the \(loser.name) in a brutal, back-and-forth clash! Both fought with everything they had, but the \(winner.name) landed the final decisive blow.",
            "After a hard-fought struggle, the \(winner.name) outlasted the \(loser.name) by sheer grit. It was close — but in the end, only one could stand tall.",
            "The \(winner.name) barely pulled ahead of the \(loser.name) in a neck-and-neck battle! Stamina won the day as the \(loser.name) finally yielded."
        ]
        let narration = narrationPool.randomElement()!

        let funFactPool = [
            "The \(winner.name) is famous for its incredible combat instincts — every move counts.",
            "In the wild (or in legend), the \(winner.name) is known for refusing to give up against tougher opponents.",
            "The \(winner.name) earned this win with a perfect mix of strength and timing."
        ]
        let funFact = funFactPool.randomElement()!

        var broken = BattleResult(
            winner: winner.id,
            narration: narration,
            funFact: funFact,
            winnerHealthPercent: Int.random(in: 45...65),   // close match — low health
            loserHealthPercent: Int.random(in: 5...20)
        )
        // Preserve the offline-fallback flag if the source was offline
        broken.isOfflineFallback = result.isOfflineFallback
        return broken
    }

}
