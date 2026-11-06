import XCTest

final class PandaPlateFlowTests: XCTestCase {
    func testHomeQuickLogSettingsAndSessionHistory() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-test-open-home"]
        app.launch()

        let launcher = app.buttons["Quick actions"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Home"].exists)
        XCTAssertTrue(app.buttons["Pip"].exists)
        XCTAssertTrue(app.buttons["Progress"].exists)
        XCTAssertTrue(app.buttons["Profile"].exists)
        XCTAssertTrue(app.images["Pip in the forest garden"].waitForExistence(timeout: 5))

        let homeAttachment = XCTAttachment(screenshot: app.screenshot())
        homeAttachment.name = "PandaPlate Home with Pip’s playground hero"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)

        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()

        app.buttons["Pip"].tap()
        XCTAssertTrue(app.staticTexts["Save a meal note"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Take a water break"].exists)
        XCTAssertTrue(app.staticTexts["Move your way"].exists)
        app.buttons["Log a meal"].tap()
        XCTAssertTrue(app.navigationBars["Manual entry"].waitForExistence(timeout: 5))
        app.buttons["Lunch"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons["Pip"].waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        app.buttons["Quick actions"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to add?"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["Quick actions"].tap()
        app.buttons["Workout"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        app.buttons["Brisk walk"].tap()
        app.buttons["60 min"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.buttons["Quick actions"].waitForExistence(timeout: 5))

        app.buttons["Quick actions"].tap()
        app.buttons["Fasting"].tap()
        XCTAssertTrue(app.navigationBars["Fasting log"].waitForExistence(timeout: 5))
        app.buttons["Start session log"].tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
        app.buttons["End and save session log"].tap()
        XCTAssertTrue(app.buttons["Quick actions"].waitForExistence(timeout: 5))

        app.buttons["Progress"].tap()
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Meal · Lunch")
        ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Workout · Brisk walk · 60 min")
        ).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Fasting log ·")
        ).firstMatch.exists)
    }
}
