import XCTest
import SpriteKit
@testable import WhoWouldWin

final class RetroBattleTests: XCTestCase {
    func testFirstAcceptedResultSurvivesALateCloudAnswer() {
        var state = RetroBattleLifecycle<String>()
        let id = state.begin()!
        XCTAssertNil(state.begin(), "View re-entry must not start another fetch.")
        XCTAssertTrue(state.accept("local winner", for: id))
        XCTAssertFalse(state.accept("late different winner", for: id))
        XCTAssertEqual(state.result, "local winner")
        XCTAssertTrue(state.finish(id))
        XCTAssertFalse(state.finish(id), "Skip and scene completion cannot both settle.")
    }

    func testRematchRejectsStaleResultsAndCompletion() {
        var state = RetroBattleLifecycle<String>()
        let oldID = state.begin()!
        state.reset()
        let newID = state.begin()!
        XCTAssertNotEqual(oldID, newID)
        XCTAssertFalse(state.accept("old result", for: oldID))
        XCTAssertFalse(state.finish(newID), "An animation cannot finish before an answer exists.")
        XCTAssertTrue(state.accept("new result", for: newID))
        XCTAssertFalse(state.finish(oldID))
        XCTAssertTrue(state.finish(newID))
    }

    func testDismissalRejectsBothPendingAnswerAndFinish() {
        var state = RetroBattleLifecycle<String>()
        let id = state.begin()!
        state.cancel()
        XCTAssertFalse(state.accept("late result", for: id))
        XCTAssertFalse(state.finish(id))
        XCTAssertNil(state.begin())
    }

    func testBackgroundPauseDoesNotFastForwardOrReplayTime() {
        var clock = RetroPresentationClock()
        XCTAssertEqual(clock.tick(10, active: true), 0)
        XCTAssertEqual(clock.tick(10.04, active: true), 0.04, accuracy: 0.0001)
        clock.pause()
        XCTAssertEqual(clock.tick(1000, active: false), 0.04, accuracy: 0.0001)
        XCTAssertEqual(clock.tick(1010, active: true), 0.04, accuracy: 0.0001)
        XCTAssertEqual(clock.tick(1010.04, active: true), 0.08, accuracy: 0.0001)
    }

    func testOutcomeUsesIDsRatherThanAnAssumedLeftWinner() {
        let lion = Animals.lion, tiger = Animals.tiger
        let answer = result(winner: tiger.id)
        XCTAssertEqual(RetroBattleOutcome.solo(answer, first: lion, second: tiger), .victory(side: 1, mvpID: tiger.id))
        XCTAssertEqual(RetroBattleOutcome.solo(answer, first: tiger, second: lion), .victory(side: 0, mvpID: tiger.id))
        XCTAssertEqual(RetroBattleOutcome.solo(result(winner: "draw"), first: lion, second: tiger), .draw)
        XCTAssertNil(RetroBattleOutcome.solo(result(winner: "not-a-participant"), first: lion, second: tiger))
    }

    func testMeleeOutcomeRetainsWinningTeamAndMVP() {
        let answer = MeleeResult(winningTeam: .B, narration: "Team B wins.", funFact: "A fact.", mvp: "tiger", teamAHealth: 24, teamBHealth: 73)
        XCTAssertEqual(RetroBattleOutcome.team(answer), .victory(side: 1, mvpID: "tiger"))
    }

    @MainActor
    func testNormalModelWaitsForSceneAndKeepsExactResult() async {
        let vm = BattleViewModel(fighter1: Animals.lion, fighter2: Animals.tiger)
        let answer = result(winner: Animals.tiger.id)
        vm.forcedResult = answer
        await vm.startBattle()
        XCTAssertEqual(vm.battleResult, answer)
        XCTAssertFalse(vm.animationComplete)
        let id = vm.presentationID
        vm.animationDidComplete(for: id)
        XCTAssertTrue(vm.animationComplete)
        XCTAssertEqual(vm.battleResult?.winnerHealthPercent, 67)
        XCTAssertEqual(vm.battleResult?.loserHealthPercent, 19)
        vm.animationDidComplete(for: id)
        XCTAssertEqual(vm.battleResult, answer)
    }

    @MainActor
    func testOldSceneCannotCompleteNewModelSession() async {
        let vm = BattleViewModel(fighter1: Animals.lion, fighter2: Animals.tiger)
        vm.forcedResult = result(winner: Animals.lion.id)
        await vm.startBattle()
        let oldID = vm.presentationID
        vm.rematch()
        vm.forcedResult = result(winner: Animals.tiger.id)
        await vm.startBattle()
        vm.animationDidComplete(for: oldID)
        XCTAssertFalse(vm.animationComplete)
        vm.animationDidComplete(for: vm.presentationID)
        XCTAssertTrue(vm.animationComplete)
        XCTAssertEqual(vm.battleResult?.winner, Animals.tiger.id)
    }

    @MainActor
    func testQuickModeDoesNotWaitForAHiddenScene() async {
        let vm = BattleViewModel(fighter1: Animals.lion, fighter2: Animals.tiger, isQuickMode: true)
        vm.forcedResult = result(winner: Animals.tiger.id)
        await vm.startBattle()
        XCTAssertTrue(vm.animationComplete)
        XCTAssertEqual(vm.battleResult?.winner, Animals.tiger.id)
    }

    @MainActor
    func testRegularDrawPreservesTheAcceptedStoryAndFinalData() async {
        let vm = BattleViewModel(fighter1: Animals.lion, fighter2: Animals.tiger)
        let answer = result(winner: "draw")
        vm.forcedResult = answer
        await vm.startBattle()
        XCTAssertEqual(vm.battleResult, answer)
        XCTAssertEqual(RetroBattleOutcome.solo(vm.battleResult, first: Animals.lion, second: Animals.tiger), .draw)
        vm.animationDidComplete(for: vm.presentationID)
        XCTAssertEqual(vm.battleResult, answer)
    }

    @MainActor
    func testQuickTournamentAcceptsItsExistingTiebreakOnceBeforeRevealing() async {
        let vm = BattleViewModel(fighter1: Animals.lion, fighter2: Animals.tiger,
                                 isQuickMode: true, tournamentContext: "Quarterfinal")
        var draw = result(winner: "draw")
        draw.isOfflineFallback = true
        vm.forcedResult = draw
        await vm.startBattle()
        let accepted = vm.battleResult
        XCTAssertTrue(vm.animationComplete)
        XCTAssertTrue([Animals.lion.id, Animals.tiger.id].contains(accepted?.winner ?? ""))
        XCTAssertEqual(accepted?.isOfflineFallback, true)
        XCTAssertNotEqual(accepted?.narration, draw.narration)
        await vm.startBattle()
        vm.animationDidComplete(for: vm.presentationID)
        XCTAssertEqual(vm.battleResult, accepted, "View re-entry must not run another random tournament tiebreak.")
    }

    @MainActor
    func testReducedMotionDrawFinishesOnceWithoutAHealthSimulation() async {
        let scene = RetroBattleScene(sessionID: UUID(), teamA: [Animals.lion],
                                     teamB: [Animals.tiger], environment: .grassland)
        scene.didMove(to: SKView(frame: .zero))
        scene.reduceMotion = true
        let done = expectation(description: "accepted draw completed")
        done.assertForOverFulfill = true
        var captions: [String] = []
        scene.onCaption = { captions.append($0) }
        scene.onFinished = { done.fulfill() }
        scene.skip() // No result has been accepted yet.
        scene.accept(.draw)
        for frame in 0...8 { scene.update(Double(frame) * 0.1) }
        scene.skip()
        await fulfillment(of: [done], timeout: 1)
        XCTAssertTrue(captions.contains("The result is ready."))
        scene.stop()
    }

    @MainActor
    func testEveryFourVersusFourParticipantActsBeforeCompletion() async {
        let first = [Animals.lion, Animals.gorilla, Animals.wolf, Animals.tiger]
        let second = [Animals.elephant, Animals.great_white_shark, Animals.bald_eagle, Animals.t_rex]
        let scene = RetroBattleScene(sessionID: UUID(), teamA: first, teamB: second, environment: .grassland)
        scene.didMove(to: SKView(frame: .zero))
        var captions: [String] = []
        let done = expectation(description: "whole roster completed")
        done.assertForOverFulfill = true
        scene.onCaption = { captions.append($0) }
        scene.onFinished = { done.fulfill() }
        scene.accept(.victory(side: 1, mvpID: Animals.bald_eagle.id))
        for frame in 0...120 { scene.update(Double(frame) * 0.1) }
        scene.skip()
        await fulfillment(of: [done], timeout: 1)
        for animal in first + second {
            XCTAssertTrue(captions.contains("\(animal.name) makes a move!"), "Missing turn for \(animal.name)")
        }
        scene.stop()
    }

    @MainActor
    func testStoppedSceneDoesNotDeliverAnAlreadyQueuedCallback() async {
        let scene = RetroBattleScene(sessionID: UUID(), teamA: [Animals.lion],
                                     teamB: [Animals.tiger], environment: .grassland)
        let cancelled = expectation(description: "dismissed scene callback")
        cancelled.isInverted = true
        scene.onFinished = { cancelled.fulfill() }
        scene.accept(.victory(side: 0, mvpID: Animals.lion.id))
        scene.skip()
        scene.stop()
        await fulfillment(of: [cancelled], timeout: 0.1)
    }

    @MainActor
    func testRewardClaimIsOncePerActualBattle() {
        let first = UUID(), rematch = UUID()
        XCTAssertTrue(RetroBattleSettlement.claim(first))
        XCTAssertFalse(RetroBattleSettlement.claim(first))
        XCTAssertTrue(RetroBattleSettlement.claim(rematch))
    }

    @MainActor
    func testEveryExistingArenaHasNativeArtwork() {
        for arena in BattleEnvironment.allCases {
            let image = RetroArenaArtwork.image(for: arena)
            XCTAssertEqual(image.size.width, 480)
            XCTAssertEqual(image.size.height, 280)
            XCTAssertNotNil(image.cgImage, "Missing native arena: \(arena.rawValue)")
        }
    }

    private func result(winner: String) -> BattleResult {
        BattleResult(winner: winner, narration: "The accepted result.", funFact: "An accepted fact.", winnerHealthPercent: 67, loserHealthPercent: 19)
    }
}
