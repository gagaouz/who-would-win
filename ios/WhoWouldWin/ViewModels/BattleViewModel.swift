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
    @Published var narrationDisplayed: String = ""   // For typewriter effect
    @Published var animationComplete: Bool = false

    let fighter1: Animal
    let fighter2: Animal
    var environment: BattleEnvironment
    var arenaEffectsEnabled: Bool
    /// Optional server-trusted tournament context line (e.g. "This battle is a Quarterfinal in an 8-creature tournament. Build drama accordingly.")
    /// When set, the backend skips its result cache so each round gets fresh narration.
    let tournamentContext: String?
    /// When true, battle resolves instantly using the local fallback engine — no API call,
    /// no animation delay. Saves tokens and time; ideal for blasting through a tournament.
    let isQuickMode: Bool

    /// When set, the next `startBattle()` run will skip the server fetch and use this result instead.
    /// Consumed (cleared) on use. Used by tournament mode to inject a client-side tiebreaker
    /// result after two consecutive draws so the bracket can advance.
    var forcedResult: BattleResult? = nil

    /// Set by `fetchResultIgnoringErrors()` whenever the most recent fetch failed
    /// SPECIFICALLY because the device is offline (not because of a server slowdown,
    /// 5xx, or rate-limit). Consumed by `startBattle()` to decide whether the local
    /// fallback should be flagged with the "⚡ Offline result" badge.
    private var lastFetchErrorWasNetworkUnavailable = false

    // Continuation used to signal when the SpriteKit animation finishes
    private var animationContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland, arenaEffectsEnabled: Bool = false, isQuickMode: Bool = false, tournamentContext: String? = nil) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.environment = environment
        self.arenaEffectsEnabled = arenaEffectsEnabled
        self.isQuickMode = isQuickMode
        self.tournamentContext = tournamentContext
    }

    // MARK: - Main Battle Flow

    /// Main battle orchestration:
    /// 1. Stay in .intro for 2 seconds
    /// 2. Transition to .animating; fire API + animation simultaneously
    /// 3. As soon as API returns, start typewriter (text pre-populates during animation)
    /// 4. Wait for animation to finish → .revealing
    /// 5. Wait for typewriter to finish → .complete
    @MainActor
    func startBattle() async {
        phase = .intro
        animationComplete = false

        // ⚡ Quick mode: use lightweight AI — same logic, far fewer tokens.
        if isQuickMode {
            let r: BattleResult
            do {
                r = try await BattleService.shared.fetchQuickBattleResult(
                    fighter1: fighter1, fighter2: fighter2, environment: environment,
                    arenaEffectsEnabled: arenaEffectsEnabled)
            } catch {
                // Local fallback so the bracket doesn't stall.
                //
                // CRITICAL: only flag the result as "offline" when the device
                // is actually offline. A slow Railway cold-start, a 5xx, or
                // a rate-limit is NOT offline — flagging it would surface a
                // misleading "⚡ Offline result" badge to a user with full
                // signal. We pass `markAsOffline: true` only for the one
                // error case that genuinely means "no network".
                let isTrueOffline = (error as? BattleError) == .networkUnavailable
                let fallback = await BattleService.shared.generateFallbackResult(
                    fighter1: fighter1,
                    fighter2: fighter2,
                    environment: environment,
                    markAsOffline: isTrueOffline)
                let finalFallback = tournamentContext != nil
                    ? breakDrawIfNeeded(fallback)
                    : fallback
                battleResult = finalFallback
                narrationDisplayed = finalFallback.narration
                phase = .complete
                return
            }
            // Quick AI endpoint never draws, but guard just in case
            let finalQuick = tournamentContext != nil ? breakDrawIfNeeded(r) : r
            battleResult = finalQuick
            narrationDisplayed = finalQuick.narration
            phase = .complete
            return
        }

        try? await Task.sleep(nanoseconds: 2_000_000_000)
        guard !Task.isCancelled else { return }

        phase = .animating

        // Fire API and animation simultaneously.
        // We can await them independently — both tasks run concurrently.
        async let fetchTask: BattleResult? = fetchResultIgnoringErrors()
        async let animTask: Void           = waitForAnimation()

        // Consume API result first so typewriter can start early.
        let fetchedResult = await fetchTask
        guard !Task.isCancelled else { return }

        let result: BattleResult
        if let forced = self.forcedResult {
            // Tournament tiebreaker injected from BattleView — skip the fetched result.
            result = forced
            self.forcedResult = nil
        } else if let r = fetchedResult {
            result = r
        } else {
            // Local fallback path. Only mark the result as "offline" when the
            // last fetch failure was specifically a network-unavailable error.
            // Server slowdowns / 5xx / rate-limits get a silent local result
            // with no misleading offline badge.
            result = await BattleService.shared.generateFallbackResult(
                fighter1: fighter1,
                fighter2: fighter2,
                environment: environment,
                markAsOffline: lastFetchErrorWasNetworkUnavailable
            )
        }
        guard !Task.isCancelled else { return }

        // Tournament matches must always produce a clear winner — silently
        // break any draw so the bracket can advance without banner/retry flows.
        let finalResult = tournamentContext != nil ? breakDrawIfNeeded(result) : result
        battleResult = finalResult

        // Start typewriter NOW — text populates while animation is still running.
        let typewriterTask = Task { @MainActor in
            await self.startTypewriterEffect()
        }

        // Wait for animation.
        await animTask
        guard !Task.isCancelled else {
            typewriterTask.cancel()
            return
        }

        phase = .revealing

        // Wait for typewriter to finish (may already be done).
        await typewriterTask.value

        phase = .complete
    }

    // MARK: - Animation Signal

    /// Called by the SpriteKit scene (or a view) when the battle animation finishes.
    @MainActor
    func animationDidComplete() {
        animationComplete = true
        animationContinuation?.resume()
        animationContinuation = nil
    }

    // MARK: - Typewriter Effect

    /// Reveals narrationDisplayed one character at a time with a 30ms delay per character.
    @MainActor
    func startTypewriterEffect() async {
        guard let result = battleResult else { return }
        narrationDisplayed = ""
        for character in result.narration {
            narrationDisplayed.append(character)
            try? await Task.sleep(nanoseconds: 30_000_000) // 30ms
        }
    }

    // MARK: - Rematch

    func rematch() {
        // Resume any suspended animation continuation so the old startBattle()
        // task can exit cleanly after its Task.isCancelled guard fires.
        animationContinuation?.resume()
        animationContinuation = nil

        phase = .intro
        battleResult = nil
        narrationDisplayed = ""
        animationComplete = false
        errorMessage = nil
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

    // MARK: - Private Helpers

    /// Wraps the BattleService call, swallowing errors and returning nil on failure.
    /// Stores a user-facing errorMessage if the fetch fails so the UI can show a badge.
    /// Also sets `lastFetchErrorWasNetworkUnavailable` so the orchestrator can decide
    /// whether the resulting local fallback should be flagged as "offline".
    @MainActor
    private func fetchResultIgnoringErrors() async -> BattleResult? {
        // Reset every call so a previous offline error doesn't leak into a
        // subsequent successful retry's failure mode.
        lastFetchErrorWasNetworkUnavailable = false
        do {
            let result = try await BattleService.shared.fetchBattleResult(
                fighter1: fighter1,
                fighter2: fighter2,
                environment: environment,
                arenaEffectsEnabled: arenaEffectsEnabled,
                tournamentContext: tournamentContext
            )
            return result
        } catch let battleError as BattleError {
            errorMessage = battleError.errorDescription
            if battleError == .networkUnavailable {
                lastFetchErrorWasNetworkUnavailable = true
            }
            return nil
        } catch {
            errorMessage = BattleError.serverError.errorDescription
            return nil
        }
    }

    /// Suspends until `animationDidComplete()` is called (or returns immediately if already complete).
    @MainActor
    private func waitForAnimation() async {
        guard !animationComplete else { return }
        await withCheckedContinuation { continuation in
            animationContinuation = continuation
        }
    }
}
