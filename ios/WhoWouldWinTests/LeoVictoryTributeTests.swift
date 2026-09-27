import XCTest
import CoreGraphics
@testable import WhoWouldWin

final class LeoVictoryTributeTests: XCTestCase {
    func testMemorialIdentityRequiresTheBuiltInGreatDane() {
        XCTAssertTrue(LeoTributePlayback.isLeonidas(Animals.great_dane))
        XCTAssertFalse(LeoTributePlayback.isLeonidas(Animals.lion))
        let custom = Animal(id: "great_dane", name: "Great Dane", emoji: "🐕", category: .pets,
                            pixelColor: "#C8A47A", size: 5, isCustom: true)
        XCTAssertFalse(LeoTributePlayback.isLeonidas(custom), "Typed lookalikes must not inherit the memorial")
        let renamed = Animal(id: "another_dog", name: "Great Dane", emoji: "🐕", category: .pets,
                             pixelColor: "#C8A47A", size: 5)
        XCTAssertFalse(LeoTributePlayback.isLeonidas(renamed))
    }

    func testRapidTapsNeverQueueOrRestartHappyClipsAndThirdTapReplacesIt() {
        var state = LeoTributePlayback()
        XCTAssertNil(state.message)
        state.tap(reduceMotion: false)
        let happyGeneration = state.generation
        XCTAssertEqual(state.animation, .happy)
        XCTAssertEqual(state.message, "Good boy, Leo!")
        state.tap(reduceMotion: false)
        XCTAssertEqual(state.generation, happyGeneration, "A rapid second tap must not rewind the active pose")
        state.tap(reduceMotion: false)
        XCTAssertEqual(state.animation, .goodnight)
        XCTAssertGreaterThan(state.generation, happyGeneration)
        XCTAssertEqual(state.message, "Goodnight, handsome.")
        let thirdTap = state
        for _ in 0..<100 { state.tap(reduceMotion: false) }
        XCTAssertEqual(state, thirdTap, "Further taps must not create more work or replay the ending")
        XCTAssertFalse(state.finish(generation: happyGeneration), "The cancelled happy task cannot finish its replacement")
        XCTAssertTrue(state.finish(generation: thirdTap.generation))
        XCTAssertEqual(state.settledFrame, LeoTributeFrame(pose: .idle))
        XCTAssertEqual(state.message, "Goodnight, handsome.")
    }

    func testInterruptionSettlesWithoutReplayingButAnExplicitSecondTapStillWorks() {
        var state = LeoTributePlayback()
        state.tap(reduceMotion: false)
        let cancelledGeneration = state.generation
        state.stop()
        XCTAssertNil(state.animation)
        XCTAssertEqual(state.tapCount, 1)
        XCTAssertEqual(state.message, "Good boy, Leo!")
        XCTAssertEqual(state.settledFrame, LeoTributeFrame(pose: .reaction))
        XCTAssertFalse(state.finish(generation: cancelledGeneration))
        let stopped = state
        state.stop()
        XCTAssertEqual(state, stopped, "Repeated inactive lifecycle callbacks are idempotent")
        state.tap(reduceMotion: false)
        XCTAssertEqual(state.animation, .happy, "Only a fresh user tap may start a new happy clip")
        XCTAssertGreaterThan(state.generation, cancelledGeneration)
        XCTAssertEqual(LeoTributePlayback().tapCount, 0, "A newly identified result starts independently")
    }

    func testReducedMotionPreservesMessagesAndHappyArtworkWithNoClip() {
        var state = LeoTributePlayback()
        for expectedCount in 1...3 {
            state.tap(reduceMotion: true)
            XCTAssertEqual(state.tapCount, expectedCount)
            XCTAssertNil(state.animation)
            XCTAssertEqual(state.settledFrame.liftFraction, 0)
            XCTAssertEqual(state.settledFrame.leanDegrees, 0)
            XCTAssertEqual(state.settledFrame.heartOpacity, 0)
        }
        XCTAssertEqual(state.message, "Goodnight, handsome.")
        var toggled = LeoTributePlayback()
        toggled.tap(reduceMotion: false)
        let oldGeneration = toggled.generation
        toggled.stop() // The reactive preference/scene/visibility change consumes the active clip.
        XCTAssertNil(toggled.animation)
        XCTAssertFalse(toggled.finish(generation: oldGeneration))
    }

    func testHappySequenceUsesAuthoredPosesAndFiniteBoundedMotionWhileGoodnightStaysGrounded() {
        var poses = Set<String>()
        var hasHop = false
        var hasHearts = false
        for step in 0...180 {
            let time = Double(step) / 100
            let happy = LeoTributeFrame.sample(time: time, kind: .happy)
            poses.insert(happy.pose.rawValue)
            hasHop = hasHop || happy.liftFraction < -0.04
            hasHearts = hasHearts || happy.heartOpacity > 0.5
            XCTAssertTrue(happy.liftFraction.isFinite && happy.leanDegrees.isFinite && happy.heartOpacity.isFinite)
            XCTAssertGreaterThanOrEqual(happy.liftFraction, -0.08)
            XCTAssertLessThanOrEqual(happy.liftFraction, 0)
            XCTAssertLessThanOrEqual(abs(happy.leanDegrees), 3)
            XCTAssertGreaterThanOrEqual(happy.heartOpacity, 0)
            XCTAssertLessThanOrEqual(happy.heartOpacity, 0.9)
            let gentle = LeoTributeFrame.sample(time: time, kind: .goodnight)
            XCTAssertEqual(gentle.liftFraction, 0)
            XCTAssertEqual(gentle.heartOpacity, 0)
            XCTAssertLessThanOrEqual(abs(gentle.leanDegrees), 2)
        }
        XCTAssertEqual(poses, Set(["anticipation", "attack", "reaction"]))
        XCTAssertTrue(hasHop)
        XCTAssertTrue(hasHearts)
        for time: Double in [1.8, 2, 1000, .greatestFiniteMagnitude, .nan, .infinity, -.infinity, -1] {
            XCTAssertEqual(LeoTributeFrame.sample(time: time, kind: .happy), LeoTributeFrame(pose: .reaction))
            XCTAssertEqual(LeoTributeFrame.sample(time: time, kind: .goodnight), LeoTributeFrame(pose: .idle))
        }
    }

    func testSpeechBubbleFitsBothTeamRosterEdgesWithoutShrinkingTheText() throws {
        for viewport in [CGRect(x: 0, y: 0, width: 393, height: 852),
                         CGRect(x: 230, y: 0, width: 340, height: 700),
                         CGRect(x: 0, y: 0, width: 180, height: 500)] {
            for x in [viewport.minX + 16, viewport.midX - 27, viewport.maxX - 70] {
                let bounds = CGRect(x: x, y: 250, width: 54, height: 54)
                let placement = try XCTUnwrap(LeoTributeBubblePlacement.make(bounds: bounds, viewport: viewport))
                let center = bounds.midX + placement.offsetX
                XCTAssertGreaterThanOrEqual(center - placement.width / 2, viewport.minX + 16)
                XCTAssertLessThanOrEqual(center + placement.width / 2, viewport.maxX - 16)
                XCTAssertEqual(placement.width, min(220, viewport.width - 32))
            }
        }
        XCTAssertNil(LeoTributeBubblePlacement.make(bounds: .zero, viewport: CGRect(x: 0, y: 0, width: 393, height: 852)))
        XCTAssertNil(LeoTributeBubblePlacement.make(bounds: CGRect(x: 0, y: 0, width: 54, height: 54), viewport: .infinite))
        XCTAssertNil(LeoTributeBubblePlacement.make(bounds: CGRect(x: 0, y: 0, width: 54, height: 54), viewport: CGRect(x: 0, y: 0, width: 32, height: 700)))
    }
}
