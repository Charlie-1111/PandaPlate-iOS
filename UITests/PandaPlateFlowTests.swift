import XCTest

final class PandaPlateFlowTests: XCTestCase {
    func testOnboardingThreeTabsHomeQuickLogSettingsAndSessionHistory() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Small bites.")).firstMatch.waitForExistence(timeout: 10))
        app.buttons["Let’s get started"].tap()

        // Goals/experience, neutral transitions, and fasting familiarity.
        for _ in 0..<6 {
            XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5))
            app.buttons["Continue"].tap()
        }
        XCTAssertTrue(app.staticTexts["Someone’s here to say hello."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Skip intro video"].exists)
        let teaserAttachment = XCTAttachment(screenshot: app.screenshot())
        teaserAttachment.name = "PandaPlate full-screen Pip teaser"
        teaserAttachment.lifetime = .keepAlways
        add(teaserAttachment)
        app.buttons["Open"].tap()

        // Mid-flow full-screen Pip reveal at 6/13, then names, tone and the full routine.
        XCTAssertTrue(app.staticTexts["Pip is ready to meet you."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Step 6 of 13"].exists)
        let pipReveal = app.descendants(matching: .any).matching(identifier: "pandaplate-midflow-pip-reveal").firstMatch
        XCTAssertTrue(pipReveal.waitForExistence(timeout: 5))
        let settledPose = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Pip lands and settles into a happy pose"),
            object: pipReveal
        )
        XCTAssertEqual(XCTWaiter.wait(for: [settledPose], timeout: 6), .completed, "Pip should settle into the final happy pose")
        let revealAttachment = XCTAttachment(screenshot: app.screenshot())
        revealAttachment.name = "PandaPlate mid-flow Pip reveal"
        revealAttachment.lifetime = .keepAlways
        add(revealAttachment)
        app.buttons["Meet Pip"].tap()
        app.buttons["Keep Pip’s name"].tap()
        app.buttons["Skip for now"].tap() // optional user name, default friend
        app.buttons["Continue"].tap() // encouragement style
        app.buttons["Continue"].tap() // Small steps count transition
        app.buttons["Continue"].tap() // unscheduled reminder preference
        app.buttons["Continue"].tap() // routine intro
        app.buttons["Continue"].tap() // meals per day
        app.buttons["Skip for now"].tap() // optional meal times
        app.buttons["Skip for now"].tap() // optional fasting schedule

        let orderIn = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Order in")).firstMatch
        let cookAtHome = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Cook at home")).firstMatch
        XCTAssertTrue(orderIn.waitForExistence(timeout: 5))
        XCTAssertTrue(cookAtHome.waitForExistence(timeout: 5))
        XCTAssertFalse(cookAtHome.isSelected)
        XCTAssertFalse(orderIn.isSelected)
        cookAtHome.tap()
        orderIn.tap()
        XCTAssertTrue(cookAtHome.isSelected)
        XCTAssertTrue(orderIn.isSelected)
        app.buttons["Continue"].tap()
        app.buttons["Skip for now"].tap() // optional diet preference
        app.buttons["No restriction to note"].tap()
        app.buttons["Skip for now"].tap() // optional water adequacy
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

        XCTAssertTrue(app.staticTexts["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SESSION NUTRITION"].exists)
        XCTAssertTrue(app.staticTexts["No calorie estimates yet"].exists)
        XCTAssertTrue(app.buttons["Home"].exists)
        XCTAssertTrue(app.buttons["Challenges"].exists)
        XCTAssertTrue(app.buttons["Stats"].exists)
        XCTAssertTrue(app.buttons["Quick actions"].exists)
        XCTAssertFalse(app.buttons["Log"].exists)
        XCTAssertFalse(app.buttons["Pip"].exists)
        XCTAssertFalse(app.buttons["You"].exists)
        XCTAssertTrue(app.staticTexts["PIP’S LITTLE WORLD"].exists)
        XCTAssertTrue(app.images["Pip waves hello with her full body in the forest garden"].exists)
        let homeAttachment = XCTAttachment(screenshot: app.screenshot())
        homeAttachment.name = "PandaPlate Home with Pip’s playground hero"
        homeAttachment.lifetime = .keepAlways
        add(homeAttachment)

        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["Challenges"].tap()
        XCTAssertTrue(app.staticTexts["No challenges to show yet"].waitForExistence(timeout: 5))
        app.buttons["Home"].tap()
        app.buttons["Quick actions"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to add?"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()

        app.buttons["Quick actions"].tap()
        app.buttons["Water"].tap()
        let addCup = app.buttons.matching(identifier: "waterServingSize_glass").element(boundBy: 1)
        XCTAssertTrue(addCup.waitForExistence(timeout: 5))
        addCup.tap()
        XCTAssertTrue(app.staticTexts["250 ml"].exists)
        let undoCup = app.buttons.matching(identifier: "waterQuickLogUndo").element(boundBy: 1)
        XCTAssertTrue(undoCup.isEnabled)
        undoCup.tap()
        XCTAssertTrue(app.staticTexts["0 ml"].exists)
        XCTAssertFalse(undoCup.isEnabled)
        app.buttons["Close"].tap()

        app.buttons["Quick actions"].tap()
        app.buttons["Workout"].tap()
        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 5))
        app.buttons["Brisk walk"].tap()
        app.buttons["60 min"].tap()
        app.buttons["Save workout"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Brisk walk · 60 min")).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Quick actions"].tap()
        app.buttons["Fasting"].tap()
        XCTAssertTrue(app.navigationBars["Fasting log"].waitForExistence(timeout: 5))
        app.buttons["Start session log"].tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 5))
        app.buttons["End and save session log"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fasting log ·")).firstMatch.waitForExistence(timeout: 5))

        app.buttons["Home"].tap()
        app.swipeUp()
        let waterAction = app.buttons["waterServingSize_glass"]
        XCTAssertTrue(waterAction.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(waterAction.frame.height, 44)
        waterAction.tap()
        XCTAssertTrue(app.staticTexts["250 ml"].exists)
        let waterUndo = app.buttons["waterQuickLogUndo"]
        XCTAssertTrue(waterUndo.isEnabled)
        waterUndo.tap()
        XCTAssertTrue(app.staticTexts["0 ml"].exists)

        // Home quick-log offers a local photo note; capture/recognition are unavailable.
        app.swipeDown()
        app.buttons["Quick log"].tap()
        XCTAssertTrue(app.staticTexts["What would you like to add?"].waitForExistence(timeout: 5))
        app.buttons["Photo note"].tap()
        XCTAssertTrue(app.navigationBars["Photo note"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertFalse(app.buttons["Take a photo"].exists)
        let photoPicker = app.descendants(matching: .any).matching(identifier: "meal-photo-picker").firstMatch
        XCTAssertTrue(photoPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Food recognition and barcode scanning are unavailable")).firstMatch.exists)
        app.swipeDown()
        app.buttons["Manual"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Lunch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No estimate"].waitForExistence(timeout: 5))

        app.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Illustrative sample charts")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Meal · Lunch")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Workout · Brisk walk · 60 min")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Fasting log ·")).firstMatch.exists)

    }

    private func selectFirstValue(in app: XCUIApplication, identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let picker = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "Expected required profile selector \(identifier).", file: file, line: line)
        XCTAssertEqual(picker.value as? String, "Not selected", file: file, line: line)
        let valueScrollView = picker.scrollViews.firstMatch
        XCTAssertTrue(valueScrollView.exists, "Required value picker should expose its inner scroll control.", file: file, line: line)
        valueScrollView.swipeUp()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", "Not selected"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed, "Selecting a snap value should enable Continue.", file: file, line: line)
    }
}
