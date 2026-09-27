import XCTest

/// The real navigation and battle loop, driven by explicit local service
/// fixtures. A successful fixture and an offline fallback are separate cases.
final class WhoWouldWinUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchFixture(_ scenario: String) {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment["AVA_UI_TESTING"] = "1"
        app.launchEnvironment["AVA_FIXTURE_SCENARIO"] = scenario
        app.launchEnvironment["AVA_BLOCK_EXTERNAL_SERVICES"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10),
                      "The app must confirm fixture mode before any interaction")
    }

    private func finishSurpriseBattle() {
        let surprise = app.buttons["home.surpriseBattle"]
        XCTAssertTrue(surprise.waitForExistence(timeout: 10), "Home screen should show Surprise Me")
        screenshot("01_home")
        surprise.tap()

        let cheer = app.buttons["battle.cheer1"]
        XCTAssertTrue(cheer.waitForExistence(timeout: 10), "The first fighter must be available to cheer for")
        screenshot("02_battle")
        cheer.tap()

        // Result screen: one of the two primary buttons appears.
        let result = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'CHALLENGER' OR label CONTAINS 'MATCH-UP'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 60), "Battle should reach the result screen")
        screenshot("03_result")
    }

    func testFixtureBattleReachesResultWithoutOfflineFallback() {
        launchFixture("battle-success")
        finishSurpriseBattle()
        let fixtureNarration = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Fixture battle completed.")).firstMatch
        XCTAssertTrue(fixtureNarration.waitForExistence(timeout: 10),
                      "A fallback result must not falsely pass the successful-response case")
        XCTAssertFalse(app.descendants(matching: .any)["battle.offlineIndicator"].exists)
    }

    func testOfflineBattleStillReachesResult() {
        launchFixture("offline")
        finishSurpriseBattle()
        XCTAssertTrue(app.descendants(matching: .any)["battle.offlineIndicator"].waitForExistence(timeout: 10),
                      "The offline scenario must exercise and identify the local fallback")
        XCTAssertFalse(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Fixture battle completed.")).firstMatch.exists)
    }
}

/// Exercises the real home carousel and navigation with local battle responses.
/// Matchups may be random; assertions follow the displayed names rather than a seed.
final class HomeMatchupUITests: XCTestCase {
    private let app = XCUIApplication()
    private var hero: XCUIElement { app.buttons["home.heroBattle"] }
    private var page: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "home.matchupPage").firstMatch
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchHome() {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "battle-success"]
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10))
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(hero.isHittable)
        waitForPage(1)
    }

    private func waitForPage(_ index: Int) {
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "\(index) of 5"), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed,
                       "The page indicator must follow the user-selected matchup")
    }

    private func displayedNames() throws -> [String] {
        let value = try XCTUnwrap(hero.value as? String)
        let names = value.components(separatedBy: " versus ")
        XCTAssertEqual(names.count, 2, "Expose both displayed fighters in left-to-right order")
        XCTAssertFalse(names.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
        XCTAssertNotEqual(names.first, names.last, "A fighter must face a different opponent")
        return names
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSwipeThenTapStartsExactlyTheDisplayedMatchup() throws {
        launchHome()
        let first = try displayedNames()
        capture("home_matchup_first")
        hero.swipeLeft()
        waitForPage(2)
        let second = try displayedNames()
        XCTAssertFalse(app.buttons["battle.cheer1"].exists, "Swiping must not launch a battle")
        capture("home_matchup_swiped")

        hero.swipeRight()
        waitForPage(1)
        XCTAssertEqual(try displayedNames(), first, "Returning to a page must retain its fighters")
        hero.swipeLeft()
        waitForPage(2)
        XCTAssertEqual(try displayedNames(), second)
        hero.tap()

        let left = app.buttons["battle.cheer1"]
        let right = app.buttons["battle.cheer2"]
        XCTAssertTrue(left.waitForExistence(timeout: 10))
        XCTAssertEqual(left.label, "Cheer for \(second[0])")
        XCTAssertEqual(right.label, "Cheer for \(second[1])")
        capture("home_matchup_exact_battle")
        let narration = app.staticTexts["battle.narration"]
        XCTAssertTrue(narration.waitForExistence(timeout: 25))
        XCTAssertEqual(narration.label, "Fixture battle completed.")
        XCTAssertFalse(app.descendants(matching: .any)["battle.offlineIndicator"].exists)
    }

    func testCarouselArrowsWrapAndNormalPickerStillSelectsAFighter() throws {
        launchHome()
        let first = try displayedNames()
        let previous = app.buttons["home.previousMatchup"]
        let next = app.buttons["home.nextMatchup"]
        XCTAssertTrue(previous.isHittable)
        XCTAssertTrue(next.isHittable)
        previous.tap()
        waitForPage(5)
        _ = try displayedNames()
        next.tap()
        waitForPage(1)
        XCTAssertEqual(try displayedNames(), first)
        for index in 2...5 {
            next.tap()
            waitForPage(index)
            _ = try displayedNames()
        }
        next.tap()
        waitForPage(1)
        XCTAssertEqual(try displayedNames(), first)
        XCTAssertFalse(app.buttons["battle.cheer1"].exists)

        let picker = app.buttons["home.pickFighters"]
        for _ in 0..<5 where !picker.isHittable { app.swipeUp() }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        let search = app.textFields["Search or create ANY creature..."]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["picker.myFighters"].exists)
        capture("home_matchup_normal_picker")
        search.tap()
        search.typeText("Lion")
        let lion = app.buttons.matching(NSPredicate(format: "label == %@", "Lion")).firstMatch
        XCTAssertTrue(lion.waitForExistence(timeout: 5))
        lion.tap()
        let selected = app.buttons.matching(NSPredicate(format: "label == %@ AND value == %@", "Lion", "Selected")).firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 5), "The normal roster selection must remain functional")
        capture("home_matchup_picker_selected")
        let remove = app.buttons["Remove Lion"]
        XCTAssertTrue(remove.isHittable)
        remove.tap()
        XCTAssertTrue(selected.waitForNonExistence(timeout: 5), "Removing a selected fighter must clear its roster selection")
        capture("home_matchup_picker_cleared")
    }
}

/// Native arena composition and lifecycle checks with local answers. These
/// fixtures use the production stage, view models, result views and rematch.
final class RetroBattleUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String) {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "battle-success", "AVA_FIXTURE_SCREEN": screen]
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10))
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    func testFourVersusFourShowsBothRostersAndRealResult() {
        launch("melee")
        let cheer = app.buttons["battle.cheer1"]
        XCTAssertTrue(cheer.waitForExistence(timeout: 10))
        XCTAssertTrue(cheer.label.contains("Lion"))
        XCTAssertTrue(cheer.label.contains("Gorilla"))
        XCTAssertTrue(cheer.label.contains("Wolf"))
        XCTAssertTrue(cheer.label.contains("Tiger"))
        let other = app.buttons["battle.cheer2"]
        XCTAssertTrue(other.label.contains("Elephant"))
        XCTAssertTrue(other.label.contains("Great White Shark"))
        XCTAssertTrue(other.label.contains("Bald Eagle"))
        XCTAssertTrue(other.label.contains("T-Rex"))
        capture("retro_4v4_arena")
        cheer.tap()
        XCTAssertEqual(cheer.value as? String, "1 cheers")
        let story = app.staticTexts["battle.narration"]
        XCTAssertTrue(story.waitForExistence(timeout: 25))
        XCTAssertEqual(story.label, "Fixture battle completed.")
        Thread.sleep(forTimeInterval: 0.8) // Let the result entrance finish before visual QA.
        capture("retro_4v4_result")
    }

    func testBackgroundPausesThenRematchStartsANewBattle() {
        launch("solo")
        let cheer = app.buttons["battle.cheer1"]
        XCTAssertTrue(cheer.waitForExistence(timeout: 10))
        capture("retro_solo_before_background")
        XCUIDevice.shared.press(.home)
        // Longer than the solo animation: background time must not complete it.
        Thread.sleep(forTimeInterval: 8)
        app.activate()
        XCTAssertTrue(app.buttons["battle.cheer1"].waitForExistence(timeout: 5),
                      "Backgrounding must pause, not finish or cancel the native battle.")
        capture("retro_solo_resumed")
        let story = app.staticTexts["battle.narration"]
        XCTAssertTrue(story.waitForExistence(timeout: 20))
        XCTAssertEqual(story.label, "Fixture battle completed.")
        let rematch = app.buttons["battle.rematch"]
        XCTAssertTrue(rematch.waitForExistence(timeout: 5))
        reveal(rematch)
        capture("retro_solo_result_actions")
        rematch.tap()
        XCTAssertTrue(cheer.waitForExistence(timeout: 10))
        XCTAssertEqual(cheer.value as? String, "0 cheers")
        capture("retro_solo_rematch")
        XCTAssertTrue(story.waitForExistence(timeout: 20))
        XCTAssertEqual(story.label, "Fixture battle completed.")
    }

    func testLocalCustomAvatarsKeepNamedParticipantsAndCompleteOffline() {
        launch("custom")
        let first = app.buttons["battle.cheer1"]
        let second = app.buttons["battle.cheer2"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(first.label.contains("Blue Lion"))
        XCTAssertTrue(first.label.contains("Ice Dragon"))
        XCTAssertTrue(second.label.contains("Robot"))
        XCTAssertTrue(second.label.contains("Glimmerflux"))
        capture("retro_custom_arena")
        first.tap()
        XCTAssertEqual(first.value as? String, "1 cheers")
        let story = app.staticTexts["battle.narration"]
        XCTAssertTrue(story.waitForExistence(timeout: 25))
        XCTAssertEqual(story.label, "Fixture battle completed.")
        XCTAssertFalse(app.descendants(matching: .any)["battle.offlineIndicator"].exists,
                       "Locally made artwork must not turn a successful battle into an offline fallback.")
        Thread.sleep(forTimeInterval: 0.8)
        capture("retro_custom_result")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "BLUE LION")).firstMatch.exists,
                      "The result must preserve the custom name, not replace its identity with the base animal.")
    }
}

/// Visual evidence for the real nonbattle views; not a claim of flow/commerce coverage.
final class RetroScreenUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    func testTournamentCloseReturnsToRealHome() {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "battle-success", "AVA_FIXTURE_SCREEN": "ui-home-navigation"]
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10))
        let tournament = app.buttons["home.tournamentMode"]
        XCTAssertTrue(tournament.waitForExistence(timeout: 10))
        for _ in 0..<5 where !tournament.isHittable { app.swipeUp() }
        XCTAssertTrue(tournament.isHittable, "The real home route must be available after scrolling")
        tournament.tap()

        let close = app.buttons["tournament.setup.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertTrue(close.isHittable)
        let setup = XCTAttachment(screenshot: app.screenshot())
        setup.name = "navigation-tournament-setup"
        setup.lifetime = .keepAlways
        add(setup)
        close.tap()

        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed,
                       "Close must dismiss the actual full-screen tournament presentation")
        XCTAssertTrue(tournament.waitForExistence(timeout: 5))
        XCTAssertTrue(tournament.isHittable, "Dismissal must restore the working home action")
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "navigation-tournament-returned-home"
        home.lifetime = .keepAlways
        add(home)
        app.terminate()
    }

    private func capture(_ screen: String, scroll: Bool = false) {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "battle-success", "AVA_FIXTURE_SCREEN": screen]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["fixture.screen.\(screen)"].waitForExistence(timeout: 10))
        if screen.hasPrefix("ui-share") {
            XCTAssertTrue(app.images["fixture.export.ready"].waitForExistence(timeout: 20))
        }
        // Let existing entrance animations settle before capturing geometry.
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = screen
        attachment.lifetime = .keepAlways
        add(attachment)
        if scroll {
            app.swipeUp()
            let lower = XCTAttachment(screenshot: app.screenshot())
            lower.name = screen + "-lower"
            lower.lifetime = .keepAlways
            add(lower)
        }
        app.terminate()
    }

    func testCreatureAndCollectionScreens() {
        if ProcessInfo.processInfo.environment["AVA_READING_ONLY"] != "1" {
            for screen in ["ui-picker", "ui-arena", "ui-book", "ui-facts"] { capture(screen) }
        }
        for screen in ["ui-reading-solo", "ui-reading-team", "ui-reading-tournament", "ui-reading-facts"] {
            captureReadingFixture(screen)
        }
        if ProcessInfo.processInfo.environment["AVA_READING_AX3"] == "1" {
            captureLargeTextSupportFixtures()
        }
    }

    /// Exercise the real scroll views with paragraphs, independently of the short
    /// battle-success answer used by lifecycle tests. A focused invocation can set
    /// AVA_READING_ONLY=1 and AVA_READING_AX3=1 in the test runner's environment.
    private func captureReadingFixture(_ screen: String) {
        let largeText = ProcessInfo.processInfo.environment["AVA_READING_AX3"] == "1"
        launchReadingFixture(screen, largeText: largeText)
        let suffix = largeText ? "-ax3" : "-default"
        if screen == "ui-reading-facts" {
            let fact = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@",
                "It folds its wings and drops")).firstMatch
            XCTAssertTrue(fact.waitForExistence(timeout: 10))
            XCTAssertTrue(fact.label.hasSuffix("right out of the air."))
            captureReadingText(fact, name: screen + suffix + "-fact")
        } else {
            let story = app.staticTexts["battle.narration"]
            XCTAssertTrue(story.waitForExistence(timeout: 35))
            let team = screen == "ui-reading-team"
            XCTAssertTrue(story.label.hasPrefix(team ? "The two teams gathered" : "The lion stepped"))
            XCTAssertTrue(story.label.hasSuffix(team ? "the most of its teamwork." : "decided this imaginary match."))
            XCTAssertEqual(story.label.components(separatedBy: "\n\n").count, 3,
                           "All three paragraphs must remain available to accessibility")
            XCTAssertEqual(story.label.count, team ? 1_269 : 1_273,
                           "The accessibility label must retain the complete long fixture, including paragraph breaks")
            Thread.sleep(forTimeInterval: 0.8) // Let the existing result entrance settle.
            captureReadingText(story, name: screen + suffix + "-story")
            if screen == "ui-reading-solo" {
                let why = app.staticTexts["battle.info.WHY?"]
                XCTAssertTrue(why.exists)
                XCTAssertTrue(why.label.hasSuffix("always wins in nature."))
                captureReadingText(why, name: screen + suffix + "-why")
            }
            if screen != "ui-reading-tournament" {
                let fact = app.staticTexts["battle.info.FUN FACT"]
                XCTAssertTrue(fact.exists)
                XCTAssertTrue(fact.label.hasSuffix("caring for its young."))
                captureReadingText(fact, name: screen + suffix + "-fact")
            }
        }

        let endAction: XCUIElement
        switch screen {
        case "ui-reading-solo": endAction = app.buttons["battle.rematch"]
        case "ui-reading-team":
            endAction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "BATTLE AGAIN")).firstMatch
        case "ui-reading-tournament":
            endAction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "NEXT MATCH-UP")).firstMatch
        default:
            endAction = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Read it to me!")).firstMatch
        }
        XCTAssertTrue(endAction.exists)
        let controlTop = app.frame.minY + (app.frame.width > 600 ? 40 : 80)
        let controlBottom = app.frame.maxY - 40
        for _ in 0..<30 {
            let before = endAction.frame
            if endAction.isHittable && before.minY >= controlTop && before.maxY <= controlBottom { break }
            if before.minY < controlTop {
                readingDrag(-min(app.frame.height * 0.18, controlTop + 8 - before.minY))
            } else {
                readingDrag(min(app.frame.height * 0.18, max(30, before.maxY - controlBottom + 8)))
            }
            if abs(endAction.frame.minY - before.minY) < 1 { break }
        }
        XCTAssertTrue(endAction.isHittable, "The real action after the complete prose must remain reachable")
        XCTAssertGreaterThanOrEqual(endAction.frame.minY, controlTop)
        XCTAssertLessThanOrEqual(endAction.frame.maxY, controlBottom,
                                "A partially visible tappable button is insufficient; show its complete label and bounds")
        XCTAssertGreaterThanOrEqual(endAction.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(endAction.frame.maxX, app.frame.maxX)
        captureReadingImage(screen + suffix + "-end-action")
        app.terminate()
    }

    private func launchReadingFixture(_ screen: String, largeText: Bool) {
        app.launchArguments = ["--uitesting", "--reset-test-data",
                               "-UIPreferredContentSizeCategoryName",
                               largeText ? "UICTContentSizeCategoryAccessibilityXL" : "UICTContentSizeCategoryL"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "reading-long", "AVA_FIXTURE_SCREEN": screen,
                                 "AVA_READING_AX3": largeText ? "1" : "0"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["fixture.screen.\(screen)"].waitForExistence(timeout: 10))
        let category = app.staticTexts["fixture.reading.contentSize"]
        XCTAssertTrue(category.waitForExistence(timeout: 10))
        XCTAssertEqual(category.value as? String, largeText ? "accessibility3" : "large",
                       "The native preferred content size must reach SwiftUI; do not fake a scaled screenshot")
    }

    private func captureLargeTextSupportFixtures() {
        launchReadingFixture("ui-help", largeText: true)
        let body = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Choose any two animals")).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 10))
        XCTAssertTrue(body.label.lowercased().hasSuffix("any creature you can dream up."))
        let page = app.scrollViews.containing(NSPredicate(format: "label == %@", body.label)).firstMatch
        XCTAssertTrue(page.exists, "Use the real help-page scroll viewport, excluding its persistent NEXT footer")
        captureReadingText(body, name: "ui-help-ax3-body", viewport: page.frame)
        let next = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "NEXT")).firstMatch
        XCTAssertTrue(next.isHittable)
        captureReadingImage("ui-help-ax3-next-action")
        next.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Battle in the jungle")).firstMatch.waitForExistence(timeout: 5))
        app.terminate()

        launchReadingFixture("ui-pin", largeText: true)
        let subtitle = app.staticTexts["Pick a 4-digit PIN that's hard for your kid to guess."]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 10))
        captureReadingText(subtitle, name: "ui-pin-ax3-subtitle")
        let cancel = app.buttons["Cancel"]
        let zero = app.buttons["0"]
        for _ in 0..<20 {
            if cancel.isHittable && zero.isHittable { break }
            let before = cancel.frame
            readingSwipeUp()
            if abs(cancel.frame.minY - before.minY) < 1 { break }
        }
        XCTAssertTrue(cancel.isHittable, "Cancel must remain reachable after the large PIN explanation")
        XCTAssertTrue(zero.isHittable, "The bottom keypad row must remain reachable")
        captureReadingImage("ui-pin-ax3-bottom-controls")
        app.terminate()
    }

    private func readingSwipeUp(in viewport: CGRect? = nil) {
        readingDrag((viewport ?? app.frame).height * 0.20, in: viewport)
    }

    private func readingDrag(_ distance: CGFloat, in viewport: CGRect? = nil) {
        // Hold at the end of a slow drag so release does not fling the first or
        // final lines out of view. Nested pages use their own scrollable bounds.
        let frame = viewport ?? app.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let startY = frame.minY + frame.height * (distance >= 0 ? 0.72 : 0.40)
        let endY = min(frame.maxY - 24, max(frame.minY + 24, startY - distance))
        let start = origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: startY - app.frame.minY))
        let end = origin.withOffset(CGVector(dx: frame.midX - app.frame.minX, dy: endY - app.frame.minY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.20)
    }

    private func captureReadingText(_ element: XCUIElement, name: String, viewport: CGRect? = nil) {
        let frame = viewport ?? app.frame
        let top = frame.minY + frame.height * 0.30
        // Full-screen cards retain 80pt below the final line. Nested help-page
        // scrolling uses its actual clipped viewport, above the separate footer.
        let bottom = frame.maxY - (viewport == nil ? 80 : 2)
        let visibleTop = frame.minY + (viewport == nil ? (app.frame.width > 600 ? 40 : 80) : 2)
        for _ in 0..<30 {
            let before = element.frame
            if before.minY <= top || before.maxY <= bottom { break }
            readingDrag(min(frame.height * 0.18, max(30, before.minY - top)), in: viewport)
            if abs(element.frame.minY - before.minY) < 1 { break }
        }
        for _ in 0..<8 {
            let before = element.frame
            if before.minY >= visibleTop { break }
            readingDrag(-min(frame.height * 0.18, visibleTop + 16 - before.minY), in: viewport)
            if abs(element.frame.minY - before.minY) < 1 { break }
        }
        XCTAssertGreaterThanOrEqual(element.frame.minY, visibleTop,
                                    "The start capture must show the first line below the visible top inset")
        XCTAssertLessThan(element.frame.minY, bottom)
        XCTAssertGreaterThan(element.frame.maxY, visibleTop)
        captureReadingImage(name + "-start")
        for _ in 0..<30 {
            let before = element.frame
            if before.maxY <= bottom { break }
            readingDrag(min(frame.height * 0.18, max(30, before.maxY - bottom)), in: viewport)
            if abs(element.frame.minY - before.minY) < 1 { break }
        }
        XCTAssertLessThanOrEqual(element.frame.maxY, bottom + 2)
        XCTAssertGreaterThan(element.frame.maxY, visibleTop,
                             "The final lines must still be on screen, not scrolled past")
        captureReadingImage(name + "-end")
    }

    private func captureReadingImage(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSettingsCommerceAndParentScreens() {
        capture("ui-settings", scroll: true)
        capture("ui-shop", scroll: true)
        capture("ui-coins")
        capture("ui-parent")
        capture("ui-pin")
        capture("ui-grownups", scroll: true)
        capture("ui-help", scroll: true)
    }

    func testTournamentAndExports() {
        capture("ui-tournament")
        capture("ui-bracket")
        capture("ui-wager")
        capture("ui-champion", scroll: true)
        for screen in ["ui-share-duel", "ui-share-team", "ui-share-tournament", "ui-share-custom"] { capture(screen, scroll: true) }
    }
}
