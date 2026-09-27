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
        for screen in ["ui-picker", "ui-arena", "ui-book", "ui-facts"] { capture(screen) }
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
