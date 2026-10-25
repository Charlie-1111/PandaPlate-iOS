import Foundation

/// Session-only answers gathered by `PandaPlateCategorizedOnboardingFlow`.
/// This draft deliberately contains no BMI, daily calorie target, health score, or medical assessment.
struct PandaPlateOnboardingDraft {
    var goal: WellnessGoal = .balanced
    var additionalGoals: Set<String> = []
    var loggingFamiliarity = "This is new to me"
    var fastingFamiliarity: String? = "No"

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
    /// Precise current weight for BMI (tenths). Falls back to whole kg when nil.
    var currentWeightKilogramsPrecise: Double?

    // Attribution (early after welcome)
    var attributionSource: String?

    // Sex/gender before body metrics
    var sexGender: String?

    // Required by the flow: each stays nil until the user explicitly selects it.
    var ageYears: Int?
    var heightCentimeters: Int?
    var currentWeightKilograms: Int?
    var targetWeightKilograms: Int?

    // Goal pace after target weight: Slow / Steady / Faster
    var goalPace: String?

    // Linear weight-date estimate (nil when skipped for under-18 or incomplete inputs)
    var estimatedReachDate: Date?
    var estimatedReachSkippedUnder18 = false

    // Account (Sign in with Apple / Google) — optional, session-only
    var appleUserIdentifier: String?
    var appleEmail: String?
    var googleUserIdentifier: String?
    var googleEmail: String?
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
