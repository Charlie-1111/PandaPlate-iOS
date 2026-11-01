import XCTest
import ImageIO
import UIKit
@testable import PandaPlate

@MainActor
final class PandaPlateSafetyTests: XCTestCase {
    func testOnboardingAnswersChangeTheHomePlan() {
        var quiet = SessionPlanInput()
        quiet.fastingFamiliarity = "No"
        quiet.fastingSchedulePreference = "Not currently"
        quiet.waterAdequacy = "Yes"
        quiet.dietPreference = nil
        quiet.pipStyle = .gentle
        quiet.goal = .maintain
        let quietPlan = SessionPlanBuilder.make(quiet, now: Date(timeIntervalSince1970: 1_762_000_000), calendar: gregorianMonday())
        XCTAssertFalse(quietPlan.showsFasting)
        XCTAssertFalse(quietPlan.emphasizesWater)
        XCTAssertNil(quietPlan.foodReminder)
        XCTAssertEqual(quietPlan.title, "A steady rhythm")
        XCTAssertTrue(quietPlan.pipLine.contains("No rush"))

        var active = SessionPlanInput()
        active.goal = .change
        active.pipStyle = .cheerleader
        active.companionName = "Miso"
        active.loggingFamiliarity = "I log regularly"
        active.fastingFamiliarity = "Yes"
        active.mealsPerDay = 2
        active.firstMealTime = "08:00"
        active.lastMealTime = "19:00"
        active.dietPreference = "Vegetarian"
        active.foodRestrictions = ["Dairy"]
        active.waterAdequacy = "No"
        active.habitChanges = ["More vegetables"]
        active.mealPlaces = ["Cook at home"]
        active.mealsLogged = 1
        active.ageYears = 30
        active.currentWeightKilograms = 70
        active.targetWeightKilograms = 68
        active.goalPace = "Slow"
        active.estimatedReachDate = Date(timeIntervalSince1970: 1_800_000_000)
        let activePlan = SessionPlanBuilder.make(active, now: Date(timeIntervalSince1970: 1_762_000_000), calendar: gregorianMonday())
        XCTAssertTrue(activePlan.showsFasting)
        XCTAssertTrue(activePlan.emphasizesWater)
        XCTAssertEqual(activePlan.mealRhythm, 2)
        XCTAssertEqual(activePlan.foodReminder?.contains("Vegetarian"), true)
        XCTAssertEqual(activePlan.foodReminder?.contains("Dairy"), true)
        XCTAssertTrue(activePlan.pipLine.contains("Miso"))
        XCTAssertTrue(activePlan.items.contains { $0.id == "meals" && $0.title == "1 of 2 meals" })
        XCTAssertTrue(activePlan.items.contains { $0.id == "habit" })
        XCTAssertTrue(activePlan.items.contains { $0.id == "pace" })
        XCTAssertFalse(activePlan.items.contains { $0.id == "weekend" })

        var underage = active
        underage.ageYears = 16
        underage.estimatedReachSkippedUnder18 = true
        let underagePlan = SessionPlanBuilder.make(underage)
        XCTAssertFalse(underagePlan.items.contains { $0.id == "pace" })

        var weekend = SessionPlanInput()
        weekend.weekendEating = "A little different"
        let saturday = Date(timeIntervalSince1970: 1_762_000_000)
        var us = Calendar(identifier: .gregorian)
        us.locale = Locale(identifier: "en_US_POSIX")
        us.timeZone = TimeZone(secondsFromGMT: 0)!
        let weekendPlan = SessionPlanBuilder.make(weekend, now: saturday, calendar: us)
        XCTAssertTrue(weekendPlan.items.contains { $0.id == "weekend" })
        let weekdayPlan = SessionPlanBuilder.make(weekend, now: Date(timeIntervalSince1970: 1_762_214_400), calendar: us)
        XCTAssertFalse(weekdayPlan.items.contains { $0.id == "weekend" })
    }

    private func gregorianMonday() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testUnknownCaloriesRemainUnknownAndZeroRemainsZero() {
        let store = AppStore()
        store.addMeal(name: "Unknown", calories: nil, imageData: nil)
        XCTAssertNil(store.meals[0].calories)
        XCTAssertNil(store.caloriesEaten, "Unknown calories must not invent a session total.")

        store.addMeal(name: "Zero", calories: 0, imageData: nil)
        XCTAssertEqual(store.meals[1].calories, 0)
        XCTAssertEqual(store.caloriesEaten, 0, "An explicit zero estimate stays zero; unknown is not coerced into the sum.")
    }

    func testCaloriesMealCountAndImagePayloadAreBounded() {
        let store = AppStore()
        store.addMeal(name: "Too high", calories: 10_001, imageData: Data(repeating: 1, count: 1_000_001))
        XCTAssertNil(store.meals[0].calories)
        XCTAssertNil(store.meals[0].imageData)

        for index in 0..<AppStore.maximumMealsPerSession + 5 {
            store.addMeal(name: "Meal \(index)", calories: 10_000, imageData: nil)
        }
        XCTAssertEqual(store.meals.count, AppStore.maximumMealsPerSession)
        XCTAssertLessThanOrEqual(store.caloriesEaten ?? Int.max, 100_000)
    }

    func testWaterAndSessionDataAreBoundedAndResettable() {
        let store = AppStore()
        for _ in 0..<25 { store.addWater(250) }
        XCTAssertEqual(store.waterML, 4_000)

        store.addMeal(name: "Lunch", calories: nil, imageData: nil)
        store.removeMeal(id: store.meals[0].id)

        store.resetDemoSession()
        XCTAssertEqual(store.waterML, 0)
        XCTAssertTrue(store.meals.isEmpty)
    }

    func testOptionalMealTimesAcceptOnlyValid24HourValues() {
        XCTAssertTrue(MealTimeValidator.isValidOptional24HourTime(""))
        XCTAssertTrue(MealTimeValidator.isValidOptional24HourTime("00:00"))
        XCTAssertTrue(MealTimeValidator.isValidOptional24HourTime("23:59"))
        XCTAssertFalse(MealTimeValidator.isValidOptional24HourTime("24:00"))
        XCTAssertFalse(MealTimeValidator.isValidOptional24HourTime("09:60"))
        XCTAssertFalse(MealTimeValidator.isValidOptional24HourTime("8:30"))
    }

    func testPhotoLoaderRejectsOversizedAndInvalidInput() {
        let oversized = Data(repeating: 0, count: BoundedPhotoLoader.maximumInputBytes + 1)
        XCTAssertNil(BoundedPhotoLoader.jpegData(from: oversized))
        XCTAssertNil(BoundedPhotoLoader.jpegData(from: Data("not an image".utf8)))
    }

    func testPhotoLoaderDownsamplesValidImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1_600, height: 1_600))
        let input = renderer.jpegData(withCompressionQuality: 0.85) { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_600, height: 1_600))
        }
        let output = try XCTUnwrap(BoundedPhotoLoader.jpegData(from: input))
        XCTAssertLessThanOrEqual(output.count, 1_000_000)

        let source = try XCTUnwrap(CGImageSourceCreateWithData(output as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        XCTAssertLessThanOrEqual(width, BoundedPhotoLoader.maximumPixelDimension)
        XCTAssertLessThanOrEqual(height, BoundedPhotoLoader.maximumPixelDimension)
    }

    func testCancelledOrSupersededPhotoLoadCannotPublish() {
        let current = UUID()
        let replacement = UUID()
        XCTAssertTrue(BoundedPhotoLoader.mayPublishResult(requestID: current, activeID: current, isCancelled: false))
        XCTAssertFalse(BoundedPhotoLoader.mayPublishResult(requestID: current, activeID: current, isCancelled: true))
        XCTAssertFalse(BoundedPhotoLoader.mayPublishResult(requestID: current, activeID: replacement, isCancelled: false))
    }

    func testWorkoutChoicesAreBoundedAndSessionOnly() {
        let store = AppStore()
        XCTAssertTrue(store.addWorkout(activity: "Casual walk", durationMinutes: 30))
        XCTAssertTrue(store.addWorkout(activity: "Running", durationMinutes: 45))
        XCTAssertTrue(store.addWorkout(activity: "Custom yoga flow", durationMinutes: 999))
        XCTAssertFalse(store.addWorkout(activity: "", durationMinutes: 30))
        XCTAssertFalse(store.addWorkout(activity: "Brisk walk", durationMinutes: 0))
        XCTAssertFalse(store.addWorkout(activity: "Brisk walk", durationMinutes: 1_441))
        XCTAssertFalse(store.addWorkout(activity: String(repeating: "a", count: 61), durationMinutes: 30))
        XCTAssertEqual(store.workouts.count, 3)
        store.resetDemoSession()
        XCTAssertTrue(store.workouts.isEmpty)
    }

    func testFastingLogCanEndCancelAndResetWithoutTarget() {
        let store = AppStore()
        let start = Date(timeIntervalSince1970: 1_000_000)
        store.startFasting(at: start)
        store.startFasting(at: start.addingTimeInterval(60))
        XCTAssertEqual(store.fastingStartedAt, start)
        XCTAssertFalse(store.endFasting(at: start.addingTimeInterval(-60)))
        XCTAssertTrue(store.endFasting(at: start.addingTimeInterval(3_600)))
        XCTAssertEqual(store.fastingEntries.first?.durationSeconds, 3_600)

        store.startFasting(at: start)
        store.cancelFasting()
        XCTAssertNil(store.fastingStartedAt)
        store.resetDemoSession()
        XCTAssertTrue(store.fastingEntries.isEmpty)
        XCTAssertNil(store.fastingStartedAt)
    }

    func testOnboardingDraftMapsAllAnswersAndResetClearsSensitiveSessionValues() {
        var draft = PandaPlateOnboardingDraft()
        draft.goal = .maintain
        draft.additionalGoals = ["More daily energy"]
        draft.loggingFamiliarity = "I’ve logged before"
        draft.fastingFamiliarity = "Yes"
        draft.companionName = "Pip"
        draft.userName = "Charlie"
        draft.pipStyle = .mindful
        draft.reminderPreference = "In the morning"
        draft.mealsPerDay = 4
        draft.firstMealTime = "08:15"
        draft.lastMealTime = "19:30"
        draft.fastingSchedulePreference = "I already follow a schedule"
        draft.eatingLocations = ["Cook at home", "Eat out"]
        draft.dietPreference = "Vegetarian"
        draft.foodRestrictions = ["Dairy"]
        draft.waterAdequacy = "Not sure"
        draft.habitChanges = ["Reduce added sugar"]
        draft.weekendEating = "A little different"
        draft.cravingsFrequency = "Sometimes"
        draft.activityLevel = "Some movement through the day"
        draft.ageYears = 17
        draft.heightCentimeters = 168
        draft.currentWeightKilograms = 72
        draft.targetWeightKilograms = 68

        let store = AppStore()
        store.applyOnboardingDraft(draft)

        XCTAssertTrue(store.finishedOnboarding)
        XCTAssertEqual(store.goal, .maintain)
        XCTAssertEqual(store.supportFocus, ["More daily energy"])
        XCTAssertEqual(store.loggingFamiliarity, "I’ve logged before")
        XCTAssertEqual(store.fastingFamiliarity, "Yes")
        XCTAssertEqual(store.userName, "Charlie")
        XCTAssertEqual(store.pipStyle, .mindful)
        XCTAssertEqual(store.mealsPerDay, 4)
        XCTAssertEqual(store.firstMealTime, "08:15")
        XCTAssertEqual(store.lastMealTime, "19:30")
        XCTAssertEqual(store.fastingSchedulePreference, "I already follow a schedule")
        XCTAssertEqual(store.mealPlaces, ["Cook at home", "Eat out"])
        XCTAssertEqual(store.dietPreference, "Vegetarian")
        XCTAssertEqual(store.foodRestrictions, ["Dairy"])
        XCTAssertEqual(store.waterAdequacy, "Not sure")
        XCTAssertEqual(store.habitChanges, ["Reduce added sugar"])
        XCTAssertEqual(store.weekendEating, "A little different")
        XCTAssertEqual(store.cravingsFrequency, "Sometimes")
        XCTAssertEqual(store.activityLevel, "Some movement through the day")
        XCTAssertEqual(store.ageYears, 17)
        XCTAssertEqual(store.heightCentimeters, 168)
        XCTAssertEqual(store.currentWeightKilograms, 72)
        XCTAssertEqual(store.targetWeightKilograms, 68)

        store.resetDemoSession()
        XCTAssertTrue(store.finishedOnboarding, "Reset keeps the app on Home while clearing this session’s answers.")
        XCTAssertEqual(store.goal, .balanced)
        XCTAssertTrue(store.supportFocus.isEmpty)
        XCTAssertNil(store.reminderPreference)
        XCTAssertNil(store.fastingSchedulePreference)
        XCTAssertNil(store.dietPreference)
        XCTAssertTrue(store.foodRestrictions.isEmpty)
        XCTAssertNil(store.waterAdequacy)
        XCTAssertTrue(store.habitChanges.isEmpty)
        XCTAssertNil(store.weekendEating)
        XCTAssertNil(store.cravingsFrequency)
        XCTAssertNil(store.activityLevel)
        XCTAssertNil(store.ageYears)
        XCTAssertNil(store.heightCentimeters)
        XCTAssertNil(store.currentWeightKilograms)
        XCTAssertNil(store.targetWeightKilograms)
    }
}
