import XCTest

/// These scenarios explicitly simulate subscription/API answers in the isolated
/// Testing app. They do not establish real account, provider or StoreKit success.
final class CustomFighterUITests: XCTestCase {
    private let app = XCUIApplication()
    private let savedID = "ab70d157-1469-4c43-bfb6-005b53f21b77"
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String) {
        app.launchArguments = ["--uitesting", "--reset-test-data"]
        app.launchEnvironment = ["AVA_UI_TESTING": "1", "AVA_BLOCK_EXTERNAL_SERVICES": "1",
                                 "AVA_FIXTURE_SCENARIO": "custom-fighter-local-fixture", "AVA_FIXTURE_SCREEN": screen]
        app.launch()
        XCTAssertTrue(app.staticTexts["uitest.fixtureMode"].waitForExistence(timeout: 10))
    }
    private func reveal(_ element: XCUIElement) {
        for _ in 0..<7 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    private func typeName() {
        let field = app.textFields["myFighters.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 10)); reveal(field); field.tap(); field.typeText("Test Moon Lion")
        if app.keyboards.buttons["Done"].exists { app.keyboards.buttons["Done"].tap() }
    }
    private func passParentGate() {
        let question = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "What is ")).firstMatch
        XCTAssertTrue(question.waitForExistence(timeout: 10))
        let factors = question.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
        XCTAssertEqual(factors.count, 2)
        guard factors.count == 2 else { return }
        let answer = app.buttons[String(factors[0] * factors[1])].firstMatch
        reveal(answer); answer.tap()
    }
    private func assertRequestCount(_ count: Int) {
        let label = app.staticTexts["myFighters.fixtureRequestCount"]
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        XCTAssertEqual(label.label, "TEST artwork requests: \(count)")
    }

    func testTypingAndCancelledConsentNeverGenerateThenExplicitCreateDoes() {
        launch("custom-fighters-ready")
        typeName(); assertRequestCount(0)
        let create = app.buttons["myFighters.create"]
        reveal(create); XCTAssertTrue(create.isEnabled); create.tap(); passParentGate()
        let confirm = app.buttons["Create artwork — use 1 credit"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10))
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists {
            cancel.tap()
        } else {
            // Native popovers omit the cancel-role button on some OS/size
            // classes. Their outside dismiss region is the actual cancel action.
            let outside = app.otherElements["PopoverDismissRegion"]
            XCTAssertTrue(outside.exists)
            outside.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        }
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5))
        assertRequestCount(0)
        reveal(create); create.tap(); passParentGate()
        XCTAssertTrue(confirm.waitForExistence(timeout: 10)); confirm.tap()
        let preview = app.buttons["myFighters.preview.\(savedID)"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        assertRequestCount(1)
        reveal(preview); capture("my_fighters_created"); preview.tap()
        XCTAssertTrue(app.descendants(matching: .any)["myFighters.fourPoses"].waitForExistence(timeout: 10))
        for name in ["Idle", "Anticipation", "Attack", "Reaction"] { XCTAssertTrue(app.staticTexts[name].exists) }
        capture("my_fighters_four_poses")
    }

    func testSavedJobOutsideRecentListRestoresWithoutAnotherCreation() {
        launch("custom-fighters-resume")
        // This fixture has an empty recent library list, an atomically saved
        // known job ID, and no active creation subscription. Only GET /jobs/:id
        // can recover the finished pack; a new creation would fail the fixture.
        let preview = app.buttons["myFighters.preview.\(savedID)"]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        assertRequestCount(0)
        reveal(preview); preview.tap()
        XCTAssertTrue(app.descendants(matching: .any)["myFighters.fourPoses"].waitForExistence(timeout: 10))
        capture("my_fighters_resumed_existing_job")
    }

    func testUnavailableServiceCannotGenerate() {
        launch("custom-fighters-unavailable")
        typeName(); assertRequestCount(0)
        let create = app.buttons["myFighters.create"]; reveal(create)
        XCTAssertFalse(create.isEnabled)
        XCTAssertTrue(app.staticTexts["New artwork is temporarily unavailable. You can still use saved fighters."].exists)
        capture("my_fighters_unavailable")
    }

    func testDownloadedFighterCanBeSelectedAfterCreationSubscriptionExpires() {
        launch("custom-fighters-saved")
        let coins = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "coins. Opens the coin shop.")).firstMatch
        XCTAssertTrue(coins.waitForExistence(timeout: 10)); let originalCoins = coins.label
        let entry = app.buttons["home.myFighters"]; reveal(entry); entry.tap()
        let premium = app.buttons["myFighters.premium"]
        XCTAssertTrue(premium.waitForExistence(timeout: 10), "Fixture must explicitly have no creation entitlement")
        assertRequestCount(0)
        let use = app.buttons["myFighters.use.\(savedID)"]; reveal(use); use.tap()
        XCTAssertTrue(app.buttons["picker.myFighters"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["TEST MOON LION"].waitForExistence(timeout: 5))
        XCTAssertEqual(coins.label, originalCoins, "Using saved artwork must not charge custom creation coins again")
        capture("my_fighters_saved_reuse")
    }
}
