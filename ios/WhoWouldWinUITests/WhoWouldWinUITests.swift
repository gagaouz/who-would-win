import XCTest

final class WhoWouldWinUITests: XCTestCase {
    let app = XCUIApplication()
    let sim = "DBE26BB7-06C6-487E-B226-15E1863FED2F"

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func screenshot(_ name: String) {
        let img = app.screenshot()
        let attachment = XCTAttachment(screenshot: img)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // Also save to /tmp for direct viewing
        if let data = img.image.pngData() {
            try? data.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        }
    }

    func testScreenshots() throws {
        sleep(3)
        screenshot("01_home")

        // Tap PLAY NOW
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'PLAY'")).firstMatch.tap()
        sleep(2)
        screenshot("02_picker_empty")

        // Tap "Lion" card (first in grid, by static text label)
        let lionCard = app.staticTexts["Lion"]
        if lionCard.waitForExistence(timeout: 5) { lionCard.tap() }
        sleep(1)

        // Tap "Tiger" card
        let tigerCard = app.staticTexts["Tiger"]
        if tigerCard.waitForExistence(timeout: 3) { tigerCard.tap() }
        sleep(1)
        screenshot("03_picker_selected")

        // Tap the FIGHT button
        let fightBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'FIGHT'")).firstMatch
        if fightBtn.waitForExistence(timeout: 5) {
            fightBtn.tap()
            sleep(2)
            screenshot("04_battle_intro")
            sleep(4)
            screenshot("05_battle_animating")
            sleep(10)
            screenshot("06_battle_result")
        }
    }
}
