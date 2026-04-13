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

    // Continuation used to signal when the SpriteKit animation finishes
    private var animationContinuation: CheckedContinuation<Void, Never>?

    // MARK: - Init

    init(fighter1: Animal, fighter2: Animal, environment: BattleEnvironment = .grassland) {
        self.fighter1 = fighter1
        self.fighter2 = fighter2
        self.environment = environment
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
        if let r = fetchedResult {
            result = r
        } else {
            result = await BattleService.shared.generateFallbackResult(
                fighter1: fighter1,
                fighter2: fighter2,
                environment: environment
            )
        }
        guard !Task.isCancelled else { return }

        battleResult = result

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

    // MARK: - Private Helpers

    /// Wraps the BattleService call, swallowing errors and returning nil on failure.
    /// Stores a user-facing errorMessage if the fetch fails so the UI can show a badge.
    @MainActor
    private func fetchResultIgnoringErrors() async -> BattleResult? {
        do {
            let result = try await BattleService.shared.fetchBattleResult(
                fighter1: fighter1,
                fighter2: fighter2,
                environment: environment
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
