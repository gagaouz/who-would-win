import XCTest
import CoreGraphics
@testable import WhoWouldWin

final class ArcadeMotionTests: XCTestCase {
    private func assertCalm(_ frame: ArcadeCreatureFrame, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(frame.lift.isFinite && frame.lean.isFinite && frame.heightScale.isFinite && frame.sparkle.isFinite,
                      "An ambient sample must never poison the view transform", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.lift, -2.1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.lift, 0, "Keep the character grounded", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(frame.lean), 1.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.heightScale, 1, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.heightScale, 1.025, "Breathing must not visibly stretch the anatomy", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.sparkle, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.sparkle, 0.9, file: file, line: line)
    }

    func testAmbientMotionIsBoundedAndSpendsMostOfItsTimeCompletelyStill() {
        // Observe several cycles at the actual clock's12Hz sampling frequency.
        // This is a behavioral calmness budget, not a duplicate of the curve.
        for mood in [ArcadeCreatureMood.idle, .winner] {
            var restingSamples = 0
            var longestRest = 0
            var currentRest = 0
            var movingSamples = 0
            for step in 0..<384 {
                let frame = ArcadeCreatureFrame.sample(time: Double(step) / 12, mood: mood)
                assertCalm(frame)
                if frame == .resting {
                    restingSamples += 1
                    currentRest += 1
                    longestRest = max(longestRest, currentRest)
                } else {
                    movingSamples += 1
                    currentRest = 0
                }
            }
            XCTAssertGreaterThan(movingSamples, 0, "Enabled featured artwork must actually move")
            XCTAssertGreaterThan(Double(restingSamples) / 384, 0.60, "The page should be still for most of its lifetime")
            XCTAssertGreaterThanOrEqual(Double(longestRest) / 12, 3.5, "A brief pause between constant flourishes is not a calm rest interval")
        }
    }

    func testIdleBreathesInPlaceWhileWinnerAddsASeparateShortGlint() {
        var idleBreaths = 0
        var winnerPoses = 0
        var glints = 0
        var simultaneousFlourishes = 0
        for step in 0..<192 {
            let time = Double(step) / 24
            let idle = ArcadeCreatureFrame.sample(time: time, mood: .idle)
            let winner = ArcadeCreatureFrame.sample(time: time, mood: .winner)
            XCTAssertEqual(idle.lift, 0)
            XCTAssertEqual(idle.lean, 0)
            XCTAssertEqual(idle.sparkle, 0, "Ordinary artwork must not look like a winner")
            if idle.heightScale > 1.005 { idleBreaths += 1 }
            if winner.lift < -0.5 { winnerPoses += 1 }
            if winner.sparkle > 0 {
                glints += 1
                if winner.lift != 0 || winner.lean != 0 || winner.heightScale != 1 { simultaneousFlourishes += 1 }
            }
        }
        XCTAssertGreaterThan(idleBreaths, 0)
        XCTAssertGreaterThan(winnerPoses, 0)
        XCTAssertGreaterThan(glints, 0, "Winner artwork should have a visible celebratory accent")
        XCTAssertLessThan(Double(glints) / 192, 0.15, "The accent must be brief, not a continuous flash")
        XCTAssertEqual(simultaneousFlourishes, 0, "Separate the breath/pose and glint rather than stacking animation")
    }

    func testInvalidTimeAndDelayRestSafelyAndExtremeFiniteSamplesStayBounded() {
        for mood in [ArcadeCreatureMood.idle, .winner] {
            for time: Double in [.nan, .infinity, -.infinity, -.greatestFiniteMagnitude, -1, 0] {
                XCTAssertEqual(ArcadeCreatureFrame.sample(time: time, mood: mood), .resting)
            }
            for delay: Double in [.nan, .infinity, -.infinity] {
                XCTAssertEqual(ArcadeCreatureFrame.sample(time: 2.4, mood: mood, delay: delay), .resting)
            }
            for time: Double in [.leastNonzeroMagnitude, 0.1, 2.4, 5, 1_000_000, .greatestFiniteMagnitude] {
                assertCalm(ArcadeCreatureFrame.sample(time: time, mood: mood))
                assertCalm(ArcadeCreatureFrame.sample(time: time, mood: mood, delay: time / 2))
                XCTAssertEqual(ArcadeCreatureFrame.sample(time: time, mood: mood, delay: -10),
                               ArcadeCreatureFrame.sample(time: time, mood: mood), "A negative delay must not fast-forward the animation")
            }
        }
    }

    func testStaggerWaitsThenPreservesTheSameMotionWithoutAccumulation() {
        let delay = 3.5
        for mood in [ArcadeCreatureMood.idle, .winner] {
            for time in [0.0, 1, 2.4, delay] {
                XCTAssertEqual(ArcadeCreatureFrame.sample(time: time, mood: mood, delay: delay), .resting)
            }
            XCTAssertNotEqual(ArcadeCreatureFrame.sample(time: 2.4, mood: mood), .resting)
            for time in [2.0, 2.5, 5.0, 6.0, 10.0, 13.0] {
                XCTAssertEqual(ArcadeCreatureFrame.sample(time: time + delay, mood: mood, delay: delay),
                               ArcadeCreatureFrame.sample(time: time, mood: mood), "Stagger changes start time, not the character's motion")
            }
            let first = ArcadeCreatureFrame.sample(time: 2.5, mood: mood)
            _ = ArcadeCreatureFrame.sample(time: 10_000, mood: mood)
            XCTAssertEqual(ArcadeCreatureFrame.sample(time: 2.5, mood: mood), first,
                           "Sampling after background time cannot leave accumulated motion behind")
        }
    }

    func testEveryCycleReturnsToRestWithoutAVisibleBoundaryJump() {
        for mood in [ArcadeCreatureMood.idle, .winner] {
            for delay in [0.0, 0.65, 3.5] {
                for cycle in 1...8 {
                    let boundary = Double(cycle) * 8 + delay
                    for offset in [-0.1, 0, 0.1] {
                        XCTAssertEqual(ArcadeCreatureFrame.sample(time: boundary + offset, mood: mood, delay: delay), .resting,
                                       "Wrapping a cycle must occur during a resting interval")
                    }
                }
            }
        }
    }

    func testEveryActivationFlagCombinationRequiresVisibleActiveAccessibleMotion() {
        let bounds = CGRect(x: 20, y: 40, width: 80, height: 100)
        let viewport = CGRect(x: 0, y: 0, width: 200, height: 300)
        var allowedCombinations = 0
        for enabled in [false, true] {
            for reduced in [false, true] {
                for active in [false, true] {
                    for appeared in [false, true] {
                        let allowed = ArcadeMotionVisibility.canAnimate(enabled: enabled, reduceMotion: reduced,
                            sceneActive: active, appeared: appeared, bounds: bounds, viewport: viewport)
                        if enabled && !reduced && active && appeared {
                            XCTAssertTrue(allowed)
                        } else {
                            XCTAssertFalse(allowed, "Covered, inaccessible, background or absent content must not animate")
                        }
                        if allowed { allowedCombinations += 1 }
                    }
                }
            }
        }
        XCTAssertEqual(allowedCombinations, 1)
    }

    private func visible(_ bounds: CGRect, in viewport: CGRect) -> Bool {
        ArcadeMotionVisibility.canAnimate(enabled: true, reduceMotion: false, sceneActive: true,
                                          appeared: true, bounds: bounds, viewport: viewport)
    }

    func testClippingRequiresAMajorityOfTheArtworkAreaInEitherScrollDirection() {
        let viewport = CGRect(x: 0, y: 0, width: 100, height: 100)
        XCTAssertTrue(visible(CGRect(x: 10, y: 10, width: 80, height: 80), in: viewport))
        for distance in [-51.0, -50, 50, 51] {
            XCTAssertFalse(visible(CGRect(x: distance, y: 0, width: 100, height: 100), in: viewport))
            XCTAssertFalse(visible(CGRect(x: 0, y: distance, width: 100, height: 100), in: viewport))
        }
        for distance in [-49.0, 49] {
            XCTAssertTrue(visible(CGRect(x: distance, y: 0, width: 100, height: 100), in: viewport))
            XCTAssertTrue(visible(CGRect(x: 0, y: distance, width: 100, height: 100), in: viewport))
        }
        XCTAssertTrue(visible(CGRect(x: 25, y: 25, width: 100, height: 100), in: viewport))
        XCTAssertFalse(visible(CGRect(x: 30, y: 30, width: 100, height: 100), in: viewport),
                       "Being mostly visible along both axes is insufficient when the visible area is under half")
        XCTAssertFalse(visible(CGRect(x: 100, y: 0, width: 100, height: 100), in: viewport), "Touching an edge is not visible")
        XCTAssertFalse(visible(CGRect(x: 500, y: 500, width: 100, height: 100), in: viewport))
        XCTAssertTrue(visible(CGRect(x: 225, y: 425, width: 100, height: 100),
                              in: CGRect(x: 200, y: 400, width: 100, height: 100)), "Global viewport origins must not affect the threshold")
    }

    func testInvalidOrEmptyGeometryNeverStartsATimeline() {
        let normal = CGRect(x: 0, y: 0, width: 100, height: 100)
        let invalid: [CGRect] = [.zero, .null, .infinite,
            CGRect(x: 0, y: 0, width: 0, height: 100), CGRect(x: 0, y: 0, width: 100, height: 0),
            // CGRect.width/height normalize negative sizes. Place the raw
            // invalid rectangles over the viewport so rejection is intentional.
            CGRect(x: 100, y: 0, width: -100, height: 100), CGRect(x: 0, y: 100, width: 100, height: -100),
            CGRect(x: CGFloat.nan, y: 0, width: 100, height: 100),
            CGRect(x: 0, y: CGFloat.infinity, width: 100, height: 100),
            CGRect(x: 0, y: 0, width: CGFloat.nan, height: 100),
            CGRect(x: 0, y: 0, width: 100, height: CGFloat.infinity)]
        for rectangle in invalid {
            XCTAssertFalse(visible(rectangle, in: normal), "Invalid artwork bounds must pause")
            XCTAssertFalse(visible(normal, in: rectangle), "An invalid viewport must pause")
        }
    }
}
