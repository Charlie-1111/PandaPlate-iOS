import XCTest

final class PandaPlateRevisionUIAccessibilityTests: XCTestCase {
    func testOnboardingChoiceStateIsAccessibleAndUpdatesWhenChanged() {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Let’s get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let defaultChoice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Feel more balanced")
        ).firstMatch
        let alternateChoice = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Build a steady rhythm")
        ).firstMatch

        XCTAssertTrue(defaultChoice.waitForExistence(timeout: 5))
        XCTAssertTrue(alternateChoice.exists)
        XCTAssertTrue(defaultChoice.isSelected)
        XCTAssertFalse(alternateChoice.isSelected)

        alternateChoice.tap()
        XCTAssertFalse(defaultChoice.isSelected)
        XCTAssertTrue(alternateChoice.isSelected)
    }

    func testHomeChallengesStatsAndLauncherExposeAccessibleNavigation() {
        let app = XCUIApplication()
        launchIntoHome(app)

        let home = app.buttons["Home"]
        let challenges = app.buttons["Challenges"]
        let stats = app.buttons["Stats"]
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(challenges.waitForExistence(timeout: 5))
        XCTAssertTrue(stats.waitForExistence(timeout: 5))
        let launcher = app.buttons["Quick actions"]
        XCTAssertTrue(launcher.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Progress"].exists)
        XCTAssertFalse(app.buttons["You"].exists)
        XCTAssertGreaterThanOrEqual(home.frame.height, 44)
        XCTAssertGreaterThanOrEqual(challenges.frame.height, 44)
        XCTAssertGreaterThanOrEqual(stats.frame.height, 44)
        XCTAssertGreaterThanOrEqual(launcher.frame.width, 64)
        XCTAssertEqual(home.value as? String, "Selected")
        XCTAssertTrue(home.isSelected)
        XCTAssertEqual(challenges.value as? String, "Not selected")
        XCTAssertEqual(stats.value as? String, "Not selected")
        let homeCapture = XCTAttachment(screenshot: app.screenshot())
        homeCapture.name = "PandaPlate Home · new navigation pill"
        homeCapture.lifetime = .keepAlways
        add(homeCapture)

        challenges.tap()
        XCTAssertEqual(challenges.value as? String, "Selected")
        XCTAssertTrue(challenges.isSelected)
        XCTAssertTrue(launcher.exists)
        XCTAssertTrue(app.staticTexts["Challenges"].waitForExistence(timeout: 5))

        stats.tap()
        XCTAssertEqual(stats.value as? String, "Selected")
        XCTAssertTrue(stats.isSelected)
        XCTAssertTrue(launcher.exists)
        XCTAssertTrue(app.staticTexts["Stats"].waitForExistence(timeout: 5))

        launcher.tap()
        XCTAssertTrue(app.staticTexts["What would you like to add?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Workout"].exists)
        XCTAssertTrue(app.buttons["Fasting"].exists)
    }

    func testTenCupWaterLogAllowsSizeSelectionAndOneStepUndo() {
        let app = XCUIApplication()
        launchIntoHome(app)
        app.swipeUp()

        let cup0 = app.buttons["waterCupSlot0"]
        XCTAssertTrue(cup0.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["waterServingSize_smallCup"].exists)
        XCTAssertTrue(app.buttons["waterServingSize_glass"].exists)
        XCTAssertTrue(app.buttons["waterServingSize_bottle"].exists)
        let undo = app.buttons["Undo last water change"]
        XCTAssertTrue(undo.exists)

        cup0.tap()
        XCTAssertTrue(undo.isEnabled)
        assertWaterTotal(250, in: app)
        undo.tap()
        XCTAssertFalse(undo.isEnabled, "Undo should reverse only the latest edit.")
        XCTAssertEqual(undo.label, "Undo unavailable")
        assertWaterTotal(0, in: app)

        app.buttons["waterServingSize_smallCup"].tap()
        cup0.tap()
        assertWaterTotal(150, in: app)
        cup0.tap()
        app.buttons["waterServingSize_bottle"].tap()
        assertWaterTotal(500, in: app)

        for index in 1..<10 {
            let cup = app.buttons["waterCupSlot\(index)"]
            XCTAssertTrue(cup.isEnabled)
            cup.tap()
        }
        assertWaterTotal(5_000, in: app)
        XCTAssertTrue(app.staticTexts["10 of 10 cups · session total"].exists)
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        assertWaterTotal(4_500, in: app)
        XCTAssertFalse(undo.isEnabled)
    }

    func testWorkoutAndFastingLogsAreAvailableFromLauncherAndStaySessionOnly() {
        let app = XCUIApplication()
        launchIntoHome(app)

        app.buttons["Quick actions"].tap()
        app.buttons["Workout"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "No calorie-burn estimates or exercise scoring")
        ).firstMatch.exists)
        app.buttons["Brisk walk"].tap()
        app.buttons["60 min"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Workout · Brisk walk · 60 min")
        ).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["No calorie estimates yet"].waitForExistence(timeout: 5))

        app.buttons["Quick actions"].tap()
        app.buttons["Fasting"].tap()
        XCTAssertTrue(app.navigationBars["Fasting log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "No target")
        ).firstMatch.exists)
        app.buttons["Start session log"].tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
        app.buttons["End and save session log"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Fasting log ·")
        ).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        app.buttons["Stats"].tap()
        let history = app.buttons["History"]
        XCTAssertTrue(history.waitForExistence(timeout: 5))
        history.tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Fasting log ·")
        ).firstMatch.waitForExistence(timeout: 5))
    }

    private func launchIntoHome(_ app: XCUIApplication) {
        app.launch()
        let start = app.buttons["Get started"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        for _ in 0..<6 {
            let continueButton = app.buttons["Continue"]
            XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
            continueButton.tap()
        }
        let skipIntro = app.buttons["Skip intro video"]
        XCTAssertTrue(skipIntro.waitForExistence(timeout: 5))
        skipIntro.tap()

        let meetPip = app.buttons["Meet Pip"]
        XCTAssertTrue(meetPip.waitForExistence(timeout: 5))
        meetPip.tap()
        app.buttons["Keep Pip’s name"].tap()
        app.buttons["Skip for now"].tap() // user name
        for _ in 0..<5 {
            app.buttons["Continue"].tap()
        }
        app.buttons["Skip for now"].tap() // meal times
        app.buttons["Skip for now"].tap() // fasting schedule
        app.buttons["No preference for now"].tap() // eating locations
        app.buttons["Skip for now"].tap() // diet preference
        app.buttons["No restriction to note"].tap()
        app.buttons["Skip for now"].tap() // water adequacy
        app.buttons["No change for now"].tap()
        app.buttons["Skip for now"].tap() // weekend routine
        app.buttons["Skip for now"].tap() // cravings
        app.buttons["Skip for now"].tap() // movement
        selectFirstValue(in: app, identifier: "onboarding-snap-value-age")
        app.buttons["Continue"].tap()
        selectFirstValue(in: app, identifier: "onboarding-snap-value-height")
        app.buttons["Continue"].tap()
        selectFirstValue(in: app, identifier: "onboarding-snap-value-current-weight")
        app.buttons["Continue"].tap()
        selectFirstValue(in: app, identifier: "onboarding-snap-value-target-weight")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your setup"].waitForExistence(timeout: 5))
        app.buttons["Finish setup"].tap()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 5))
    }

    private func selectFirstValue(in app: XCUIApplication, identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Expected required profile selector \(identifier).", file: file, line: line)
        XCTAssertEqual(picker.value as? String, "Not selected", file: file, line: line)
        XCTAssertFalse(app.buttons["Continue"].isEnabled, "The required measurement should block Continue until selected.", file: file, line: line)
        let valueScrollView = picker.scrollViews.firstMatch
        XCTAssertTrue(valueScrollView.exists, "Required value picker should expose its inner scroll control.", file: file, line: line)
        valueScrollView.swipeUp()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", "Not selected"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "Selecting a snap value should enable Continue.", file: file, line: line)
        XCTAssertTrue(app.buttons["Continue"].isEnabled, file: file, line: line)
    }

    private func assertWaterTotal(_ amount: Int, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let unformattedAmount = "\(amount) ml"
        let formattedAmount = "\(amount.formatted()) ml"
        let total = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", unformattedAmount, formattedAmount)
        ).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5), "Expected water total to include \(amount) ml.", file: file, line: line)
    }
}
