import Foundation

/// Session-only answers gathered by `PandaPlateCategorizedOnboardingFlow`.
/// This draft deliberately contains no BMI, daily calorie target, health score, or medical assessment.
struct PandaPlateOnboardingDraft {
    var goal: WellnessGoal = .balanced
    var additionalGoals: Set<String> = []
    var loggingFamiliarity = "This is new to me"
    var fastingFamiliarity: String?

    var companionName = "Pip"
    var userName = ""
    var pipStyle: PipStyle = .gentle
    var reminderPreference: String?

    var mealsPerDay = 3
    var firstMealTime = ""
    var lastMealTime = ""
    var fastingSchedulePreference: String?
    var eatingLocations: Set<String> = []
    var dietPreference: String?
    var foodRestrictions: Set<String> = []
    var waterAdequacy: String?
    var habitChanges: Set<String> = []
    var weekendEating: String?
    var cravingsFrequency: String?
    var activityLevel: String?
    /// Preference only — Smart vs Add-all. No BMR/TDEE computed yet.
    var activityCalorieMode: ActivityCalorieMode = .smart
    /// User opted into Apple Health during onboarding (or skipped).
    var healthKitConnected: Bool = false
    var healthKitSkipped: Bool = false
    /// Optional display precision for the session-only weight selector; never used for BMI or plan targets.
    var currentWeightKilogramsPrecise: Double?

    // Attribution (early after welcome)
    var attributionSource: String?

    // Sex/gender before body metrics
    var sexGender: String?

    // Required session-only profile values; they are not used for derived calculations.
    var ageYears: Int?
    var heightCentimeters: Int?
    var currentWeightKilograms: Int?
    var targetWeightKilograms: Int?

    // Retained for current AppStore compatibility; no pace question or estimate is produced by onboarding.
    var goalPace: String?

    // Retained for current AppStore compatibility; no weight-date projection is produced by onboarding.
    var estimatedReachDate: Date?
    var estimatedReachSkippedUnder18 = false

    // Apple identity fields required to complete onboarding and start a proxy session.
    var appleUserIdentifier: String?
    var appleEmail: String?
    var continuedWithoutAccount = false

    var sanitizedCompanionName: String {
        let trimmed = companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pip" : String(trimmed.prefix(24))
    }

    var sanitizedUserName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "friend" : String(trimmed.prefix(24))
    }
}
