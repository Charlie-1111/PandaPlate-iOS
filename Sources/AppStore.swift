import Foundation
import SwiftUI

enum MealTimeValidator {
    static func isValidOptional24HourTime(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return true }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }
}

enum WellnessGoal: String, CaseIterable, Identifiable {
    case balanced = "Feel more balanced"
    case maintain = "Build a steady rhythm"
    case change = "Try one new habit"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .balanced: "leaf.fill"
        case .maintain: "calendar"
        case .change: "sparkles"
        }
    }
    var detail: String {
        switch self {
        case .balanced: "Build steady everyday habits"
        case .maintain: "Make everyday routines feel more doable"
        case .change: "Start with one small experiment"
        }
    }
}

enum PipStyle: String, CaseIterable, Identifiable {
    case cheerleader = "Cheerleader"
    case gentle = "Gentle friend"
    case straightTalker = "Straight talker"
    case mindful = "Mindful guide"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .cheerleader: "sparkles"
        case .gentle: "heart.fill"
        case .straightTalker: "bubble.left.fill"
        case .mindful: "leaf.fill"
        }
    }
}

struct MealEntry: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int?
    let time: Date
    let imageData: Data?
}

struct WorkoutEntry: Identifiable {
    let id = UUID()
    let activity: String
    let durationMinutes: Int
    let time: Date
    /// Real source only (e.g. HealthKit totalEnergyBurned). nil = Unknown — never invent; blank ≠ 0.
    let activeEnergyKcal: Int?
}

struct WeightLogEntry: Identifiable {
    let id = UUID()
    let kilograms: Double
    let time: Date
}

struct FastingEntry: Identifiable {
    let id = UUID()
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
}

@MainActor
final class AppStore: ObservableObject {
    static let maximumMealsPerSession = 20
    @Published var finishedOnboarding = false
    @Published var goal: WellnessGoal = .balanced
    @Published var pipStyle: PipStyle = .gentle
    @Published var companionName = "Pip"
    @Published var userName = "friend"
    @Published var loggingFamiliarity = "This is new to me"
    @Published var fastingFamiliarity = "No"
    @Published var reminderPreference: String?
    @Published var supportFocus: Set<String> = []
    @Published var mealsPerDay = 3
    @Published var firstMealTime = ""
    @Published var lastMealTime = ""
    @Published var mealPlaces: Set<String> = ["Cook at home"]
    @Published var fastingSchedulePreference: String?
    @Published var dietPreference: String?
    @Published var foodRestrictions: Set<String> = []
    @Published var waterAdequacy: String?
    @Published var habitChanges: Set<String> = []
    @Published var weekendEating: String?
    @Published var cravingsFrequency: String?
    @Published var activityLevel: String?
    @Published var activityCalorieMode: ActivityCalorieMode = .smart
    @Published var healthKitConnected = false
    @Published var currentWeightKilogramsPrecise: Double?
    /// Cached steps from HealthKitActivitySync for Home honesty line.
    @Published var todayStepsFromHealth: Int?
    @Published var ageYears: Int?
    @Published var heightCentimeters: Int?
    @Published var currentWeightKilograms: Int?
    @Published var targetWeightKilograms: Int?
    @Published var attributionSource: String?
    @Published var sexGender: String?
    @Published var goalPace: String?
    @Published var estimatedReachDate: Date?
    @Published var estimatedReachSkippedUnder18 = false
    @Published var appleUserIdentifier: String?
    @Published var appleEmail: String?
    @Published var googleUserIdentifier: String?
    @Published var googleEmail: String?
    @Published var continuedWithoutAccount = false
    @Published var waterServingsML: [Int?] = Array(repeating: nil, count: WaterQuickLogModel.maximumCups)
    @Published private(set) var canUndoWaterChange = false
    private var previousWaterServingsML: [Int?]?
    var waterML: Int { WaterQuickLogModel.total(for: waterServingsML) }
    @Published var meals: [MealEntry] = []
    @Published var workouts: [WorkoutEntry] = []
    @Published var weightLogs: [WeightLogEntry] = []
    @Published var fastingEntries: [FastingEntry] = []
    @Published var fastingStartedAt: Date?

    var caloriesEaten: Int? {
        let logged = meals.compactMap(\.calories)
        guard !logged.isEmpty else { return nil }
        return logged.reduce(0) { total, value in
            min(100_000, total + min(10_000, max(0, value)))
        }
    }

    func addMeal(name: String, calories: Int?, imageData: Data?) {
        guard meals.count < Self.maximumMealsPerSession else { return }
        let boundedCalories = calories.flatMap { (0...10_000).contains($0) ? $0 : nil }
        let boundedImage = imageData.flatMap { $0.count <= 1_000_000 ? $0 : nil }
        meals.append(MealEntry(name: name, calories: boundedCalories, time: Date(), imageData: boundedImage))
        SoftShowUpStore.shared.markSeen()
        // Soft wall + review milestone: first honest food log confirmed.
        FirstSuccessMoments.shared.noteFirstFoodLogConfirmed()
    }

    func removeMeal(id: UUID) {
        meals.removeAll { $0.id == id }
    }

    @discardableResult
    func setWaterServing(_ amountML: Int?, at index: Int) -> Bool {
        guard waterServingsML.indices.contains(index) else { return false }
        if let amountML, !WaterQuickLogModel.allowedServingSizes.contains(amountML) { return false }
        var updated = waterServingsML
        updated[index] = amountML
        guard updated != waterServingsML else { return false }
        guard WaterQuickLogModel.total(for: updated) <= WaterQuickLogModel.maximumTotalML else { return false }
        previousWaterServingsML = waterServingsML
        canUndoWaterChange = true
        waterServingsML = updated
        return true
    }

    @discardableResult
    func undoLastWaterChange() -> Bool {
        guard canUndoWaterChange, let previousWaterServingsML else { return false }
        self.previousWaterServingsML = nil
        canUndoWaterChange = false
        waterServingsML = previousWaterServingsML
        return true
    }

    @discardableResult
    func addWater(_ amount: Int = WaterServingSize.glass.milliliters) -> Bool {
        guard WaterQuickLogModel.allowedServingSizes.contains(amount),
              let index = waterServingsML.firstIndex(where: { $0 == nil }) else { return false }
        return setWaterServing(amount, at: index)
    }

    @discardableResult
    func addWorkout(activity: String, durationMinutes: Int, time: Date = Date(), activeEnergyKcal: Int? = nil) -> Bool {
        let trimmed = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only store kcal from a real source (HealthKit). Manual logs stay nil = Unknown.
        let kcal = activeEnergyKcal.flatMap { (1...20_000).contains($0) ? $0 : nil }
        guard !trimmed.isEmpty,
              trimmed.count <= WorkoutFeatureRules.maximumActivityNameLength,
              trimmed.rangeOfCharacter(from: .controlCharacters) == nil,
              (1...WorkoutFeatureRules.maximumCustomDuration).contains(durationMinutes),
              workouts.count < WorkoutFeatureRules.maximumSessionEntries else { return false }
        workouts.append(WorkoutEntry(activity: trimmed, durationMinutes: durationMinutes, time: time, activeEnergyKcal: kcal))
        return true
    }


    @discardableResult
    func addWeight(kilograms: Double, time: Date = Date()) -> Bool {
        guard kilograms >= 25, kilograms <= 300, weightLogs.count < 100 else { return false }
        weightLogs.append(WeightLogEntry(kilograms: kilograms, time: time))
        // Keep profile current weight in sync with the check-in (session).
        currentWeightKilogramsPrecise = kilograms
        currentWeightKilograms = Int(kilograms.rounded())
        return true
    }

    func removeWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
    }

    func removeFastingEntry(id: UUID) {
        fastingEntries.removeAll { $0.id == id }
    }

    func startFasting(at time: Date = Date()) {
        guard fastingStartedAt == nil else { return }
        fastingStartedAt = time
    }

    func cancelFasting() {
        fastingStartedAt = nil
    }

    @discardableResult
    func endFasting(at time: Date = Date()) -> Bool {
        guard let start = fastingStartedAt, time > start else { return false }
        let elapsed = time.timeIntervalSince(start)
        guard elapsed <= 172_800, fastingEntries.count < 100 else { return false }
        let duration = max(0, Int(elapsed))
        fastingEntries.append(FastingEntry(startedAt: start, endedAt: time, durationSeconds: duration))
        fastingStartedAt = nil
        return true
    }

    func applyOnboardingDraft(_ draft: PandaPlateOnboardingDraft) {
        goal = draft.goal
        supportFocus = draft.additionalGoals
        loggingFamiliarity = draft.loggingFamiliarity
        fastingFamiliarity = draft.fastingFamiliarity ?? ""
        companionName = draft.sanitizedCompanionName
        userName = draft.sanitizedUserName
        pipStyle = draft.pipStyle
        reminderPreference = draft.reminderPreference
        mealsPerDay = draft.mealsPerDay
        firstMealTime = draft.firstMealTime
        lastMealTime = draft.lastMealTime
        fastingSchedulePreference = draft.fastingSchedulePreference
        mealPlaces = draft.eatingLocations
        dietPreference = draft.dietPreference
        foodRestrictions = draft.foodRestrictions
        waterAdequacy = draft.waterAdequacy
        habitChanges = draft.habitChanges
        weekendEating = draft.weekendEating
        cravingsFrequency = draft.cravingsFrequency
        activityLevel = draft.activityLevel
        activityCalorieMode = draft.activityCalorieMode
        healthKitConnected = draft.healthKitConnected
        currentWeightKilogramsPrecise = draft.currentWeightKilogramsPrecise
        todayStepsFromHealth = HealthKitActivitySync.shared.todaySteps
        ageYears = draft.ageYears
        heightCentimeters = draft.heightCentimeters
        currentWeightKilograms = draft.currentWeightKilograms
        targetWeightKilograms = draft.targetWeightKilograms
        attributionSource = draft.attributionSource
        sexGender = draft.sexGender
        goalPace = draft.goalPace
        estimatedReachDate = draft.estimatedReachDate
        estimatedReachSkippedUnder18 = draft.estimatedReachSkippedUnder18
        appleUserIdentifier = draft.appleUserIdentifier
        appleEmail = draft.appleEmail
        googleUserIdentifier = draft.googleUserIdentifier
        googleEmail = draft.googleEmail
        continuedWithoutAccount = draft.continuedWithoutAccount
        finishedOnboarding = true
        Task { @MainActor in
            await ReminderNotifications.reschedule(
                preference: reminderPreference,
                firstMealTime: firstMealTime,
                companionName: companionName
            )
        }
    }

    func resetDemoSession() {
        ReminderNotifications.cancelAll()
        meals = []
        workouts = []
        weightLogs = []
        fastingEntries = []
        fastingStartedAt = nil
        waterServingsML = Array(repeating: nil, count: WaterQuickLogModel.maximumCups)
        previousWaterServingsML = nil
        canUndoWaterChange = false
        goal = .balanced
        pipStyle = .gentle
        companionName = "Pip"
        userName = "friend"
        loggingFamiliarity = "This is new to me"
        fastingFamiliarity = "No"
        reminderPreference = nil
        supportFocus = []
        mealsPerDay = 3
        firstMealTime = ""
        lastMealTime = ""
        mealPlaces = ["Cook at home"]
        fastingSchedulePreference = nil
        dietPreference = nil
        foodRestrictions = []
        waterAdequacy = nil
        habitChanges = []
        weekendEating = nil
        cravingsFrequency = nil
        activityLevel = nil
        activityCalorieMode = .smart
        healthKitConnected = false
        currentWeightKilogramsPrecise = nil
        todayStepsFromHealth = nil
        HealthKitActivitySync.shared.resetDemoState()
        ageYears = nil
        heightCentimeters = nil
        currentWeightKilograms = nil
        targetWeightKilograms = nil
        attributionSource = nil
        sexGender = nil
        goalPace = nil
        estimatedReachDate = nil
        estimatedReachSkippedUnder18 = false
        appleUserIdentifier = nil
        appleEmail = nil
        googleUserIdentifier = nil
        googleEmail = nil
        continuedWithoutAccount = false
    }
}
