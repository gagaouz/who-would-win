import XCTest

/// Smoke test of the main loop: home → Surprise Me battle → result screen.
/// Talks to the real backend (or falls back to the phone's own result), so it
/// needs network for the full story but passes either way.
final class WhoWouldWinUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSurpriseBattleReachesResult() throws {
        // First launch offers a welcome alert — skip it.
        let explore = app.alerts.buttons["I'll explore"]
        if explore.waitForExistence(timeout: 3) { explore.tap() }

        let surprise = app.buttons["Surprise Me — start a random battle"]
        XCTAssertTrue(surprise.waitForExistence(timeout: 10), "Home screen should show Surprise Me")
        screenshot("01_home")
        surprise.tap()

        // Cheer for the first fighter (the columns are labelled "Cheer for <name>").
        let cheer = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Cheer for'")).firstMatch
        if cheer.waitForExistence(timeout: 10) {
            screenshot("02_battle")
            cheer.tap()
        }

        // Result screen: one of the two primary buttons appears.
        let result = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'CHALLENGER' OR label CONTAINS 'MATCH-UP'")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 60), "Battle should reach the result screen")
        sleep(2)
        screenshot("03_result")
    }
}
