import XCTest
import UIKit

final class PandaPlateRevisionUIAccessibilityTests: XCTestCase {
    func testOnboardingChoiceStateIsAccessibleAndUpdatesWhenChanged() {
        let app = XCUIApplication()
        app.launch()

        let start = app.buttons["Get started"]
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

    func testPipRevealStartsOnlyAfterOpenAndOffersSkip() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Get started"].tap()
        app.buttons["Continue"].tap() // Main goal is preselected.
        let extraGoal = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Everyday wellbeing")).firstMatch
        XCTAssertTrue(extraGoal.waitForExistence(timeout: 5))
        extraGoal.tap()
        app.buttons["Continue"].tap()
        app.buttons["Continue"].tap() // Tracking experience is preselected.
        XCTAssertTrue(app.staticTexts["A little world is waiting"].waitForExistence(timeout: 5))

        let open = app.buttons["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A little world is waiting"].exists)
        open.tap()

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(app.buttons["Skip video"].waitForExistence(timeout: 5))
        XCTAssertFalse(continueButton.isEnabled, "Continue must wait until Pip’s video finishes.")
        let playbackFinished = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: continueButton
        )
        XCTAssertEqual(XCTWaiter.wait(for: [playbackFinished], timeout: 12), .completed)
        XCTAssertTrue(app.staticTexts["Meet your new companion"].exists)
        continueButton.tap()
        let pipNameHeading = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Name your companion")
        ).firstMatch
        XCTAssertTrue(pipNameHeading.waitForExistence(timeout: 5))
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

    func testPipHomeHeroFramesAdvanceWhileVisible() throws {
        let app = XCUIApplication()
        launchIntoHome(app)

        let pipHero = app.descendants(matching: .any).matching(identifier: "pipHomeHero").firstMatch
        XCTAssertTrue(pipHero.waitForExistence(timeout: 5))
        let heroFrame = pipHero.frame
        XCTAssertGreaterThan(heroFrame.width, 0)
        XCTAssertGreaterThan(heroFrame.height, 0)

        let firstCapture = app.screenshot()
        Thread.sleep(forTimeInterval: 0.8)
        let secondCapture = app.screenshot()

        let firstHeroPixels = try XCTUnwrap(croppedHeroPNG(from: firstCapture, frame: heroFrame))
        let secondHeroPixels = try XCTUnwrap(croppedHeroPNG(from: secondCapture, frame: heroFrame))
        XCTAssertNotEqual(firstHeroPixels, secondHeroPixels, "Pip’s visible Home frame should advance between captures.")
    }

    func testStatsEmptyStateOpensQuickLogAndShowsSessionHeading() {
        let app = XCUIApplication()
        launchIntoHome(app)

        app.buttons["Stats"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["stats-session-so-far"].waitForExistence(timeout: 5))

        let openQuickLog = app.buttons["stats-empty-open-quick-log"]
        if openQuickLog.waitForExistence(timeout: 3) {
            openQuickLog.tap()
        } else {
            app.buttons["Open quick log"].tap()
        }
        XCTAssertTrue(app.staticTexts["What would you like to add?"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        let statsCapture = XCTAttachment(screenshot: app.screenshot())
        statsCapture.name = "PandaPlate Stats · session recap empty"
        statsCapture.lifetime = .keepAlways
        add(statsCapture)
    }

    func testRecentMealsOpensSessionOnlyEmptyState() {
        let app = XCUIApplication()
        launchIntoHome(app)

        app.buttons["Quick actions"].tap()
        XCTAssertTrue(app.buttons["Recent meals"].waitForExistence(timeout: 5))
        app.buttons["Recent meals"].tap()

        XCTAssertTrue(app.navigationBars["Quick repeat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No recent meals yet"].exists)
        XCTAssertTrue(app.staticTexts["From this session only. Copy opens a review; nothing is saved until you tap Save meal."].exists)
        app.buttons["Close"].tap()
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
        let undo = app.buttons["waterQuickLogUndo"]
        XCTAssertTrue(undo.exists)

        let addCup = app.buttons["waterQuickLogAddCup"]
        cup0.tap()
        XCTAssertTrue(addCup.isEnabled)
        assertWaterTotal(0, in: app)
        app.buttons["waterServingSize_smallCup"].tap()
        assertWaterTotal(0, in: app, message: "Choosing a cup size alone must not change the water log.")
        addCup.tap()
        XCTAssertTrue(undo.isEnabled)
        assertWaterTotal(150, in: app)
        undo.tap()
        XCTAssertFalse(undo.isEnabled, "Undo should reverse only the latest edit.")
        XCTAssertEqual(undo.label, "Undo unavailable")
        assertWaterTotal(0, in: app)

        cup0.tap()
        addCup.tap()
        assertWaterTotal(150, in: app)
        app.buttons["waterServingSize_bottle"].tap()
        assertWaterTotal(150, in: app, message: "Choosing a new size must not edit a filled cup until Update is pressed.")
        XCTAssertTrue(addCup.isEnabled)
        addCup.tap()
        assertWaterTotal(500, in: app)

        for index in 1..<10 {
            let cup = app.buttons["waterCupSlot\(index)"]
            XCTAssertTrue(cup.isEnabled)
            cup.tap()
            XCTAssertTrue(addCup.isEnabled)
            addCup.tap()
        }
        assertWaterTotal(5_000, in: app)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "10 of 10 cups logged")
        ).firstMatch.exists)
        XCTAssertFalse(addCup.isEnabled, "A filled ten-cup tray must prevent an eleventh addition.")
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
            NSPredicate(format: "label CONTAINS[c] %@", "Manual logs stay Unknown")
        ).firstMatch.exists)
        app.buttons["Brisk walk"].tap()
        app.buttons["60 min"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Workout · Brisk walk · 60 min")
        ).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 5))

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
        app.launchArguments = ["-ui-test-open-home"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 10))
    }

    private func croppedHeroPNG(from screenshot: XCUIScreenshot, frame: CGRect) -> Data? {
        let image = screenshot.image
        guard let source = image.cgImage else { return nil }
        let scale = image.scale
        let pixelFrame = frame.applying(CGAffineTransform(scaleX: scale, y: scale))
        let screenBounds = CGRect(x: 0, y: 0, width: source.width, height: source.height)
        let cropRect = pixelFrame.intersection(screenBounds).integral
        guard !cropRect.isNull, !cropRect.isEmpty, let cropped = source.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped).pngData()
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

    private func assertWaterTotal(_ amount: Int, in app: XCUIApplication, message: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let unformattedAmount = "\(amount) ml"
        let formattedAmount = "\(amount.formatted()) ml"
        let total = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", unformattedAmount, formattedAmount)
        ).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5), message.isEmpty ? "Expected water total to include \(amount) ml." : message, file: file, line: line)
    }
}
