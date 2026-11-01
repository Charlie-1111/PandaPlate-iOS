import Foundation

/// Answers that should change the routine after setup. No calorie budget or medical target is derived here.
struct SessionPlanInput: Equatable {
    var goal: WellnessGoal = .balanced
    var supportFocus: Set<String> = []
    var pipStyle: PipStyle = .gentle
    var companionName: String = "Pip"
    var loggingFamiliarity: String = "This is new to me"
    var fastingFamiliarity: String = "No"
    var mealsPerDay: Int = 3
    var firstMealTime: String = ""
    var lastMealTime: String = ""
    var fastingSchedulePreference: String?
    var mealPlaces: Set<String> = []
    var dietPreference: String?
    var foodRestrictions: Set<String> = []
    var waterAdequacy: String?
    var habitChanges: Set<String> = []
    var weekendEating: String?
    var cravingsFrequency: String?
    var activityLevel: String?
    var activityCalorieMode: ActivityCalorieMode = .smart
    var ageYears: Int?
    var goalPace: String?
    var estimatedReachDate: Date?
    var estimatedReachSkippedUnder18 = false
    var currentWeightKilograms: Int?
    var targetWeightKilograms: Int?
    var mealsLogged: Int = 0
    var waterMilliliters: Int = 0
}

struct SessionPlan: Equatable {
    struct Item: Equatable, Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    let title: String
    let pipLine: String
    let items: [Item]
    /// Meal count the person chose. Home compares logs to this rhythm, not to a calorie target.
    let mealRhythm: Int
    /// They said their water routine could use more check-ins.
    let emphasizesWater: Bool
    /// Fasting stays on the plan only when they said they know it or already follow a schedule.
    let showsFasting: Bool
    /// Diet and avoided foods, for the meal logger. Nil when they gave no food note.
    let foodReminder: String?
    let waterCaption: String
}

enum SessionPlanBuilder {
    static func make(
        _ input: SessionPlanInput,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> SessionPlan {
        let meals = min(5, max(1, input.mealsPerDay))
        let companion = input.companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let pipName = companion.isEmpty ? "Pip" : companion
        let title = title(for: input.goal)
        let emphasizesWater = input.waterAdequacy == "No"
        let showsFasting = wantsFasting(input)
        let foodReminder = foodReminder(diet: input.dietPreference, restrictions: input.foodRestrictions)
        var items: [SessionPlan.Item] = []

        items.append(SessionPlan.Item(
            id: "meals",
            symbol: "fork.knife",
            title: "\(input.mealsLogged) of \(meals) meals",
            detail: mealDetail(input, meals: meals)
        ))

        if let foodReminder {
            items.append(SessionPlan.Item(
                id: "food",
                symbol: "carrot.fill",
                title: "Food note",
                detail: foodReminder
            ))
        }

        if !input.mealPlaces.isEmpty {
            items.append(SessionPlan.Item(
                id: "places",
                symbol: "house.fill",
                title: "Usual places",
                detail: input.mealPlaces.sorted().joined(separator: ", ")
            ))
        }

        items.append(SessionPlan.Item(
            id: "water",
            symbol: "drop.fill",
            title: emphasizesWater ? "Water check-ins" : "Water",
            detail: waterDetail(input, milliliters: input.waterMilliliters)
        ))

        if showsFasting {
            items.append(SessionPlan.Item(
                id: "fasting",
                symbol: "moon.stars.fill",
                title: "Fasting",
                detail: fastingDetail(input)
            ))
        }

        let habits = input.habitChanges.filter { $0 != "No change for now" }
        if !habits.isEmpty {
            items.append(SessionPlan.Item(
                id: "habit",
                symbol: "leaf.fill",
                title: "Today’s focus",
                detail: habits.sorted().joined(separator: ", ")
            ))
        }

        if !input.supportFocus.isEmpty {
            items.append(SessionPlan.Item(
                id: "support",
                symbol: "heart.fill",
                title: "Extra support",
                detail: input.supportFocus.sorted().joined(separator: ", ")
            ))
        }

        if let movement = movementDetail(input) {
            items.append(SessionPlan.Item(
                id: "movement",
                symbol: "figure.walk",
                title: "Movement",
                detail: movement
            ))
        }

        if calendar.isDateInWeekend(now), input.weekendEating == "A little different" {
            items.append(SessionPlan.Item(
                id: "weekend",
                symbol: "calendar",
                title: "Weekend",
                detail: "You said weekends can look different. Log what actually happens."
            ))
        }

        if input.cravingsFrequency == "Often" {
            items.append(SessionPlan.Item(
                id: "cravings",
                symbol: "heart.text.square.fill",
                title: "Cravings",
                detail: "You said cravings come up often. Log the bite if you want a record. Nothing here is forbidden."
            ))
        }

        if let pace = paceDetail(input) {
            items.append(SessionPlan.Item(
                id: "pace",
                symbol: "tortoise.fill",
                title: "Pace estimate",
                detail: pace
            ))
        }

        return SessionPlan(
            title: title,
            pipLine: pipLine(style: input.pipStyle, name: pipName, title: title, familiarity: input.loggingFamiliarity),
            items: items,
            mealRhythm: meals,
            emphasizesWater: emphasizesWater,
            showsFasting: showsFasting,
            foodReminder: foodReminder,
            waterCaption: waterCaption(input)
        )
    }

    private static func title(for goal: WellnessGoal) -> String {
        switch goal {
        case .balanced: return "A balanced day"
        case .maintain: return "A steady rhythm"
        case .change: return "One new habit"
        }
    }

    private static func pipLine(style: PipStyle, name: String, title: String, familiarity: String) -> String {
        let simple = familiarity == "This is new to me" ? " One step is enough." : ""
        switch style {
        case .cheerleader:
            return "\(name) is with you. Today is \(title.lowercased()).\(simple)"
        case .gentle:
            return "No rush. Today is \(title.lowercased()).\(simple)"
        case .straightTalker:
            return "Today: \(title).\(simple)"
        case .mindful:
            return "Notice one part of \(title.lowercased()).\(simple)"
        }
    }

    private static func mealDetail(_ input: SessionPlanInput, meals: Int) -> String {
        let first = input.firstMealTime.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = input.lastMealTime.trimmingCharacters(in: .whitespacesAndNewlines)
        if !first.isEmpty, !last.isEmpty {
            return "You chose \(meals) meals, from \(first) to \(last). This is a rhythm, not a calorie target."
        }
        return "You chose \(meals) meals. This is a rhythm, not a calorie target."
    }

    private static func foodReminder(diet: String?, restrictions: Set<String>) -> String? {
        let avoided = restrictions.filter { $0 != "No restrictions" }.sorted()
        let dietText = diet?.trimmingCharacters(in: .whitespacesAndNewlines)
        let dietNote = (dietText?.isEmpty == false) ? dietText : nil
        if dietNote == nil, avoided.isEmpty { return nil }
        if let dietNote, !avoided.isEmpty {
            return "\(dietNote). You also noted avoiding \(avoided.joined(separator: ", ")). This is a reminder, not a menu."
        }
        if let dietNote { return "\(dietNote). A reminder when you log, not a calculated menu." }
        return "You noted avoiding \(avoided.joined(separator: ", "))."
    }

    private static func waterDetail(_ input: SessionPlanInput, milliliters: Int) -> String {
        let logged = milliliters > 0 ? " \(milliliters) ml logged this session." : ""
        switch input.waterAdequacy {
        case "No":
            return "You said this routine could use more check-ins. No amount is prescribed.\(logged)"
        case "Yes":
            return "You said this feels fine. Log a cup only if you want to.\(logged)"
        default:
            return "Optional check-in. No hydration target is calculated.\(logged)"
        }
    }

    private static func waterCaption(_ input: SessionPlanInput) -> String {
        switch input.waterAdequacy {
        case "No":
            return "On your plan · you asked for more check-ins. No amount is prescribed."
        case "Yes":
            return "You said this feels fine. Cups are optional."
        default:
            return "Optional. No hydration target is calculated."
        }
    }

    private static func wantsFasting(_ input: SessionPlanInput) -> Bool {
        if input.fastingFamiliarity == "Yes" { return true }
        return input.fastingSchedulePreference == "I already follow a schedule"
    }

    private static func fastingDetail(_ input: SessionPlanInput) -> String {
        if input.fastingSchedulePreference == "I already follow a schedule" {
            return "You already follow a schedule. The fasting log records elapsed time only."
        }
        return "You said fasting is familiar. The log records elapsed time only — no schedule is prescribed."
    }

    private static func movementDetail(_ input: SessionPlanInput) -> String? {
        let level: String
        switch input.activityLevel {
        case "Mostly sitting":
            level = "You described mostly sitting. A short walk still counts if you log it."
        case "Some movement through the day":
            level = "You described some movement through the day."
        case "Regular movement":
            level = "You described regular movement."
        default:
            level = ""
        }
        let mode = input.activityCalorieMode == .addAll
            ? " Logged activity energy stays on the workout, separate from meals."
            : " Activity stays separate from meal estimates."
        if level.isEmpty, input.activityLevel == nil { return "Activity stays separate from meal estimates." }
        return level + mode
    }

    private static func paceDetail(_ input: SessionPlanInput) -> String? {
        if input.estimatedReachSkippedUnder18 { return nil }
        if let age = input.ageYears, age < 18 { return nil }
        guard let date = input.estimatedReachDate,
              let current = input.currentWeightKilograms,
              let target = input.targetWeightKilograms,
              let pace = input.goalPace else { return nil }
        let formatted = dateFormatter.string(from: date)
        return "A linear estimate from \(current) kg toward \(target) kg at a \(pace.lowercased()) pace: \(formatted). Not a prescription."
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_HK")
        formatter.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

extension AppStore {
    var sessionPlanInput: SessionPlanInput {
        SessionPlanInput(
            goal: goal,
            supportFocus: supportFocus,
            pipStyle: pipStyle,
            companionName: companionName,
            loggingFamiliarity: loggingFamiliarity,
            fastingFamiliarity: fastingFamiliarity,
            mealsPerDay: mealsPerDay,
            firstMealTime: firstMealTime,
            lastMealTime: lastMealTime,
            fastingSchedulePreference: fastingSchedulePreference,
            mealPlaces: mealPlaces,
            dietPreference: dietPreference,
            foodRestrictions: foodRestrictions,
            waterAdequacy: waterAdequacy,
            habitChanges: habitChanges,
            weekendEating: weekendEating,
            cravingsFrequency: cravingsFrequency,
            activityLevel: activityLevel,
            activityCalorieMode: activityCalorieMode,
            ageYears: ageYears,
            goalPace: goalPace,
            estimatedReachDate: estimatedReachDate,
            estimatedReachSkippedUnder18: estimatedReachSkippedUnder18,
            currentWeightKilograms: currentWeightKilograms,
            targetWeightKilograms: targetWeightKilograms,
            mealsLogged: meals.count,
            waterMilliliters: waterML
        )
    }

    var sessionPlan: SessionPlan { SessionPlanBuilder.make(sessionPlanInput) }
}

extension PandaPlateOnboardingDraft {
    var sessionPlanInput: SessionPlanInput {
        SessionPlanInput(
            goal: goal,
            supportFocus: additionalGoals,
            pipStyle: pipStyle,
            companionName: sanitizedCompanionName,
            loggingFamiliarity: loggingFamiliarity,
            fastingFamiliarity: fastingFamiliarity ?? "No",
            mealsPerDay: mealsPerDay,
            firstMealTime: firstMealTime,
            lastMealTime: lastMealTime,
            fastingSchedulePreference: fastingSchedulePreference,
            mealPlaces: eatingLocations,
            dietPreference: dietPreference,
            foodRestrictions: foodRestrictions,
            waterAdequacy: waterAdequacy,
            habitChanges: habitChanges,
            weekendEating: weekendEating,
            cravingsFrequency: cravingsFrequency,
            activityLevel: activityLevel,
            activityCalorieMode: activityCalorieMode,
            ageYears: ageYears,
            goalPace: goalPace,
            estimatedReachDate: estimatedReachDate,
            estimatedReachSkippedUnder18: estimatedReachSkippedUnder18,
            currentWeightKilograms: currentWeightKilograms,
            targetWeightKilograms: targetWeightKilograms
        )
    }

    var sessionPlan: SessionPlan { SessionPlanBuilder.make(sessionPlanInput) }
}
