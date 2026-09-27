import XCTest

/// Runs the real screens and clock with local service fixtures. Screenshots and
/// the separate DEBUG lifecycle trace support review; they are not golden-frame
/// or frame-rate assertions.
final class ArcadeMotionUITests: XCTestCase {
    private let app = XCUIApplication()
    private var hero: XCUIElement { app.buttons["home.heroBattle"] }
    private var page: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "home.matchupPage").firstMatch
    }

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String) {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "battle-success", "AVA_FIXTURE_SCREEN": screen,
                                 "AVA_MOTION_TRACE": "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10))
        if screen.hasPrefix("ui-") {
            XCTAssertTrue(app.descendants(matching: .any)["fixture.screen.\(screen)"].waitForExistence(timeout: 10))
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForPage(_ number: Int) {
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "\(number) of 5"), object: page)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<7 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    func testAmbientMotionStaysUsableAcrossVisibilityChanges() throws {
        launch("ui-home-navigation")
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        let firstPair = try XCTUnwrap(hero.value as? String)
        XCTAssertEqual(firstPair.components(separatedBy: " versus ").count, 2)
        capture("ambient_home_rest")
        Thread.sleep(forTimeInterval: 9) // Observe a real cycle; do not override the clock.
        XCTAssertEqual(hero.value as? String, firstPair, "Ambient art must not rotate the selected matchup")
        capture("ambient_home_later")

        app.buttons["home.nextMatchup"].tap()
        waitForPage(2)
        let secondPair = try XCTUnwrap(hero.value as? String)
        XCTAssertEqual(secondPair.components(separatedBy: " versus ").count, 2)
        XCTAssertFalse(app.buttons["battle.cheer1"].exists, "Paging must not accidentally start a battle")
        capture("ambient_home_changed_page")
        app.buttons["home.previousMatchup"].tap()
        waitForPage(1)
        XCTAssertEqual(hero.value as? String, firstPair)

        let library = app.buttons["home.myFighters"]
        reveal(library)
        library.tap()
        let close = app.buttons["myFighters.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        Thread.sleep(forTimeInterval: 2)
        capture("ambient_home_covered_by_library")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
        XCTAssertTrue(library.waitForExistence(timeout: 5))

        // Scroll to the actual end of the page. A large tablet may keep part of
        // the hero visible; the trace's measured intersection determines whether
        // its clock should pause, rather than assuming every viewport is equal.
        let help = app.buttons["home.howToPlay"]
        reveal(help)
        for _ in 0..<3 where hero.exists && hero.isHittable { app.swipeUp() }
        XCTAssertTrue(help.isHittable, "The lower home controls must remain usable")
        Thread.sleep(forTimeInterval: 2)
        capture(hero.exists && hero.isHittable ? "ambient_home_scrolled_partly_visible" : "ambient_home_scrolled_hidden")
        for _ in 0..<6 { app.swipeDown() }
        XCTAssertTrue(hero.isHittable)
        XCTAssertEqual(hero.value as? String, firstPair)
        capture("ambient_home_returned_from_scroll")

        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        app.activate()
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(hero.isHittable)
        XCTAssertEqual(hero.value as? String, firstPair)
        capture("ambient_home_returned_from_background")
        app.terminate()

        launch("ui-facts")
        XCTAssertTrue(app.staticTexts["LION"].waitForExistence(timeout: 10))
        capture("ambient_facts_rest")
        Thread.sleep(forTimeInterval: 9)
        XCTAssertTrue(app.staticTexts["LION"].exists)
        capture("ambient_facts_later")
        app.terminate()

        launch("ui-champion")
        XCTAssertTrue(app.staticTexts["TOURNAMENT CHAMPION"].waitForExistence(timeout: 10))
        capture("ambient_champion_rest")
        Thread.sleep(forTimeInterval: 9)
        XCTAssertTrue(app.staticTexts["TOURNAMENT CHAMPION"].exists)
        capture("ambient_champion_later")
        app.terminate()

        // A deliberate hold makes the raised button's pressed and released
        // states observable in passive native video, while testing its action.
        launch("ui-home-navigation")
        let picker = app.buttons["home.pickFighters"]
        reveal(picker)
        capture("ambient_before_held_press")
        picker.press(forDuration: 1.2)
        XCTAssertTrue(app.textFields["Search or create ANY creature..."].waitForExistence(timeout: 10))
        capture("ambient_after_held_press")
        app.terminate()
    }
}
