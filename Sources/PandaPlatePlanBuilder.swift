import Foundation

/// The plan is a flexible routine checklist, not a nutrition, weight-loss, or medical plan.
enum PandaPlatePlanAgeSafety: Equatable {
    case under18
    case adult
    case ageNotProvided

    var note: String {
        switch self {
        case .under18:
            return "This is only a routine checklist. It does not set food, body, fasting, or activity targets."
        case .adult:
            return "A flexible routine checklist only. No calorie, macro, BMI, body, fasting, or activity targets are calculated."
        case .ageNotProvided:
            return "Age was not provided, so no age-specific content is added. No calorie, macro, BMI, body, fasting, or activity targets are calculated."
        }
    }
}

struct PandaPlatePlanContext: Equatable {
    let mainFocus: String
    let additionalGoals: [String]
    let loggingFamiliarity: String
    let mealsPerDay: Int?
    let firstMealPeriod: String?
    let lastMealPeriod: String?
    let fastingFamiliarity: String?
    let fastingSchedulePreference: String?
    let eatingLocations: [String]
    let dietPreference: String?
    let foodRestrictions: [String]
    let waterAdequacy: String?
    let habitChanges: [String]
    let weekendEating: String?
    let cravingsFrequency: String?
    let activityLevel: String?
    let pipStyle: String
    let reminderPreference: String?
}

struct PandaPlatePlanDay: Identifiable, Equatable {
    let dayNumber: Int
    let title: String
    let detail: String
    var isComplete = false

    var id: Int { dayNumber }
}

struct PandaPlatePlanTask: Identifiable, Equatable {
    let id: String
    let title: String
    var isComplete = false
}

struct PandaPlatePlanWeek: Identifiable, Equatable {
    let weekNumber: Int
    let title: String
    let checkInPrompt: String
    var tasks: [PandaPlatePlanTask]
    var reflection = ""

    var id: Int { weekNumber }
}

struct PandaPlatePlan: Equatable {
    let context: PandaPlatePlanContext
    let weeklyFocus: String
    let supportLine: String
    let loggingLine: String
    let activityLine: String
    let waterLine: String
    let fastingLine: String
    let weekendLine: String
    let cravingsLine: String
    let safety: PandaPlatePlanAgeSafety
    /// Present only if at least one body-profile field was supplied. Its content is the same for all values.
    let bodyNeutralEmphasis: String?
    let days: [PandaPlatePlanDay]
    let premiumWeeks: [PandaPlatePlanWeek]
    /// This version intentionally makes no food/recipe suggestions, so selected restrictions cannot be contradicted.
    let foodSuggestions: [String]

    var safetyNote: String { safety.note }
}

/// A deterministic, offline builder for a user-editable routine checklist.
enum PandaPlatePlanBuilder {
    static func build(from draft: PandaPlateOnboardingDraft) -> PandaPlatePlan {
        let context = makeContext(from: draft)
        let supportLine = supportLine(for: draft.pipStyle)
        let loggingLine = loggingLine(for: draft.loggingFamiliarity)
        let activityLine = activityLine(for: draft.activityLevel)
        let waterLine = waterLine(for: draft.waterAdequacy)
        let fastingLine = fastingLine(familiarity: draft.fastingFamiliarity, schedule: draft.fastingSchedulePreference)
        let weekendLine = weekendLine(for: draft.weekendEating)
        let cravingsLine = cravingsLine(for: draft.cravingsFrequency)

        // Only inspect age for safety classification. It never changes routine content or targets.
        let safety: PandaPlatePlanAgeSafety
        if let age = draft.ageYears {
            safety = age < 18 ? .under18 : .adult
        } else {
            safety = .ageNotProvided
        }

        // Body measurements are checked only for presence. Their values and directions are never read.
        let hasBodyProfile = draft.heightCentimeters != nil
            || draft.currentWeightKilograms != nil
            || draft.targetWeightKilograms != nil
        let bodyNeutralEmphasis = hasBodyProfile
            ? "Keep the routine comfortable and flexible; profile measurements do not change any targets here."
            : nil

        let weeklyFocus = draft.goal.detail
        let days = makeDays(context: context, supportLine: supportLine, loggingLine: loggingLine,
                            activityLine: activityLine, waterLine: waterLine, weeklyFocus: weeklyFocus)
        let premiumWeeks = makePremiumWeeks(context: context)

        return PandaPlatePlan(
            context: context,
            weeklyFocus: weeklyFocus,
            supportLine: supportLine,
            loggingLine: loggingLine,
            activityLine: activityLine,
            waterLine: waterLine,
            fastingLine: fastingLine,
            weekendLine: weekendLine,
            cravingsLine: cravingsLine,
            safety: safety,
            bodyNeutralEmphasis: bodyNeutralEmphasis,
            days: days,
            premiumWeeks: premiumWeeks,
            foodSuggestions: []
        )
    }

    private static func makeContext(from draft: PandaPlateOnboardingDraft) -> PandaPlatePlanContext {
        let mealCount = (1...5).contains(draft.mealsPerDay) ? draft.mealsPerDay : nil
        return PandaPlatePlanContext(
            mainFocus: draft.goal.rawValue,
            additionalGoals: draft.additionalGoals.sorted(),
            loggingFamiliarity: draft.loggingFamiliarity,
            mealsPerDay: mealCount,
            firstMealPeriod: meridiem(for: draft.firstMealTime),
            lastMealPeriod: meridiem(for: draft.lastMealTime),
            fastingFamiliarity: cleaned(draft.fastingFamiliarity),
            fastingSchedulePreference: cleaned(draft.fastingSchedulePreference),
            eatingLocations: draft.eatingLocations.sorted(),
            dietPreference: cleaned(draft.dietPreference),
            foodRestrictions: draft.foodRestrictions.sorted(),
            waterAdequacy: cleaned(draft.waterAdequacy),
            habitChanges: draft.habitChanges.sorted(),
            weekendEating: cleaned(draft.weekendEating),
            cravingsFrequency: cleaned(draft.cravingsFrequency),
            activityLevel: cleaned(draft.activityLevel),
            pipStyle: draft.pipStyle.rawValue,
            reminderPreference: cleaned(draft.reminderPreference)
        )
    }

    /// Converts a valid 24-hour input to its AM/PM period only; no duration or eating window is inferred.
    private static func meridiem(for time: String) -> String? {
        let trimmed = time.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MealTimeValidator.isValidOptional24HourTime(trimmed), !trimmed.isEmpty else { return nil }
        let hour = Int(trimmed.prefix(2)) ?? 0
        return hour < 12 ? "AM" : "PM"
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func supportLine(for style: PipStyle) -> String {
        switch style {
        case .cheerleader: return "Pip says: You’ve got this. Keep it small, and count what works for you."
        case .gentle: return "Pip is here at your pace. You can keep, change, or skip any step."
        case .straightTalker: return "Pip says: Keep the useful parts. Drop anything that doesn’t fit."
        case .mindful: return "Pip invites you to pause and notice what feels manageable today."
        }
    }

    private static func loggingLine(for familiarity: String) -> String {
        switch familiarity {
        case "This is new to me":
            return "Start with a meal name or a brief note only when logging feels useful."
        case "I’ve logged before but stopped", "I’ve logged before":
            return "Use the logging shortcuts that feel comfortable; every entry can be reviewed."
        case "I log regularly":
            return "Keep using the logging style that works for you; this plan adds no quota."
        default:
            return "Meal logging is optional; use a name or note if it helps your routine."
        }
    }

    private static func activityLine(for activity: String?) -> String {
        switch activity {
        case "Mostly sitting": return "Your movement context is noted. No exercise or activity target is added."
        case "Some movement through the day": return "Everyday movement can stay as it is; no extra activity target is added."
        case "Regular movement": return "Keep your current movement routine if it suits you; no additional target is added."
        case .none: return "Movement is optional context; no activity target is set."
        default: return "Movement is only a preference note; no activity target is set."
        }
    }

    private static func waterLine(for adequacy: String?) -> String {
        switch adequacy {
        case "Yes": return "You said your water routine feels adequate. No volume target is added."
        case "No": return "Water logging can be used if you find it helpful; no volume target is added."
        case "Not sure": return "Your water answer stays as context only; no volume target is added."
        case .none: return "Water logging is optional; no volume target is added."
        default: return "Your water answer stays as context only; no volume target is added."
        }
    }

    private static func fastingLine(familiarity: String?, schedule: String?) -> String {
        if let schedule {
            switch schedule {
            case "I already follow a schedule":
                return "You already follow a fasting schedule; it stays context only. No new window or recommendation is created."
            case "Not currently":
                return "You’re not currently following a fasting schedule; none is added. No recommendation is created."
            case "Prefer not to say":
                return "No fasting schedule is assumed. No window or recommendation is created."
            default:
                return "Your fasting schedule answer stays context only. No window or recommendation is created."
            }
        }
        if let familiarity {
            return "Fasting familiarity (\(familiarity)) is context only. No fasting window or recommendation is created."
        }
        return "No fasting window or recommendation is created."
    }

    private static func weekendLine(for answer: String?) -> String {
        switch answer {
        case "About the same": return "Keep the same flexible routine on weekends if that still fits."
        case "A little different": return "Leave room for weekend differences; no weekend rule is added."
        case "Not sure": return "Weekend rhythm stays open; no pattern is assumed."
        case .none: return "No weekend pattern is assumed."
        default: return "Weekend rhythm stays open; no score or rule is added."
        }
    }

    private static func cravingsLine(for answer: String?) -> String {
        switch answer {
        case "Often": return "You chose “Often.” That answer is context only; no foods are labelled or restricted by this plan."
        case "Sometimes": return "You chose “Sometimes.” That answer is context only; no foods are labelled or restricted by this plan."
        case "Rarely": return "You chose “Rarely.” That answer is context only; no foods are labelled or restricted by this plan."
        case .none: return "No cravings pattern is assumed."
        default: return "Cravings are context only; no foods are labelled or restricted by this plan."
        }
    }

    private static func makeDays(
        context: PandaPlatePlanContext,
        supportLine: String,
        loggingLine: String,
        activityLine: String,
        waterLine: String,
        weeklyFocus: String
    ) -> [PandaPlatePlanDay] {
        let mealAnchor: String
        if let count = context.mealsPerDay {
            mealAnchor = "Use one of your usual \(count) meal moments as an optional check-in; this is not a meal quota."
        } else {
            mealAnchor = "Use a meal moment that fits today, or skip this check-in."
        }

        let periodParts = [
            context.firstMealPeriod.map { "First meal · \($0)" },
            context.lastMealPeriod.map { "Last meal · \($0)" }
        ].compactMap { $0 }
        let periodLine = periodParts.isEmpty
            ? "Meal periods are open; no times are assumed."
            : "Your selected periods: \(periodParts.joined(separator: " · ")). No schedule is added."

        let placeLine = context.eatingLocations.isEmpty
            ? "No usual place is selected; any place that suits your day is fine."
            : "Choose any of your usual places: \(context.eatingLocations.joined(separator: ", "))."

        let selectedHabits = context.habitChanges.filter { $0 != "No change for now" }
        let focusParts = selectedHabits + context.additionalGoals
        let habitLine: String
        if !focusParts.isEmpty {
            habitLine = "Your selected focus: \(focusParts.joined(separator: ", ")). Keep any part flexible and skip what doesn’t fit."
        } else if context.habitChanges.contains("No change for now") {
            habitLine = "You chose no change for now. Keep your current routine; no new habit is suggested."
        } else {
            habitLine = "Your focus is \(weeklyFocus). Keep it flexible and skip anything that doesn’t fit."
        }

        let foodDetail: String
        var foodPreferences: [String] = []
        if let diet = context.dietPreference { foodPreferences.append("Preference: \(diet)") }
        if context.foodRestrictions.contains("No restrictions") {
            foodPreferences.append("No restrictions selected")
        } else if !context.foodRestrictions.isEmpty {
            foodPreferences.append("Avoid: \(context.foodRestrictions.joined(separator: ", "))")
        }
        if !foodPreferences.isEmpty {
            foodDetail = "Keep your choices visible for reference (\(foodPreferences.joined(separator: "; "))). No food or recipe suggestions are generated."
        } else {
            foodDetail = "No food preferences are assumed. This plan makes no food or recipe suggestions."
        }

        return [
            PandaPlatePlanDay(dayNumber: 1, title: "Start with one familiar moment", detail: mealAnchor),
            PandaPlatePlanDay(dayNumber: 2, title: "Use your own meal periods", detail: periodLine),
            PandaPlatePlanDay(dayNumber: 3, title: "Choose a place that fits", detail: placeLine),
            PandaPlatePlanDay(dayNumber: 4, title: "Keep your chosen focus", detail: habitLine),
            PandaPlatePlanDay(dayNumber: 5, title: "Keep food preferences visible", detail: "\(foodDetail) \(fastingLine(familiarity: context.fastingFamiliarity, schedule: context.fastingSchedulePreference))"),
            PandaPlatePlanDay(dayNumber: 6, title: "Leave room for real life", detail: "\(activityLine) \(waterLine) \(weekendLine(for: context.weekendEating)) \(cravingsLine(for: context.cravingsFrequency))"),
            PandaPlatePlanDay(dayNumber: 7, title: "Check in with Pip", detail: "\(loggingLine) \(supportLine)")
        ]
    }

    private static func makePremiumWeeks(context: PandaPlatePlanContext) -> [PandaPlatePlanWeek] {
        let chosenFocus = context.habitChanges.first(where: { $0 != "No change for now" })
            ?? context.additionalGoals.first
            ?? context.mainFocus
        let placeTask = context.eatingLocations.isEmpty
            ? "Keep the routine flexible across places."
            : "Review which usual place felt easiest: \(context.eatingLocations.joined(separator: ", "))."

        let definitions: [(String, String, [String])] = [
            ("Settle into a rhythm", "Which routine step felt easiest to keep, if any?", [
                "Review one familiar meal moment.", "Edit or skip a step that did not fit."
            ]),
            ("Make it fit your week", "What would you like to keep or simplify?", [
                placeTask, "Keep meal periods as context, not a schedule."
            ]),
            ("Revisit your own focus", "Does your chosen focus still feel useful?", [
                "Check in on \(chosenFocus) only if you want to.", "No food suggestions or targets are added."
            ]),
            ("Choose what stays", "Which parts would you like to carry forward?", [
                "Keep, edit, or remove any routine step.", "Use Pip’s support in the style you selected."
            ])
        ]

        return definitions.enumerated().map { index, definition in
            PandaPlatePlanWeek(
                weekNumber: index + 1,
                title: definition.0,
                checkInPrompt: definition.1,
                tasks: definition.2.enumerated().map { taskIndex, title in
                    PandaPlatePlanTask(id: "week-\(index + 1)-task-\(taskIndex + 1)", title: title)
                }
            )
        }
    }
}
