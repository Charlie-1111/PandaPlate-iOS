import XCTest
@testable import PandaPlate

final class PandaPlatePlanBuilderTests: XCTestCase {
    func testSameDraftAlwaysProducesEqualSevenDayPlanAndFourPremiumWeeks() {
        let draft = representativeDraft()
        let first = PandaPlatePlanBuilder.build(from: draft)
        let second = PandaPlatePlanBuilder.build(from: draft)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.days.count, 7)
        XCTAssertEqual(first.days.map(\.dayNumber), Array(1...7))
        XCTAssertEqual(first.premiumWeeks.count, 4)
        XCTAssertTrue(first.premiumWeeks.allSatisfy { !$0.checkInPrompt.isEmpty && !$0.tasks.isEmpty })
        XCTAssertTrue(first.foodSuggestions.isEmpty)
    }

    func testOnboardingAnswersShapeTheRoutineWithoutBecomingTargets() {
        let plan = PandaPlatePlanBuilder.build(from: representativeDraft())

        XCTAssertEqual(plan.weeklyFocus, WellnessGoal.change.detail)
        XCTAssertEqual(plan.context.mainFocus, WellnessGoal.change.rawValue)
        XCTAssertEqual(plan.context.additionalGoals, ["Everyday wellbeing"])
        XCTAssertEqual(plan.context.loggingFamiliarity, "I log regularly")
        XCTAssertEqual(plan.context.mealsPerDay, 4)
        XCTAssertEqual(plan.context.firstMealPeriod, "AM")
        XCTAssertEqual(plan.context.lastMealPeriod, "PM")
        XCTAssertEqual(plan.context.eatingLocations, ["Cook at home", "Order in"])
        XCTAssertEqual(plan.context.dietPreference, "Vegetarian")
        XCTAssertEqual(plan.context.foodRestrictions, ["Dairy", "Nuts"])
        XCTAssertEqual(plan.context.habitChanges, ["Cook at home more often"])
        XCTAssertEqual(plan.context.activityLevel, "Some movement through the day")
        XCTAssertEqual(plan.context.pipStyle, PipStyle.mindful.rawValue)
        XCTAssertEqual(plan.context.fastingFamiliarity, "Yes")
        XCTAssertEqual(plan.context.fastingSchedulePreference, "I already follow a schedule")
        XCTAssertEqual(plan.context.waterAdequacy, "Not sure")
        XCTAssertEqual(plan.context.weekendEating, "A little different")
        XCTAssertEqual(plan.context.cravingsFrequency, "Sometimes")
        XCTAssertEqual(plan.context.reminderPreference, "In the morning")

        XCTAssertTrue(plan.days[0].detail.contains("4 meal moments"))
        XCTAssertTrue(plan.days[1].detail.contains("AM"))
        XCTAssertTrue(plan.days[1].detail.contains("PM"))
        XCTAssertTrue(plan.days[2].detail.contains("Cook at home"))
        XCTAssertTrue(plan.days[3].detail.contains("Cook at home more often"))
        XCTAssertTrue(plan.days[4].detail.contains("Preference: Vegetarian"))
        XCTAssertTrue(plan.days[4].detail.contains("Avoid: Dairy, Nuts"))
        XCTAssertTrue(plan.days[4].detail.contains("No food or recipe suggestions"))
        XCTAssertTrue(plan.days[5].detail.contains("activity target"))
        XCTAssertTrue(plan.days[6].detail.contains("logging"))
        XCTAssertTrue(plan.supportLine.contains("pause"))
        XCTAssertTrue(plan.fastingLine.contains("No new window or recommendation"))
        XCTAssertTrue(plan.weekendLine.contains("weekend differences"))
        XCTAssertTrue(plan.cravingsLine.contains("context only"))
    }

    func testSelectedRestrictionsNeverProduceFoodSuggestions() {
        var draft = PandaPlateOnboardingDraft()
        draft.foodRestrictions = ["Nuts", "Dairy", "Shellfish"]
        draft.dietPreference = "Vegan"

        let plan = PandaPlatePlanBuilder.build(from: draft)

        XCTAssertEqual(plan.context.foodRestrictions, ["Dairy", "Nuts", "Shellfish"])
        XCTAssertEqual(plan.context.dietPreference, "Vegan")
        XCTAssertTrue(plan.foodSuggestions.isEmpty)
        XCTAssertTrue(plan.days[4].detail.contains("No food or recipe suggestions"))
    }

    func testMissingOrInvalidAnswersStayUnknownRatherThanReceivingDefaults() {
        var draft = PandaPlateOnboardingDraft()
        draft.mealsPerDay = 99
        draft.firstMealTime = "25:99"
        draft.lastMealTime = ""
        draft.fastingFamiliarity = nil
        draft.fastingSchedulePreference = nil
        draft.eatingLocations = []
        draft.dietPreference = nil
        draft.foodRestrictions = []
        draft.waterAdequacy = nil
        draft.habitChanges = []
        draft.weekendEating = nil
        draft.cravingsFrequency = nil
        draft.activityLevel = nil
        draft.ageYears = nil

        let plan = PandaPlatePlanBuilder.build(from: draft)

        XCTAssertNil(plan.context.mealsPerDay)
        XCTAssertNil(plan.context.firstMealPeriod)
        XCTAssertNil(plan.context.lastMealPeriod)
        XCTAssertNil(plan.context.fastingFamiliarity)
        XCTAssertNil(plan.context.fastingSchedulePreference)
        XCTAssertNil(plan.context.dietPreference)
        XCTAssertNil(plan.context.waterAdequacy)
        XCTAssertNil(plan.context.weekendEating)
        XCTAssertNil(plan.context.cravingsFrequency)
        XCTAssertNil(plan.context.activityLevel)
        XCTAssertEqual(plan.safety, .ageNotProvided)
        XCTAssertNil(plan.bodyNeutralEmphasis)
        XCTAssertTrue(plan.days[0].detail.contains("skip this check-in"))
        XCTAssertTrue(plan.days[1].detail.contains("no times are assumed"))
        XCTAssertTrue(plan.days[2].detail.contains("No usual place is selected"))
        XCTAssertTrue(plan.foodSuggestions.isEmpty)
    }

    func testAgeChangesOnlySafetyClassification() {
        var adultDraft = representativeDraft()
        var under18Draft = adultDraft
        adultDraft.ageYears = 18
        under18Draft.ageYears = 17

        let adultPlan = PandaPlatePlanBuilder.build(from: adultDraft)
        let under18Plan = PandaPlatePlanBuilder.build(from: under18Draft)

        XCTAssertEqual(adultPlan.safety, .adult)
        XCTAssertEqual(under18Plan.safety, .under18)
        XCTAssertNotEqual(adultPlan.safetyNote, under18Plan.safetyNote)
        XCTAssertEqual(adultPlan.context, under18Plan.context)
        XCTAssertEqual(adultPlan.days, under18Plan.days)
        XCTAssertEqual(adultPlan.premiumWeeks, under18Plan.premiumWeeks)
        XCTAssertEqual(adultPlan.weeklyFocus, under18Plan.weeklyFocus)
    }

    func testBodyMetricValuesAndWeightDirectionNeverChangePlanContent() {
        var lowerProfile = representativeDraft()
        var higherProfile = representativeDraft()
        lowerProfile.heightCentimeters = 140
        lowerProfile.currentWeightKilograms = 95
        lowerProfile.targetWeightKilograms = 50
        higherProfile.heightCentimeters = 195
        higherProfile.currentWeightKilograms = 48
        higherProfile.targetWeightKilograms = 120

        let lowerPlan = PandaPlatePlanBuilder.build(from: lowerProfile)
        let higherPlan = PandaPlatePlanBuilder.build(from: higherProfile)

        XCTAssertEqual(lowerPlan, higherPlan)
        XCTAssertEqual(lowerPlan.bodyNeutralEmphasis, higherPlan.bodyNeutralEmphasis)
        XCTAssertFalse(lowerPlan.bodyNeutralEmphasis?.contains("kg") ?? false)
        XCTAssertFalse(lowerPlan.bodyNeutralEmphasis?.contains("cm") ?? false)
        XCTAssertTrue(lowerPlan.safetyNote.contains("No calorie"))
    }

    func testNoNumericNutritionOrBodyTargetsExistInPlanModelOutput() {
        let plan = PandaPlatePlanBuilder.build(from: representativeDraft())
        let visibleCopy = ([plan.weeklyFocus, plan.supportLine, plan.loggingLine, plan.activityLine,
                            plan.waterLine, plan.fastingLine, plan.weekendLine, plan.cravingsLine] +
                           plan.days.map(\.detail) + plan.premiumWeeks.flatMap { [$0.title, $0.checkInPrompt] + $0.tasks.map(\.title) })
            .joined(separator: " ")
            .lowercased()

        XCTAssertFalse(visibleCopy.contains("kcal"))
        XCTAssertFalse(visibleCopy.contains("bmi"))
        XCTAssertFalse(visibleCopy.contains("weight loss"))
        XCTAssertFalse(visibleCopy.contains("weight gain"))
        XCTAssertFalse(visibleCopy.contains("projection"))
        XCTAssertTrue(plan.foodSuggestions.isEmpty)
    }

    private func representativeDraft() -> PandaPlateOnboardingDraft {
        var draft = PandaPlateOnboardingDraft()
        draft.goal = .change
        draft.additionalGoals = ["Everyday wellbeing"]
        draft.loggingFamiliarity = "I log regularly"
        draft.fastingFamiliarity = "Yes"
        draft.pipStyle = .mindful
        draft.reminderPreference = "In the morning"
        draft.mealsPerDay = 4
        draft.firstMealTime = "08:30"
        draft.lastMealTime = "19:30"
        draft.fastingSchedulePreference = "I already follow a schedule"
        draft.eatingLocations = ["Cook at home", "Order in"]
        draft.dietPreference = "Vegetarian"
        draft.foodRestrictions = ["Dairy", "Nuts"]
        draft.waterAdequacy = "Not sure"
        draft.habitChanges = ["Cook at home more often"]
        draft.weekendEating = "A little different"
        draft.cravingsFrequency = "Sometimes"
        draft.activityLevel = "Some movement through the day"
        draft.ageYears = 32
        draft.heightCentimeters = 170
        draft.currentWeightKilograms = 68
        draft.targetWeightKilograms = 65
        return draft
    }
}
