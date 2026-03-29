import Foundation
import Combine

class BattleViewModel: ObservableObject {

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

    // Continuation used to signal when the SpriteKit animation finishes
    private var animationContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
    }

    // MARK: - Main Battle Flow

    /// Main battle orchestration:
    /// 1. Stay in .intro for 2 seconds
    /// 2. Transition to .animating
    /// 3. Fire off API call AND wait for animation to finish simultaneously (async let)
    /// 4. When BOTH complete → move to .revealing
    /// 5. If API fails → use offline fallback from BattleService
    /// 6. Run typewriter effect on narration
    /// 7. → .complete
    @MainActor
    func startBattle() async {
        // Step 1: Hold in intro briefly for dramatic effect
        phase = .intro
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Step 2: Kick off animation
        phase = .animating
        animationComplete = false

        // Step 3: Fire API call and wait for animation simultaneously
        async let apiResult: BattleResult? = fetchResultIgnoringErrors()
        async let _: Void = waitForAnimation()

        // Await both — neither can proceed until both are done
        let (fetchedResult, _) = await (apiResult, ())

        // Step 4: Pick result — use fetched or fall back
        let result: BattleResult
        if let fetchedResult {
            result = fetchedResult
        } else {
            result = await BattleService.shared.generateFallbackResult(
                fighter1: fighter1,
                fighter2: fighter2
            )
        }

        battleResult = result
        phase = .revealing

        // Step 6: Typewriter effect on narration
        await startTypewriterEffect()

        // Step 7: Complete
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
        phase = .intro
        battleResult = nil
        narrationDisplayed = ""
        animationComplete = false
        animationContinuation = nil
    }

    // MARK: - Private Helpers

    /// Wraps the BattleService call, swallowing errors and returning nil on failure.
    /// Stores a user-facing errorMessage if the fetch fails so the UI can show a badge.
    @MainActor
    private func fetchResultIgnoringErrors() async -> BattleResult? {
        do {
            let result = try await BattleService.shared.fetchBattleResult(
                fighter1: fighter1,
                fighter2: fighter2
            )
            return result
        } catch let battleError as BattleError {
            errorMessage = battleError.errorDescription
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
