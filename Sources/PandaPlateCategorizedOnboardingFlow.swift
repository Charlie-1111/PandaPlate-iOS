import SwiftUI
import UIKit
import UserNotifications
import StoreKit
import AuthenticationServices
import GoogleSignIn

/// A drop-in onboarding flow. It owns only temporary UI state; the host decides what to store.
/// It does not edit AppStore, Home/navigation, health data, meals, or nutrition calculations.
struct PandaPlateCategorizedOnboardingFlow: View {
    var onComplete: (PandaPlateOnboardingDraft) -> Void = { _ in }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var step: Step = .welcome
    @State private var draft = PandaPlateOnboardingDraft()
    @State private var skipRevealAnimation = false
    @State private var teaserIsVisible = false
    @State private var revealDragTranslation: CGFloat = 0
    @State private var revealCompleted = false
    @State private var showMidflowSoftPaywall = false
    @State private var didRequestMidflowReview = false
    @State private var planBuildProgress: Double = 0
    @State private var planBuildPhaseIndex: Int = 0
    @State private var planBuildPausedForQuestion = false
    @State private var planInterruptIndex: Int = 0
    @State private var showBMISourceSheet = false
    @State private var presentedLegalDocument: PandaPlateLegal.Document? = nil
    /// Welcome “I already have an account” shortcut — Back must return to welcome, not softPaywall.
    @State private var enteredAccountFromWelcomeShortcut = false
    @State private var weightPreciseKg: Double?
    @State private var healthConnectBusy = false
    @State private var notificationRequestBusy = false
    @ObservedObject private var healthSync = HealthKitActivitySync.shared
    @State private var appleSignInError: String?
    @State private var googleSignInError: String?
    @FocusState private var focusedField: Field?
    @Environment(\.requestReview) private var requestReview

    private enum Field: Hashable { case petName, userName }

    private enum Step: Int, CaseIterable {
        case welcome
        case attribution
        case mainGoal
        case extraGoals
        case trackingExperience
        case smallStepsIntro
        case fastingFamiliarity
        case fastingContext
        case pipTeaser
        case pipReveal
        case pipName
        case userName
        case tone
        case toneInterstitial
        case reminders
        case routineIntro
        case mealsPerDay
        case mealWindow
        case fastingSchedule
        case eatingLocations
        case dietPreference
        case foodRestrictions
        case waterAdequacy
        case habitChanges
        case weekendEating
        case cravings
        case activityLevel
        case connectHealth
        case activityCalorieMode
        case sexGender
        case age
        case height
        case currentWeight
        case targetWeight
        case goalPace
        case weightProjection
        case planBuilding
        case finish
        case rateApp
        case softPaywall
        case account

        var category: String {
            switch self {
            case .welcome, .attribution, .mainGoal, .extraGoals, .trackingExperience, .smallStepsIntro,
                 .fastingFamiliarity, .fastingContext:
                "Goals & experience"
            case .pipTeaser, .pipReveal, .pipName, .userName, .tone, .toneInterstitial, .reminders:
                "Meet Pip & support"
            case .routineIntro, .mealsPerDay, .mealWindow, .fastingSchedule, .eatingLocations,
                 .dietPreference, .foodRestrictions, .waterAdequacy, .habitChanges:
                "Eating routine"
            case .weekendEating, .cravings, .activityLevel, .connectHealth, .activityCalorieMode, .sexGender, .age, .height, .currentWeight, .targetWeight,
                 .goalPace, .weightProjection:
                "Personal context"
            case .planBuilding, .finish: "Your setup"
            case .rateApp, .softPaywall, .account: "Almost ready"
            }
        }

        var title: String {
            switch self {
            case .welcome: "Small bites. Big little wins."
            case .attribution: "How did you hear about us?"
            case .mainGoal: "What feels important right now?"
            case .extraGoals: "Anything else you’d like to focus on?"
            case .trackingExperience: "Have you used a food log before?"
            case .smallStepsIntro: "A few notes about small steps."
            case .fastingFamiliarity: "Have you heard of intermittent fasting?"
            case .fastingContext: "A little context, only if you want it."
            case .pipTeaser: "Let’s meet your virtual pet!"
            case .pipReveal: "Swipe up to see who’s there"
            case .pipName: "Name your companion"
            case .userName: "What should Pip call you?"
            case .tone: "How should Pip encourage you?"
            case .toneInterstitial: "Small steps count. Keep logging!"
            case .reminders: "Would a reminder feel useful?"
            case .routineIntro: "Now let’s talk about your eating habits."
            case .mealsPerDay: "How many meals fit your day?"
            case .mealWindow: "When do meals usually fit?"
            case .fastingSchedule: "Do you already follow a fasting schedule?"
            case .eatingLocations: "Where do you usually eat?"
            case .dietPreference: "What kind of food preference would you like to note?"
            case .foodRestrictions: "Are there foods you choose to avoid?"
            case .waterAdequacy: "How does your water routine feel?"
            case .habitChanges: "What small changes would you like to focus on?"
            case .weekendEating: "Does your eating routine change on weekends?"
            case .cravings: "How often do cravings come up for you?"
            case .activityLevel: "How would you describe your usual movement?"
            case .connectHealth: "Connect Apple Health"
            case .activityCalorieMode: "How should activity factor into your preferences?"
            case .sexGender: "How do you describe yourself?"
            case .age: "How old are you?"
            case .height: "How tall are you?"
            case .currentWeight: "What's your current weight?"
            case .targetWeight: "What target weight do you have in mind?"
            case .goalPace: "What pace feels right?"
            case .weightProjection: "A simple estimate"
            case .planBuilding: "Personalizing your plan"
            case .finish: "Your setup"
            case .rateApp: "Enjoying PandaPlate?"
            case .softPaywall: "A little more with Pip"
            case .account: "Create your account"
            }
        }

        var symbol: String {
            switch self {
            case .mainGoal, .extraGoals, .smallStepsIntro: "leaf.fill"
            case .attribution: "megaphone.fill"
            case .trackingExperience: "square.and.pencil"
            case .fastingFamiliarity, .fastingContext, .fastingSchedule: "moon.stars.fill"
            case .pipTeaser, .pipReveal, .pipName, .userName, .tone, .toneInterstitial: "heart.fill"
            case .reminders: "bell.badge.fill"
            case .routineIntro, .mealsPerDay, .eatingLocations, .dietPreference, .foodRestrictions: "fork.knife"
            case .mealWindow: "clock.fill"
            case .waterAdequacy: "drop.fill"
            case .habitChanges: "leaf.fill"
            case .weekendEating: "calendar"
            case .cravings: "heart.text.square.fill"
            case .activityLevel: "figure.walk"
            case .connectHealth: "heart.text.square.fill"
            case .activityCalorieMode: "flame.fill"
            case .sexGender: "person.fill"
            case .age: "calendar"
            case .height: "ruler"
            case .currentWeight, .targetWeight, .goalPace, .weightProjection: "scalemass.fill"
            case .planBuilding, .finish: "checkmark.seal.fill"
            case .rateApp: "star.fill"
            case .softPaywall: "sparkles"
            case .account: "person.crop.circle.badge.checkmark"
            case .welcome: "heart.fill"
            }
        }

        var isOptional: Bool {
            // Charlie: every real question is required. Skip stays only for Health / Rate / Soft paywall.
            switch self {
            case .connectHealth, .rateApp, .softPaywall:
                true
            default: false
            }
        }

        var skipTitle: String? {
            guard isOptional else { return nil }
            switch self {
            case .connectHealth: return "Skip for now"
            case .rateApp: return "Maybe later"
            case .softPaywall: return "Continue with Free"
            default: return nil
            }
        }

        /// Grouped stages — new BitePal-parity beats share stages so the bar stays readable.
    }

    private var isAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }
    private var gridColumns: [GridItem] { [GridItem(.flexible())] }

    private var requiredMeasurementsAreValid: Bool {
        guard let age = draft.ageYears, (13...100).contains(age),
              let height = draft.heightCentimeters, (100...230).contains(height),
              let currentWeight = draft.currentWeightKilograms, (25...300).contains(currentWeight),
              let targetWeight = draft.targetWeightKilograms, (25...300).contains(targetWeight),
              draft.goalPace != nil else { return false }
        return true
    }

    private var hasSignedInAccount: Bool {
        draft.appleUserIdentifier != nil || draft.googleUserIdentifier != nil
    }

    private var requiredMeasurementMissing: Bool {
        switch step {
        case .attribution: draft.attributionSource == nil
        case .extraGoals: draft.additionalGoals.isEmpty
        case .fastingFamiliarity: draft.fastingFamiliarity == nil
        case .userName: draft.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .reminders: draft.reminderPreference == nil
        case .mealWindow:
            draft.firstMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || draft.lastMealTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fastingSchedule: draft.fastingSchedulePreference == nil
        case .eatingLocations: draft.eatingLocations.isEmpty
        case .dietPreference: draft.dietPreference == nil
        case .foodRestrictions: draft.foodRestrictions.isEmpty
        case .waterAdequacy: draft.waterAdequacy == nil
        case .habitChanges: draft.habitChanges.isEmpty
        case .weekendEating: draft.weekendEating == nil
        case .cravings: draft.cravingsFrequency == nil
        case .activityLevel: draft.activityLevel == nil
        case .sexGender: draft.sexGender == nil
        case .age: draft.ageYears.map { (13...100).contains($0) } != true
        case .height: draft.heightCentimeters.map { (100...230).contains($0) } != true
        case .currentWeight: draft.currentWeightKilograms.map { (25...300).contains($0) } != true
        case .targetWeight: draft.targetWeightKilograms.map { (25...300).contains($0) } != true
        case .goalPace: draft.goalPace == nil
        case .finish: !requiredMeasurementsAreValid
        case .account: !hasSignedInAccount
        default: false
        }
    }

    /// Calm copy near Continue — questions feel long; clarify it’s worth it for Pip’s setup.
    private var requiredAnswersWorthItLine: String {
        "Every answer is required — it only takes a few minutes and makes Pip’s setup fit you."
    }

    private var showsRequiredWorthItHelper: Bool {
        switch step {
        case .welcome, .pipTeaser, .pipReveal, .pipName, .toneInterstitial, .routineIntro,
             .smallStepsIntro, .fastingContext, .planBuilding, .finish, .rateApp, .softPaywall, .account,
             .weightProjection, .connectHealth:
            false
        default:
            true
        }
    }

    /// Pip art stays hidden until the introduce / reveal step completes.
    private var hasMetPip: Bool {
        step.rawValue > Step.pipReveal.rawValue
    }

    var body: some View {
        ZStack {
            BitePalColor.questionBG.ignoresSafeArea()
            switch step {
            case .welcome:
                welcomeScreen
            case .pipTeaser:
                teaserScreen
            case .pipReveal:
                revealScreen
            case .pipName:
                pipNameScreen
            case .toneInterstitial:
                toneInterstitialScreen
            case .routineIntro:
                routineIntroScreen
            case .account:
                accountScreen
            default:
                standardScreen
            }
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        // Welcome first screen only: hide system status bar (no battery/Wi‑Fi/cellular). Restored on later steps.
        .pandaPlateStatusBarHidden(step == .welcome)
        .sheet(isPresented: $showMidflowSoftPaywall) {
            PremiumPaywallView(isSoftPrompt: true)
        }
        .sheet(isPresented: $showBMISourceSheet) {
            bmiSourceSheet
        }
        .sheet(item: $presentedLegalDocument) { doc in
            PandaPlateLegalDocumentSheet(document: doc)
        }
        .onChange(of: step) { _, newStep in
            if newStep == .planBuilding {
                startPlanBuildingAnimation()
            }
            if newStep == .weightProjection {
                refreshWeightProjectionEstimate()
            }
            if newStep == .rateApp {
                maybeRequestMidflowReview()
            }
        }
    }

    private var standardScreen: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if step == .welcome {
                        welcomeContent
                    } else {
                        promptHeader
                        // Hide Pip until after the introduce beat (pipReveal).
                        if hasMetPip, step != .pipName, step != .tone, step != .routineIntro, step != .smallStepsIntro, step != .toneInterstitial,
                           step != .planBuilding, step != .rateApp, step != .softPaywall, step != .account, step != .weightProjection,
                           step != .connectHealth, step != .activityCalorieMode, step != .currentWeight, step != .height {
                            PipQuestionCompanion(
                                assetNames: pipAssetsForCurrentStep,
                                label: "Pip is here while you choose",
                                size: isAccessibilityLayout ? 82 : 72
                            )
                            .frame(maxWidth: .infinity)
                        }
                        answerContent
                    }
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, step == .welcome ? 24 : 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            // BitePal-like: allow natural bounce; avoid fighting nested wheel pickers.
            .scrollBounceBehavior(.always)
            footer
        }
        .background(BitePalColor.questionBG.ignoresSafeArea())
    }

    private var topBar: some View {
        // BitePal question chrome: soft circle back + category eyebrow. Same light-grey as screen — no cream strip.
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(PPColor.ink)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.92), in: Circle())
                        .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go back")
                .accessibilityHint("Returns to the previous setup screen")
                Spacer(minLength: 0)
            }
            HStack {
                Text(step.category.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                    .tracking(0.8)
                    .foregroundStyle(BitePalColor.titleGrey)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color.clear)
    }

    private var promptHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.system(size: 26, weight: .bold, design: .rounded, relativeTo: .title))
                .foregroundStyle(PPColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(stepSubtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stepSubtitle: String {
        switch step {
        case .mainGoal: "Choose one. There’s no perfect answer, and it can change."
        case .extraGoals: "Pick at least one. These notes don’t change calculations."
        case .trackingExperience: "This just helps set the tone. Nothing is judged or scored."
        case .smallStepsIntro: "A neutral overview of what this setup asks. No outcome claims or targets."
        case .fastingFamiliarity: "Just a familiarity question. No schedule or recommendation follows."
        case .fastingContext: "PandaPlate won’t set a fasting target or give fasting advice."
        case .pipTeaser: "Gamification makes habits stick for up 5x longer."
        case .pipReveal: "Swipe up to meet Pip. Continue when you’re ready."
        case .pipName: "Pick a name, or keep Pip."
        case .userName: "Required. It’s only for Pip’s greeting during this session."
        case .tone: "Pick the style that feels comfortable to hear."
        case .toneInterstitial: "Pip can be kind and encouraging without keeping score."
        case .reminders: "Pick one. Next we’ll ask iOS for notification permission if you want reminders."
        case .routineIntro: "A few short questions help describe your usual rhythm."
        case .mealsPerDay: "A reference point, not a target or prescription."
        case .mealWindow: "Choose first and last meal times (24-hour). Both are required."
        case .fastingSchedule: "Note your current routine. No schedule or recommendation is created."
        case .eatingLocations: "Choose any that fit. Your routine can vary day to day."
        case .dietPreference: "Pick a preference; no meal plan is calculated."
        case .foodRestrictions: "Pick any that apply (or No restrictions). Not an allergy check or safety guarantee."
        case .waterAdequacy: "Required. There’s no right answer and no hydration target is calculated."
        case .habitChanges: "Choose at least one. These answers don’t create targets."
        case .weekendEating: "Required context. It isn’t scored or used for calorie calculations."
        case .cravings: "Required context; there’s no judgment or score."
        case .activityLevel: "Required context; it doesn’t change calorie estimates in this version."
        case .connectHealth: "Optional. Read steps, active energy, exercise time, and workouts. Skip is fine — Finish never blocks on Health."
        case .activityCalorieMode: "Preference only — stored for later personalization, not a live calorie budget."
        case .attribution: "Pick one. This stays in the setup session only."
        case .sexGender: "Choose one before body metrics. Held in this setup session only."
        case .age: "Required · years · held in this setup session only."
        case .height: "Required · centimetres · no BMI or daily calorie target is shown."
        case .currentWeight: "Required · kilograms · no BMI or daily calorie target is shown."
        case .targetWeight: "Required · kg or lbs (wheels rematch the unit) · pace and a simple date estimate come next."
        case .goalPace: "Choose a pace. This is a preference, not a prescription."
        case .weightProjection: "A linear estimate only — not medical advice. No BMI or calorie targets."
        case .planBuilding: "Gathering your answers. No fake macros or calorie plan."
        case .finish: "Review your answers. No nutrition target, BMI, or macros are calculated."
        case .rateApp: "Optional. A soft thank-you — Apple may show a rating prompt once."
        case .softPaywall: "Optional Premium for extra Pip looks, show-up history, and session export. Free remains usable."
        case .account: "Sign in with Apple or Google to finish setup. An account is required."
        case .welcome: "Start with one small step that feels right for you."
        }
    }

    // MARK: - Welcome (cropped): headline + CTAs + legal only — no floating collage
    private var welcomeScreen: some View {
        // Soft sky-blue → white wash matching the lower half of the BitePal/crop ref.
        let softBlue = Color(red: 0.93, green: 0.96, blue: 1.0)
        let softWhite = Color(red: 0.98, green: 0.99, blue: 1.0)
        return ZStack {
            LinearGradient(colors: [softBlue, softWhite, Color.white], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            // Soft mint wash behind CTAs (depth, no floating chips).
            Ellipse()
                .fill(BitePalColor.introVideoGreen.opacity(0.28))
                .frame(width: 340, height: 220)
                .blur(radius: 40)
                .offset(y: 180)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Text("Reach your\nweight goals")
                    .font(.ppDisplay(size: 48, relativeTo: .largeTitle))
                    .foregroundStyle(Color.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 36)

                Button {
                    focusedField = nil
                    moveToNextStep()
                } label: {
                    Text("Get started")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .accessibilityLabel("Get started")

                Button {
                    focusedField = nil
                    enteredAccountFromWelcomeShortcut = true
                    step = .account
                } label: {
                    Text("I already have an account")
                        .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink.opacity(0.75))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .accessibilityLabel("I already have an account")

                PandaPlateLegalLinksRow(
                    preface: "By continuing you’re accepting our",
                    style: .welcome,
                    presentedDocument: $presentedLegalDocument
                )
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 18)
                .zIndex(5)
                .allowsHitTesting(true)
            }
        }
    }

    /// Legacy standardScreen branch (unused while welcomeScreen owns .welcome).
    @ViewBuilder private var welcomeContent: some View {
        EmptyView()
    }

    @ViewBuilder private var answerContent: some View {
        switch step {
        case .mainGoal:
            singleChoices(WellnessGoal.allCases.map(\.rawValue), selected: draft.goal.rawValue) { value in
                if let goal = WellnessGoal(rawValue: value) { draft.goal = goal }
            }
        case .extraGoals:
            multiChoices([
                "A kinder food relationship", "Everyday wellbeing", "More daily energy", "More variety",
                "Feel more like myself", "Support movement", "Less stress", "Learn about nutrition"
            ], selected: $draft.additionalGoals)
        case .trackingExperience:
            singleChoices(["This is new to me", "I’ve logged before", "I log regularly"], selected: draft.loggingFamiliarity) {
                draft.loggingFamiliarity = $0
            }
        case .smallStepsIntro:
            reassuranceCards([
                ("A few preferences", "This setup asks about a handful of choices.", "list.bullet"),
                ("No outcome claims", "These answers do not calculate a nutrition plan.", "info.circle.fill"),
                ("You stay in control", "You can review your answers before finishing.", "hand.raised.fill")
            ])
        case .fastingFamiliarity:
            singleChoices(["Yes", "No"], selected: draft.fastingFamiliarity ?? "") {
                draft.fastingFamiliarity = $0
            }
        case .fastingContext:
            reassuranceCards([
                ("Just information", "This flow won’t set a fasting window.", "info.circle.fill"),
                ("No pressure", "No fasting schedule or advice follows.", "hand.raised.fill")
            ])
        case .pipName:
            nameField(title: "Pet name", placeholder: "Pip", text: $draft.companionName, focused: .petName)
        case .userName:
            nameField(title: "Your name", placeholder: "Your name", text: $draft.userName, focused: .userName)
        case .tone:
            toneChoices
        case .toneInterstitial:
            reassuranceCards([
                ("Small steps count", "Pip offers support, not pressure.", "heart.fill"),
                ("You set the pace", "There’s no streak or perfect-day test.", "leaf.fill")
            ])
        case .reminders:
            singleChoices(["In the morning", "Before each meal", "When Pip is hungry", "Set up later"], selected: draft.reminderPreference ?? "") {
                draft.reminderPreference = $0
            }
        case .routineIntro:
            reassuranceCards([
                ("Usual is enough", "Choose what fits most days.", "calendar"),
                ("Skip if it doesn’t fit", "Location choices are optional and multi-select.", "arrow.uturn.backward")
            ])
        case .mealsPerDay:
            singleChoices((1...5).map { "\($0) meals" }, selected: "\(draft.mealsPerDay) meals") { value in
                if let count = Int(value.split(separator: " ").first ?? "3") { draft.mealsPerDay = count }
            }
        case .mealWindow:
            mealWindowFields
        case .fastingSchedule:
            singleChoices(["I already follow a schedule", "Not currently", "Prefer not to say"], selected: draft.fastingSchedulePreference ?? "") {
                draft.fastingSchedulePreference = $0
            }
        case .eatingLocations:
            locationChoices
        case .dietPreference:
            singleChoices(["Balanced", "Vegetarian", "Vegan", "Paleo", "Ketogenic", "High protein", "Lower carb", "Another preference"], selected: draft.dietPreference ?? "") {
                draft.dietPreference = $0
            }
        case .foodRestrictions:
            multiChoices([
                "All meat", "Animal products", "Citrus fruits", "Dairy", "Eggs", "Fish", "Gluten", "Nuts",
                "Red meat", "Seafood", "Seeds", "Shellfish", "Soy", "No restrictions"
            ], selected: $draft.foodRestrictions, onSelection: toggleRestriction)
        case .waterAdequacy:
            singleChoices(["Yes", "No", "Not sure"], selected: draft.waterAdequacy ?? "") {
                draft.waterAdequacy = $0
            }
        case .habitChanges:
            multiChoices([
                "Reduce added sugar", "Eat fewer highly processed snacks", "Add more greens and vegetables",
                "Cook at home more often", "Reduce salt", "No change for now"
            ], selected: $draft.habitChanges, onSelection: toggleHabitChange)
        case .weekendEating:
            singleChoices(["About the same", "A little different", "Not sure"], selected: draft.weekendEating ?? "") {
                draft.weekendEating = $0
            }
        case .cravings:
            singleChoices(["Often", "Sometimes", "Rarely"], selected: draft.cravingsFrequency ?? "") {
                draft.cravingsFrequency = $0
            }
        case .attribution:
            singleChoices(["TikTok", "Instagram", "Friend", "App Store", "YouTube", "Other"], selected: draft.attributionSource ?? "") {
                draft.attributionSource = $0
            }
        case .activityLevel:
            singleChoices(["Mostly sitting", "Some movement through the day", "Regular movement"], selected: draft.activityLevel ?? "") {
                draft.activityLevel = $0
            }
        case .connectHealth:
            connectHealthContent
        case .activityCalorieMode:
            activityCalorieModeContent
        case .sexGender:
            singleChoices(["Female", "Male", "Other", "Prefer not to say"], selected: draft.sexGender ?? "") {
                draft.sexGender = $0
            }
        case .age:
            requiredMeasurementPicker(title: "Your age", unit: "years", values: Array(13...100), selection: $draft.ageYears)
        case .height:
            heightMeasurementContent
        case .currentWeight:
            currentWeightWithBMIContent
        case .targetWeight:
            targetWeightContent
        case .goalPace:
            singleChoices(["Slow", "Steady", "Faster"], selected: draft.goalPace ?? "") {
                draft.goalPace = $0
            }
        case .weightProjection:
            weightProjectionContent
        case .planBuilding:
            planBuildingContent
        case .finish:
            setupReview
        case .rateApp:
            rateAppContent
        case .softPaywall:
            softPaywallStepContent
        case .account:
            accountStepContent
        case .welcome, .pipTeaser, .pipReveal:
            EmptyView()
        }
    }

    private var toneChoices: some View {
        VStack(spacing: 14) {
            PipToneShowcase(style: draft.pipStyle)
                .frame(height: isAccessibilityLayout ? 174 : 150)

            LazyVGrid(columns: gridColumns, spacing: 10) {
                ForEach(PipStyle.allCases) { style in
                    let selected = draft.pipStyle == style
                    Button { draft.pipStyle = style } label: {
                        VStack(spacing: 8) {
                            PipTonePose(style: style, size: isAccessibilityLayout ? 90 : 72)
                            Text(style.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.ink)
                                .multilineTextAlignment(.center)
                            if selected {
                                Label("Selected", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                                    .foregroundStyle(PPColor.coralInk)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 124)
                        .padding(12)
                        .background(selected ? PPColor.peach.opacity(0.72) : PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? PPColor.coralInk : PPColor.line, lineWidth: selected ? 1.5 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(style.rawValue), \(selected ? "selected" : "not selected")")
                    .accessibilityValue(selected ? "Selected" : "Not selected")
                    .accessibilityHint("Choose how Pip talks to you")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }

    private var mealWindowFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            PandaPlateSnapTimeSelector(title: "First meal", time: $draft.firstMealTime)
            PandaPlateSnapTimeSelector(title: "Last meal", time: $draft.lastMealTime)
            Text("Choose first and last meal times to continue.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
        }
    }

    private var locationChoices: some View {
        multiChoices(["Cook at home", "Order in", "Eat out"], selected: $draft.eatingLocations)
    }


    // MARK: - Health connect, activity calorie mode, height/BMI wheels

    @ViewBuilder private var connectHealthContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image("PP_PipChatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text("Want to sync steps and workouts from Apple Health? It’s optional — Skip is fine.")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                    .padding(14)
                    .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            PPCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("What we read", systemImage: "heart.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                    Text("Steps, active energy, exercise minutes, and recent workouts. We don’t write to Health in this version. Simulator support is limited — connect may no-op there.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if draft.healthKitConnected || healthSync.isConnected {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(BitePalColor.selectGreen)
            } else if healthSync.connectionState == .denied {
                Text(healthSync.lastErrorMessage ?? "Health access wasn’t granted. You can try again in You, or Skip.")
                    .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }

            Button {
                Task { @MainActor in
                    healthConnectBusy = true
                    let state = await healthSync.requestAuthorization()
                    draft.healthKitConnected = (state == .connected)
                    draft.healthKitSkipped = false
                    healthConnectBusy = false
                }
            } label: {
                HStack {
                    if healthConnectBusy { ProgressView().tint(.white) }
                    Text(draft.healthKitConnected || healthSync.isConnected ? "Connected to Apple Health" : "Connect Apple Health")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(BitePalColor.ctaBlack, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(healthConnectBusy || draft.healthKitConnected || healthSync.isConnected)
            .accessibilityHint("Requests Apple Health read access. Skip remains available.")
        }
    }

    @ViewBuilder private var activityCalorieModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 10) {
                Image("PP_PipChatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text("How should activity factor into your preferences?")
                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                    .padding(14)
                    .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            ForEach(ActivityCalorieMode.allCases) { mode in
                let selected = draft.activityCalorieMode == mode
                Button {
                    draft.activityCalorieMode = mode
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: mode == .smart ? "gauge.with.needle.fill" : "flame.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(selected ? BitePalColor.selectGreen : Color(red: 0.55, green: 0.40, blue: 0.85))
                            .frame(width: 44, height: 44)
                            .background(
                                (selected ? BitePalColor.selectFill : Color(red: 0.93, green: 0.90, blue: 0.98)),
                                in: Circle()
                            )
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(mode.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                                    .foregroundStyle(PPColor.ink)
                                if mode.isRecommended {
                                    Text("Recommended")
                                        .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(BitePalColor.selectGreen, in: Capsule())
                                }
                            }
                            Text(mode.detail)
                                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        selected ? BitePalColor.selectFill.opacity(0.55) : BitePalColor.whiteCard,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? BitePalColor.selectGreen : Color.black.opacity(0.06), lineWidth: selected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.title)\(mode.isRecommended ? ", recommended" : ""), \(selected ? "selected" : "not selected")")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }

            Text("Preference only — stored for later. Not a live calorie budget.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
        }
    }

    @ViewBuilder private var heightMeasurementContent: some View {
        VStack(spacing: 11) {
            PandaPlateSnapValueSelector(
                title: "Height",
                unit: "cm",
                values: Array(100...230),
                alternateUnit: "ft",
                selection: $draft.heightCentimeters
            )
            if draft.heightCentimeters == nil {
                Text("Select or enter a value to continue.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }
            PPCard {
                Text("Stored in centimetres for this session. No BMI until weight. No daily calorie target.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }
        }
    }

    @ViewBuilder private var currentWeightWithBMIContent: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image("PP_PipChatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text("What's your current weight?")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                    .padding(12)
                    .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            PandaPlateDecimalWeightSelector(title: "Current weight", selectionKg: $draft.currentWeightKilograms, preciseKgBinding: $draft.currentWeightKilogramsPrecise)

            bmiCard

            if draft.currentWeightKilograms == nil {
                Text("Select a weight to continue.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }
        }
    }

    @ViewBuilder private var targetWeightContent: some View {
        VStack(spacing: 12) {
            // Same DecimalWeightSelector as current weight: wheel digits + values rematch kg↔lbs (not label-only).
            PandaPlateDecimalWeightSelector(title: "Target weight", selectionKg: $draft.targetWeightKilograms)

            if draft.targetWeightKilograms == nil {
                Text("Select a weight to continue.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }

            PPCard {
                Text("This answer stays in this setup session. No BMI or daily calorie target is shown.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var bmiCard: some View {
        let height = draft.heightCentimeters
        let weight = draft.currentWeightKilogramsPrecise ?? draft.currentWeightKilograms.map(Double.init)
        if let height, let weight, let result = BMICategory.compute(heightCm: height, weightKg: weight) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your BMI:")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                    Text(String(format: "%.1f", result.value))
                        .font(.system(size: 28, weight: .black, design: .rounded, relativeTo: .title))
                        .foregroundStyle(result.category.badgeFill)
                    Spacer()
                    Text(result.category.badgeTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(result.category.badgeText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(result.category.badgeFill, in: Capsule())
                }
                Text(result.category.calmCopy)
                    .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let age = draft.ageYears, (13...17).contains(age) {
                    Text("These labels use WHO adult categories; they aren’t tailored for teens — check with a clinician if you have questions.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Teen note: WHO adult BMI categories; not tailored for teens")
                }
                Button("Based on what you shared") { showBMISourceSheet = true }
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(BitePalColor.selectGreen)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(result.category.softCardTint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(result.category.badgeFill.opacity(0.35), lineWidth: 1)
            )
        } else if draft.currentWeightKilograms != nil, draft.heightCentimeters == nil {
            Text("Add height first to see an informational BMI.")
                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var bmiSourceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("BMI here is informational only — computed from the height and weight you entered. It isn’t a diagnosis, and it never unlocks or locks Premium.")
                        .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                    if let age = draft.ageYears, (13...17).contains(age) {
                        Text("You’re under 18: the bands below are WHO adult categories and aren’t tailored for teens. Talk with a clinician if you have questions — BMI here stays informational only.")
                            .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Adult categories commonly cited by WHO / CDC-style charts:")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                    ForEach([
                        (BMICategory.underweight.badgeTitle, "< 18.5", BMICategory.underweight),
                        (BMICategory.healthy.badgeTitle, "18.5 – 24.9", BMICategory.healthy),
                        (BMICategory.overweight.badgeTitle, "25.0 – 29.9", BMICategory.overweight),
                        (BMICategory.obese.badgeTitle, "≥ 30.0", BMICategory.obese),
                    ], id: \.0) { row in
                        HStack(spacing: 10) {
                            Capsule()
                                .fill(row.2.badgeFill)
                                .frame(width: 10, height: 10)
                                .accessibilityHidden(true)
                            Text(row.0).font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                .foregroundStyle(PPColor.ink)
                            Spacer()
                            Text(row.1).font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.muted)
                        }
                        .padding(.vertical, 6)
                    }
                    Text("PandaPlate won’t invent height or weight, and won’t use BMI for guilt or paywalls.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
                .padding(20)
            }
            .background(BitePalColor.questionBG.ignoresSafeArea())
            .navigationTitle("Based on what you shared")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showBMISourceSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }


    private func requiredMeasurementPicker(
        title: String,
        unit: String,
        values: [Int],
        selection: Binding<Int?>,
        alternateUnit: String? = nil
    ) -> some View {
        VStack(spacing: 11) {
            PandaPlateSnapValueSelector(title: title, unit: unit, values: values, alternateUnit: alternateUnit, selection: selection)
            if selection.wrappedValue == nil {
                Text("Select or enter a value to continue.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .accessibilityAddTraits(.isStaticText)
            }
            PPCard {
                Text("This answer stays in this setup session. No BMI or daily calorie target is shown.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var setupReview: some View {
        VStack(alignment: .leading, spacing: 11) {
            recapCard("Main focus", value: draft.goal.rawValue, symbol: "sparkles")
            recapCard("Pip’s style", value: draft.pipStyle.rawValue, symbol: "heart.fill")
            recapCard("Pip calls you", value: draft.sanitizedUserName, symbol: "person.fill")
            recapCard("Companion name", value: draft.sanitizedCompanionName, symbol: "pawprint.fill")
            recapCard("Food-log experience", value: draft.loggingFamiliarity, symbol: "square.and.pencil")
            recapCard("Fasting familiarity", value: draft.fastingFamiliarity ?? "Not set", symbol: "moon.stars.fill")
            recapCard("Meals that fit your day", value: "\(draft.mealsPerDay)", symbol: "fork.knife")
            recapCard("First meal", value: draft.firstMealTime.isEmpty ? "Not set" : draft.firstMealTime, symbol: "sunrise.fill")
            recapCard("Last meal", value: draft.lastMealTime.isEmpty ? "Not set" : draft.lastMealTime, symbol: "sunset.fill")
            recapCard("Fasting schedule", value: draft.fastingSchedulePreference ?? "Not set", symbol: "moon.stars.fill")
            recapCard("Usual places", value: draft.eatingLocations.isEmpty ? "Not set" : draft.eatingLocations.sorted().joined(separator: ", "), symbol: "house.fill")
            recapCard("Food preference", value: draft.dietPreference ?? "Not set", symbol: "carrot.fill")
            recapCard("Foods to avoid", value: draft.foodRestrictions.isEmpty ? "Not set" : draft.foodRestrictions.sorted().joined(separator: ", "), symbol: "fork.knife")
            recapCard("Water routine", value: draft.waterAdequacy ?? "Not set", symbol: "drop.fill")
            recapCard("Changes you chose", value: draft.habitChanges.isEmpty ? "Not set" : draft.habitChanges.sorted().joined(separator: ", "), symbol: "leaf.fill")
            recapCard("Weekend routine", value: draft.weekendEating ?? "Not set", symbol: "calendar")
            recapCard("Cravings", value: draft.cravingsFrequency ?? "Not set", symbol: "heart.text.square.fill")
            recapCard("Heard about us", value: draft.attributionSource ?? "Not set", symbol: "megaphone.fill")
            recapCard("Usual movement", value: draft.activityLevel ?? "Not set", symbol: "figure.walk")
            recapCard("Apple Health", value: draft.healthKitConnected ? "Connected" : (draft.healthKitSkipped ? "Skipped" : "Not connected"), symbol: "heart.text.square.fill")
            recapCard("Activity calories", value: draft.activityCalorieMode.title, symbol: "flame.fill")
            recapCard("Sex / gender", value: draft.sexGender ?? "Not set", symbol: "person.fill")
            recapCard("Age", value: draft.ageYears.map { "\($0) years" } ?? "Not set", symbol: "calendar")
            recapCard("Height", value: draft.heightCentimeters.map { "\($0) cm" } ?? "Not set", symbol: "ruler")
            recapCard("Current weight", value: draft.currentWeightKilograms.map { "\($0) kg" } ?? "Not set", symbol: "scalemass.fill")
            recapCard("Target weight", value: draft.targetWeightKilograms.map { "\($0) kg" } ?? "Not set", symbol: "scalemass.fill")
            recapCard("Goal pace", value: draft.goalPace ?? "Not set", symbol: "tortoise.fill")
            recapCard("Date estimate", value: projectionRecapValue, symbol: "calendar.badge.clock")
            recapCard("Reminder preference", value: reminderRecapValue, symbol: "bell.fill")
            if !draft.additionalGoals.isEmpty {
                recapCard("Extra focus", value: draft.additionalGoals.sorted().joined(separator: ", "), symbol: "leaf.fill")
            }
            PPCard {
                Text("This is a preference review — not a nutrition plan, BMI, or macros. If you allowed notifications, gentle local reminders follow your preference on this device (best-effort — not a delivery guarantee).")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        // BitePal: black CTA on same light-grey as the question screen — no cream footer strip.
        VStack(spacing: 6) {
            if showsRequiredWorthItHelper {
                Text(requiredAnswersWorthItLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(BitePalColor.titleGrey)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                    .accessibilityLabel(requiredAnswersWorthItLine)
            }
            Button {
                focusedField = nil
                continueFlow()
            } label: {
                HStack(spacing: 8) {
                    Text(primaryTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                    if primaryTitle == "Next" || primaryTitle == "Continue" {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(BitePalColor.ctaBlack, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(requiredMeasurementMissing || notificationRequestBusy)
            .opacity((requiredMeasurementMissing || notificationRequestBusy) ? 0.45 : 1)
            .accessibilityLabel(primaryTitle)
            .accessibilityHint(
                step == .account && requiredMeasurementMissing
                ? "Sign in with Apple or Google to finish setup."
                : (requiredMeasurementMissing ? "Choose an answer to continue — every question is required." : "")
            )
            if let skipTitle = step.skipTitle {
                Button(skipTitle, action: skipCurrentStep)
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .frame(maxWidth: 500)
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.clear)
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Let’s get started"
        case .pipTeaser: "Continue"
        case .pipReveal: "Continue"
        case .pipName: "Next"
        case .planBuilding: "Keep going"
        case .finish: "Looks good"
        case .rateApp: "Continue"
        case .softPaywall: "Continue with Free"
        case .account: hasSignedInAccount ? "Enter PandaPlate" : "Sign in to continue"
        default: "Continue"
        }
    }

    @ViewBuilder private var teaserScreen: some View {
        // Reveal-world backdrop = intro-video mint (#B8E3CA).
        return ZStack {
            revealWorldBackground
            VStack(spacing: 0) {
            mintBackBar
            Spacer(minLength: 40)
            VStack(spacing: 6) {
                Text("Let’s meet your")
                    .font(.system(size: 34, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
                Text("virtual pet")
                    .font(.system(size: 34, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(BitePalColor.titleGrey)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Let’s meet your virtual pet")

            Spacer(minLength: 24)

            teaserTipCard
                .padding(.horizontal, 28)

            Button {
                focusedField = nil
                resetRevealInteraction()
                step = .pipReveal
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(BitePalColor.ctaBlack, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 22)
            .accessibilityLabel("Continue")
        }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // BitePal advances from teaser with a continue/tap.
            focusedField = nil
            resetRevealInteraction()
            step = .pipReveal
        }
        .onAppear { teaserIsVisible = true }
        .onDisappear {
            teaserIsVisible = false
            focusedField = nil
        }
    }

    private var teaserTipCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("5x")
                .font(.system(size: 34, weight: .heavy, design: .rounded, relativeTo: .title))
                .foregroundStyle(PPColor.ink)
                .accessibilityHidden(true)
            (
                Text("Gamification makes habits stick for up ")
                    .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                + Text("5x longer")
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
            )
            .foregroundStyle(PPColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(BitePalColor.tipPill, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Gamification makes habits stick for up 5 times longer")
    }

    /// BitePal back chevron — soft white circle, no cream strip.
    private var mintBackBar: some View {
        HStack(spacing: 12) {
            Button(action: goBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PPColor.ink)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.92), in: Circle())
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the previous setup screen")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    /// Pet-intro / reveal world — solid mint from pip-peek-swipe.gif (#B8E3CA), not cream PP_RevealBackground.
    private var revealWorldBackground: some View {
        BitePalColor.introVideoGreen
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Full-screen mint reveal — swipe-up GIF (no mp4).
    private var revealScreen: some View {
        VStack(spacing: 0) {
            mintBackBar
            Text(revealCompleted || skipRevealAnimation
                 ? "This \(draft.companionName.isEmpty ? "Pip" : draft.companionName) is now your virtual pet"
                 : step.title)
                .font(.system(size: 28, weight: .bold, design: .rounded, relativeTo: .title))
                .multilineTextAlignment(.center)
                .foregroundStyle(PPColor.ink)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .fixedSize(horizontal: false, vertical: true)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: revealCompleted)

            ZStack(alignment: .bottom) {
                Color.clear
                revealBackdrop
                    .offset(y: revealPetVisualOffset)
                    .gesture(revealSwipeGesture)
                    .animation(reduceMotion ? nil : .interactiveSpring(response: 0.32, dampingFraction: 0.86), value: revealDragTranslation)
                    .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.84), value: revealCompleted)

                if !revealCompleted {
                    VStack(spacing: 10) {
                        if reduceMotion || skipRevealAnimation {
                            Button {
                                completePipReveal()
                            } label: {
                                Text("Meet Pip")
                                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 52)
                                    .background(BitePalColor.ctaBlack, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 22)
                        } else {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(PPColor.ink.opacity(0.45))
                                .accessibilityHidden(true)
                            Text("Swipe up")
                                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.ink.opacity(0.55))
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            VStack(spacing: 6) {
                Button {
                    focusedField = nil
                    step = .pipName
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!revealCompleted && !skipRevealAnimation)
                .opacity((revealCompleted || skipRevealAnimation) ? 1 : 0.45)
                .accessibilityHint(revealCompleted || skipRevealAnimation ? "" : "Swipe up to meet Pip first")

                Button("Skip") {
                    focusedField = nil
                    skipRevealAnimation = true
                    revealCompleted = true
                    step = .pipName
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.coralInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityHint("Skip the reveal and continue to naming with a static Pip")
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.72))
        }
        .background { revealWorldBackground }
        .onAppear {
            teaserIsVisible = true
            if skipRevealAnimation {
                revealCompleted = true
                revealDragTranslation = revealSwipeTravel
            }
        }
        .onDisappear { teaserIsVisible = false }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Swipe up to see who’s there")
    }

    private var revealSwipeTravel: CGFloat { 220 }

    private var revealPetVisualOffset: CGFloat {
        if revealCompleted || skipRevealAnimation {
            return 0
        }
        // Start mostly below the fold; drag up reduces the offset.
        let base: CGFloat = 210
        let lifted = min(revealDragTranslation, revealSwipeTravel)
        return max(0, base - lifted)
    }

    private var revealSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !revealCompleted, !reduceMotion, !skipRevealAnimation else { return }
                let upward = max(0, -value.translation.height)
                revealDragTranslation = upward
            }
            .onEnded { value in
                guard !revealCompleted, !reduceMotion, !skipRevealAnimation else { return }
                let upward = max(0, -value.translation.height)
                let predicted = max(0, -value.predictedEndTranslation.height)
                if upward >= 110 || predicted >= 160 {
                    completePipReveal()
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        revealDragTranslation = 0
                    }
                }
            }
    }

    private func completePipReveal() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.84)) {
            revealDragTranslation = revealSwipeTravel
            revealCompleted = true
        }
    }

    private func resetRevealInteraction() {
        revealDragTranslation = 0
        revealCompleted = false
        skipRevealAnimation = false
    }

    @ViewBuilder private var revealBackdrop: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Transparent — parent supplies intro-video green world.
                Color.clear
                if skipRevealAnimation || (reduceMotion && revealCompleted) {
                    Image("PP_PipBase")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: min(geometry.size.width * 0.78, 320))
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)
                } else {
                    PipLifeLoopView(
                        resourceName: "PP_PipLife_Wave",
                        stillAssetName: "PP_PipBase",
                        size: min(geometry.size.width * 0.72, 300),
                        height: min(geometry.size.height * 0.72, 480),
                        accessibilityLabel: "Pip waving in the forest garden"
                    )
                    .padding(.bottom, 0)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }
    }

    /// BitePal-style naming: side mascot, big name field, dice, Next.
    private var pipNameScreen: some View {
        ZStack(alignment: .topTrailing) {
            BitePalColor.questionBG.ignoresSafeArea()

            // Side mascot peeking from the right (clipped).
            Image("PP_PipPeek")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .offset(x: 78, y: 56)
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 36)

                VStack(spacing: 14) {
                    Text("Name your companion")
                        .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.muted)
                        .frame(maxWidth: .infinity)

                    TextField("Pip", text: $draft.companionName)
                        .font(.system(size: 36, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.ink)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .petName)
                        .padding(.horizontal, 28)
                        .onChange(of: draft.companionName) { _, newValue in
                            if newValue.count > 24 {
                                draft.companionName = String(newValue.prefix(24))
                            }
                        }
                        .accessibilityLabel("Companion name")

                    HStack(spacing: 12) {
                        Button {
                            draft.companionName = randomFriendlyCompanionName()
                        } label: {
                            Image(systemName: "dice.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(PPColor.ink)
                                .frame(width: 52, height: 52)
                                .background(PPColor.card, in: Circle())
                                .overlay(Circle().stroke(PPColor.line.opacity(0.7), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Random name")
                        .accessibilityHint("Picks a short friendly name")

                        Button {
                            focusedField = nil
                            if draft.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                draft.companionName = "Pip"
                            }
                            moveToNextStep()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(BitePalColor.ctaBlack, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Next")
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)
                }

                Spacer(minLength: 24)

                Button("Keep Pip’s name") {
                    draft.companionName = "Pip"
                    focusedField = nil
                    moveToNextStep()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.bottom, 12)
            }
        }
        .clipped()
        .onAppear {
            if draft.companionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.companionName = "Pip"
            }
            focusedField = .petName
        }
        .onDisappear { focusedField = nil }
    }


    // MARK: - BitePal-style interstitial: pink “Small steps count”
    private var toneInterstitialScreen: some View {
        let pink = BitePalColor.pinkScreen
        return ZStack {
            pink.ignoresSafeArea()

            // Soft stars (BitePal layout)
            toneInterstitialStars
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Text("Small steps count.\nKeep logging!")
                    .font(.system(size: 32, weight: .bold, design: .rounded, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)

                // White tip card
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(BitePalColor.pinkScreen)
                            .frame(width: 56, height: 56)
                        Image("PP_IconSaladBowl")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .accessibilityHidden(true)
                    }
                    Text("You’re doing great — log your next meal when you’re ready.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 8)

                ZStack {
                    // Rainbow arcs behind Pip
                    bitePalRainbow
                        .frame(height: 160)
                        .offset(y: 36)
                        .allowsHitTesting(false)

                    Image("PP_PipWaveCheer")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 320)
                        .accessibilityLabel("Pip cheering")
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

                Button {
                    focusedField = nil
                    moveToNextStep()
                } label: {
                    Text("Set up reminders")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
                .accessibilityLabel("Set up reminders")
            }
        }
    }

    private var toneInterstitialStars: some View {
        GeometryReader { geo in
            let star = BitePalColor.starSalmon
            ZStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(star.opacity(0.9))
                    .font(.system(size: 16))
                    .position(x: geo.size.width * 0.18, y: geo.size.height * 0.14)
                Image(systemName: "star.fill")
                    .foregroundStyle(star.opacity(0.75))
                    .font(.system(size: 12))
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.11)
                Image(systemName: "star.fill")
                    .foregroundStyle(star.opacity(0.8))
                    .font(.system(size: 14))
                    .position(x: geo.size.width * 0.62, y: geo.size.height * 0.20)
            }
            .accessibilityHidden(true)
        }
    }

    private var bitePalRainbow: some View {
        let bands: [(Color, CGFloat)] = [
            (BitePalColor.rainbowMint, 30),
            (BitePalColor.rainbowYellow, 30),
            (BitePalColor.rainbowBlue, 30),
            (BitePalColor.rainbowGreen, 30),
        ]
        return VStack(spacing: 0) {
            ForEach(0..<bands.count, id: \.self) { i in
                Capsule()
                    .fill(bands[i].0)
                    .frame(height: bands[i].1)
                    .padding(.horizontal, CGFloat(i) * 6)
            }
        }
        .rotationEffect(.degrees(-8))
        .opacity(0.95)
        .accessibilityHidden(true)
    }

    // MARK: - Charlie kitchen composition: PP_KitchenScene + Pip + thought bubbles
    private var routineIntroScreen: some View {
        ZStack {
            routineIntroBackdrop

            VStack(spacing: 0) {
                HStack {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.92), in: Circle())
                            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                Text("Now let’s talk\nabout your\neating habits")
                    .font(.system(size: 32, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(PPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
                    .padding(.top, 10)
                    .shadow(color: .white.opacity(0.85), radius: 6, y: 0)

                Spacer(minLength: 8)

                // Pip on the kitchen rug + thought bubbles (matches charlie-eating-habits-kitchen.png)
                ZStack(alignment: .top) {
                    Image("PP_PipThinking")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 250, maxHeight: 280)
                        .accessibilityLabel("Pip thinking about food")
                        .padding(.top, 36)

                    HStack(spacing: 18) {
                        Image("PP_ThoughtApple")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                        Image("PP_ThoughtGrainBowl")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 86, height: 86)
                    }
                    .offset(y: -4)
                    .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)

                Spacer(minLength: 8)

                Button {
                    focusedField = nil
                    moveToNextStep()
                } label: {
                    Text("Let’s go")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
                .accessibilityLabel("Let’s go")
            }
        }
    }

    private var routineIntroBackdrop: some View {
        GeometryReader { geo in
            ZStack {
                BitePalColor.kitchenMint
                Image("PP_KitchenScene")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                // Soft wash so title stays readable over the window
                LinearGradient(
                    colors: [Color.white.opacity(0.62), Color.white.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func thoughtBubble(systemName: String, tint: Color) -> some View {
        ZStack {
            Capsule()
                .fill(Color.white)
                .frame(width: 64, height: 52)
                .shadow(color: PPColor.ink.opacity(0.08), radius: 6, y: 2)
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
        }
        .accessibilityHidden(true)
    }


    private func randomFriendlyCompanionName() -> String {
        let names = [
            "Pip", "Pebble", "Mochi", "Maple", "Bean", "Coco", "Mango",
            "Sprout", "Nori", "Boba", "Kiwi", "Pudding", "Acorn", "Miso",
            "Peanut", "Bun", "Toast", "Olive", "Pepper", "Sunny"
        ]
        let current = draft.companionName
        let options = names.filter { $0.caseInsensitiveCompare(current) != .orderedSame }
        return options.randomElement() ?? "Pip"
    }

    @ViewBuilder private var answerControls: some View { answerContent }

    private func singleChoices(_ options: [String], selected: String, onSelect: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 9) {
            ForEach(options, id: \.self) { option in
                choiceCard(option, symbol: symbolFor(option), selected: selected == option, mode: "single") { onSelect(option) }
            }
        }
    }

    private func multiChoices(
        _ options: [String],
        selected: Binding<Set<String>>,
        onSelection: ((String) -> Void)? = nil
    ) -> some View {
        LazyVGrid(columns: gridColumns, spacing: 9) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected.wrappedValue.contains(option)
                choiceCard(option, symbol: symbolFor(option), selected: isSelected, mode: "multi") {
                    if let onSelection { onSelection(option) }
                    else { toggle(option, in: selected) }
                }
            }
        }
    }

    private func choiceCard(
        _ title: String,
        detail: String? = nil,
        symbol: String,
        selected: Bool,
        mode: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selected ? BitePalColor.selectGreen : PPColor.ink)
                    .frame(width: 40, height: 40)
                    .background(selected ? BitePalColor.selectFill : BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? (mode == "multi" ? "checkmark.square.fill" : "checkmark.circle.fill") : (mode == "multi" ? "square" : "circle"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selected ? BitePalColor.selectGreen : PPColor.muted)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(12)
            .background(selected ? BitePalColor.selectFill.opacity(0.55) : BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected ? BitePalColor.selectGreen : Color.black.opacity(0.08), lineWidth: selected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(selected ? "selected" : "not selected")")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(mode == "multi" ? "Choose or unchoose this option. You may select more than one." : "Select this option.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func reassuranceCards(_ rows: [(String, String, String)]) -> some View {
        VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: row.2)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PPColor.coralInk)
                        .frame(width: 42, height: 42)
                        .background(PPColor.peach, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.0).font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.ink)
                        Text(row.1).font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.muted)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .padding(12)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private func nameField(title: String, placeholder: String, text: Binding<String>, focused: Field) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "pencil.line").foregroundStyle(PPColor.coralInk).accessibilityHidden(true)
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: focused)
                    .accessibilityLabel(title)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        if newValue.count > 24 { text.wrappedValue = String(newValue.prefix(24)) }
                    }
            }
            .font(.system(size: 16, weight: .medium, design: .rounded, relativeTo: .body))
            .padding(14)
            .frame(minHeight: 52)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PPColor.line, lineWidth: 1))
            Text("Required · up to 24 characters · held for this session only")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }

    private func recapCard(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).foregroundStyle(PPColor.coralInk).frame(width: 38, height: 38).background(PPColor.peach, in: RoundedRectangle(cornerRadius: 12, style: .continuous)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.muted)
                Text(value).font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.ink).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(13)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var pipAssetsForCurrentStep: [String] {
        switch step {
        case .mainGoal, .trackingExperience: ["PP_PipThinking", "PP_PipGentle"]
        case .extraGoals: ["PP_PipPeek", "PP_PipLove"]
        case .fastingFamiliarity, .fastingContext: ["PP_PipRest", "PP_PipThinking"]
        case .reminders, .mealWindow: ["PP_PipGentle", "PP_PipRest"]
        case .mealsPerDay, .routineIntro: ["PP_PipChef", "PP_PipThinking"]
        case .eatingLocations: ["PP_PipLove", "PP_PipChef"]
        default: ["PP_PipWelcome", "PP_PipGentle"]
        }
    }

    private func symbolFor(_ option: String) -> String {
        let key = option.lowercased()
        if key.contains("cook at home") { return "house.fill" }
        if key.contains("order in") { return "takeoutbag.and.cup.and.straw.fill" }
        if key.contains("eat out") { return "fork.knife" }
        if key.contains("home") || key.contains("balanced") || key.contains("variety") { return "leaf.fill" }
        if key.contains("water") { return "drop.fill" }
        if key.contains("morning") || key.contains("meal") { return "fork.knife" }
        if key.contains("not sure") || key.contains("later") || key.contains("none") { return "minus.circle" }
        if key.contains("movement") || key.contains("sitting") { return "figure.walk" }
        if key.contains("log") || key.contains("track") { return "square.and.pencil" }
        if key.contains("yes") || key.contains("often") || key.contains("sometimes") { return "checkmark" }
        if key.contains("no") || key.contains("rarely") { return "hand.raised" }
        if key.contains("vegetarian") || key.contains("vegan") { return "carrot.fill" }
        return "sparkle"
    }

    private func toggle(_ value: String, in set: Binding<Set<String>>) {
        if set.wrappedValue.contains(value) { set.wrappedValue.remove(value) }
        else { set.wrappedValue.insert(value) }
    }

    private func toggleRestriction(_ value: String) {
        if value == "No restrictions" {
            draft.foodRestrictions = draft.foodRestrictions.contains(value) ? [] : [value]
            return
        }
        draft.foodRestrictions.remove("No restrictions")
        toggle(value, in: $draft.foodRestrictions)
    }

    private func toggleHabitChange(_ value: String) {
        if value == "No change for now" {
            draft.habitChanges = draft.habitChanges.contains(value) ? [] : [value]
            return
        }
        draft.habitChanges.remove("No change for now")
        toggle(value, in: $draft.habitChanges)
    }

    private var projectionRecapValue: String {
        if draft.estimatedReachSkippedUnder18 {
            return "Skipped under 18"
        }
        if let date = draft.estimatedReachDate {
            return Self.projectionDateFormatter.string(from: date) + " · estimate"
        }
        return "Not set"
    }

    private static let projectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_HK")
        f.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    @ViewBuilder private var weightProjectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if draft.estimatedReachSkippedUnder18 {
                PPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("We’re skipping the date estimate for now.")
                            .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.ink)
                        Text("For ages under 18, PandaPlate doesn’t show a weight-date projection. Your other answers still help personalize the setup.")
                            .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let date = draft.estimatedReachDate,
                      let current = draft.currentWeightKilograms,
                      let target = draft.targetWeightKilograms,
                      let pace = draft.goalPace {
                PPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Estimate · not medical advice")
                            .font(.system(size: 11, weight: .heavy, design: .rounded, relativeTo: .caption2))
                            .tracking(0.6)
                            .foregroundStyle(PPColor.coralInk)
                        Text(Self.projectionDateFormatter.string(from: date))
                            .font(.system(size: 28, weight: .black, design: .rounded, relativeTo: .title))
                            .foregroundStyle(PPColor.ink)
                        Text("A simple linear pace from \(current) kg toward \(target) kg at a \(pace.lowercased()) pace. Not a prescription — no BMI or daily calorie targets.")
                            .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                PPCard {
                    Text("Add age, weights, and pace to see a simple date estimate. No BMI or calorie targets.")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
            }
        }
    }

    private var planPhases: [(String, String)] {
        [
            ("Personalizing your setup", "person.text.rectangle"),
            ("Reviewing your answers", "checkmark.circle"),
            ("Shaping your nutrition prefs", "leaf"),
            ("Looking at lifestyle notes", "figure.walk"),
        ]
    }

    /// Mid-generation interrupt questions that write into the draft when still unanswered.
    private var planInterruptQuestions: [(key: String, prompt: String, options: [String])] {
        var q: [(String, String, [String])] = []
        if draft.cravingsFrequency == nil {
            q.append(("cravingsFrequency", "Do you get cravings?", ["All the time", "Now and then", "Rarely"]))
        }
        if draft.weekendEating == nil {
            q.append(("weekendEating", "Does your eating change on weekends?", ["About the same", "A little different", "Not sure"]))
        }
        if draft.waterAdequacy == nil {
            q.append(("waterAdequacy", "How does your water routine feel?", ["Yes — feels fine", "No — could drink more", "Not sure"]))
        }
        return q
    }

    @ViewBuilder private var planBuildingContent: some View {
        ZStack {
            VStack(spacing: 18) {
                Text("Personalizing your plan")
                    .font(.system(size: 26, weight: .bold, design: .rounded, relativeTo: .title))
                    .foregroundStyle(PPColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(planPhases.indices, id: \.self) { index in
                        planPhaseRow(index: index)
                    }
                }

                Text("Setup personalization only — not lab metabolism or a calorie prescription.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Image("PP_PipPlanClipboard")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isAccessibilityLayout ? 168 : 148, height: isAccessibilityLayout ? 168 : 148)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Pip with your setup clipboard")
            }

            if planBuildPausedForQuestion, planInterruptIndex < planInterruptQuestions.count {
                Color.black.opacity(0.28).ignoresSafeArea()
                planInterruptCard(planInterruptQuestions[planInterruptIndex])
                    .padding(.horizontal, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: planBuildPausedForQuestion)
    }

    private func planPhaseRow(index: Int) -> some View {
        let phase = planPhases[index]
        let isActive = index == planBuildPhaseIndex && !planBuildPausedForQuestion
        let isDone = index < planBuildPhaseIndex || (index == planBuildPhaseIndex && planBuildProgress >= 0.999 && !planBuildPausedForQuestion)
        let isUpcoming = index > planBuildPhaseIndex
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : phase.1)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isDone || isActive ? BitePalColor.selectGreen : PPColor.muted)
                    .frame(width: 24)
                Text(phase.0)
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(isUpcoming ? PPColor.muted : PPColor.ink)
                Spacer()
                if isActive {
                    Text("\(Int((planBuildProgress * 100).rounded()))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(BitePalColor.selectGreen)
                }
            }
            if isActive {
                ProgressView(value: planBuildProgress)
                    .tint(BitePalColor.selectGreen)
                if let height = draft.heightCentimeters, let weight = draft.currentWeightKilograms {
                    let precise = draft.currentWeightKilogramsPrecise ?? Double(weight)
                    Text(String(format: "%d cm, %.1f kg", height, precise))
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
            }
        }
        .padding(12)
        .background(
            (isActive ? BitePalColor.selectFill.opacity(0.35) : BitePalColor.whiteCard),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .opacity(isUpcoming ? 0.55 : 1)
    }

    private func planInterruptCard(_ question: (key: String, prompt: String, options: [String])) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image("PP_PipChatAvatar")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(question.prompt)
                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                    .padding(14)
                    .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            }
            VStack(spacing: 8) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        applyPlanInterruptAnswer(key: question.key, option: option)
                    } label: {
                        Text(option)
                            .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(BitePalColor.whiteCard, in: Capsule())
                            .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(BitePalColor.questionBG.opacity(0.97), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(question.prompt)
    }

    private func applyPlanInterruptAnswer(key: String, option: String) {
        switch key {
        case "cravingsFrequency":
            draft.cravingsFrequency = option == "All the time" ? "Often" : (option == "Now and then" ? "Sometimes" : "Rarely")
        case "weekendEating":
            draft.weekendEating = option
        case "waterAdequacy":
            if option.hasPrefix("Yes") { draft.waterAdequacy = "Yes" }
            else if option.hasPrefix("No") { draft.waterAdequacy = "No" }
            else { draft.waterAdequacy = "Not sure" }
        default: break
        }
        planInterruptIndex += 1
        planBuildPausedForQuestion = false
        // Nudge checklist forward after answering.
        if planBuildPhaseIndex < planPhases.count - 1 {
            planBuildPhaseIndex += 1
            planBuildProgress = 0.05
        }
    }


    @ViewBuilder private var rateAppContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            PPCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enjoying PandaPlate?")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                    Text("If a rating prompt appears, it’s optional. Soft thank-you only — no pressure.")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder private var softPaywallStepContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image("PP_PipCelebrate")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Optional Premium")
                        .font(.ppDisplay(size: 24, relativeTo: .title2))
                        .foregroundStyle(Color.black)
                    Text("Premium unlocks extra Pip looks, show-up history, and session export. Live food recognition isn’t available in this build.")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                showMidflowSoftPaywall = true
            } label: {
                Text("See Premium options")
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(BitePalColor.ctaBlack, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens a dismissible Premium sheet. Free continues either way.")
        }
    }

    /// Full-bleed BitePal account — soft blue edge-to-edge, no cream strip sandwich.
    private var accountScreen: some View {
        ZStack {
            BitePalColor.accountBlue.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: goBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.92), in: Circle())
                            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go back")
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        Text("Create your account")
                            .font(.system(size: 28, weight: .bold, design: .rounded, relativeTo: .title))
                            .foregroundStyle(PPColor.ink)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)

                        Text("Sign in with Apple or Google to finish setup. An account is required.")
                            .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)

                        accountStepContent
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                }

                VStack(spacing: 6) {
                    Button {
                        focusedField = nil
                        continueFlow()
                    } label: {
                        Text(hasSignedInAccount ? "Enter PandaPlate" : "Sign in to continue")
                            .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(BitePalColor.ctaBlack, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasSignedInAccount)
                    .opacity(hasSignedInAccount ? 1 : 0.45)
                    .accessibilityLabel(hasSignedInAccount ? "Enter PandaPlate" : "Sign in to continue")
                    .accessibilityHint(hasSignedInAccount ? "" : "Sign in with Apple or Google to finish setup.")
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder private var accountStepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("PP_PipHeartHands")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Pip making a heart with hands")
                .padding(.top, 4)

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 56)
                .clipShape(Capsule())
                .accessibilityLabel("Sign in with Apple")

                // Visual twin of SignInWithAppleButton: full-width capsule, centered icon+label.
                Button(action: startGoogleSignIn) {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                            .accessibilityHidden(true)
                        Text("Continue with Google")
                            .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.ink)
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Color.white, in: Capsule())
                    .overlay(Capsule().stroke(PPColor.line.opacity(0.9), lineWidth: 1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Continue with Google")
            }

            if let appleSignInError {
                Text(appleSignInError)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }
            if let googleSignInError {
                Text(googleSignInError)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
            }

            if hasSignedInAccount {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(PPColor.coralInk)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.appleUserIdentifier != nil ? "Signed in with Apple" : "Signed in with Google")
                            .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.ink)
                        if let email = (draft.appleEmail ?? draft.googleEmail), !email.isEmpty {
                            Text(email)
                                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(PPColor.peach.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                appleSignInError = "Apple sign-in didn’t return a usable credential."
                return
            }
            draft.appleUserIdentifier = credential.user
            if let email = credential.email, !email.isEmpty {
                draft.appleEmail = email
            }
            draft.continuedWithoutAccount = false
            appleSignInError = nil
        case .failure(let error):
            let ns = error as NSError
            if ns.domain == ASAuthorizationError.errorDomain, ns.code == ASAuthorizationError.canceled.rawValue {
                appleSignInError = nil
                return
            }
            appleSignInError = "Sign in with Apple couldn’t finish. Try again, or use Google."
        }
    }

    private func startGoogleSignIn() {
        googleSignInError = nil
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !clientID.isEmpty else {
            googleSignInError = "Google Sign-In needs a Client ID in Info.plist (GIDClientID)."
            return
        }
        if clientID.contains("REPLACE_WITH_GOOGLE") {
            googleSignInError = "Google Sign-In needs a Client ID. Paste your iOS OAuth Client ID into Info.plist (GIDClientID) and set the URL scheme to the reversed client id from Google Cloud Console."
            return
        }

        // Ensure configuration is set from Bundle (single source of truth).
        if GIDSignIn.sharedInstance.configuration == nil {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        guard let presenter = Self.topPresentingViewController() else {
            googleSignInError = "Couldn’t open Google Sign-In. Try again, or use Apple."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, error in
            DispatchQueue.main.async {
                if let error {
                    let ns = error as NSError
                    // User cancel — soft.
                    if ns.domain == "com.google.GIDSignIn", ns.code == -5 {
                        googleSignInError = nil
                        return
                    }
                    googleSignInError = "Google Sign-In couldn’t finish. Try again, or use Apple."
                    return
                }
                guard let user = result?.user else {
                    googleSignInError = "Google Sign-In didn’t return a usable account. Try again, or use Apple."
                    return
                }
                draft.googleUserIdentifier = user.userID
                if let email = user.profile?.email, !email.isEmpty {
                    draft.googleEmail = email
                }
                draft.continuedWithoutAccount = false
                googleSignInError = nil
            }
        }
    }

    /// Active window scene root for `GIDSignIn.sharedInstance.signIn(withPresenting:)`.
    private static func topPresentingViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let window = active?.windows.first(where: \.isKeyWindow) ?? active?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    private func refreshWeightProjectionEstimate() {
        guard let age = draft.ageYears else {
            draft.estimatedReachDate = nil
            draft.estimatedReachSkippedUnder18 = false
            return
        }
        if age < 18 {
            draft.estimatedReachDate = nil
            draft.estimatedReachSkippedUnder18 = true
            return
        }
        draft.estimatedReachSkippedUnder18 = false
        guard let current = draft.currentWeightKilograms,
              let target = draft.targetWeightKilograms,
              let pace = draft.goalPace else {
            draft.estimatedReachDate = nil
            return
        }
        let kgPerWeek: Double
        switch pace {
        case "Slow": kgPerWeek = 0.25
        case "Faster": kgPerWeek = 0.75
        default: kgPerWeek = 0.5 // Steady
        }
        let delta = abs(Double(current - target))
        if delta < 0.5 {
            draft.estimatedReachDate = Date()
            return
        }
        let weeks = max(1.0, delta / kgPerWeek)
        draft.estimatedReachDate = Calendar.current.date(byAdding: .day, value: Int((weeks * 7.0).rounded()), to: Date())
    }

    private func startPlanBuildingAnimation() {
        planBuildProgress = 0
        planBuildPhaseIndex = 0
        planInterruptIndex = 0
        planBuildPausedForQuestion = false

        if reduceMotion {
            // Jump to complete checklist, ask any missing Qs as simple cards, then advance.
            planBuildPhaseIndex = planPhases.count - 1
            planBuildProgress = 1
            Task { @MainActor in
                for q in planInterruptQuestions {
                    guard step == .planBuilding else { return }
                    planBuildPausedForQuestion = true
                    // Wait until user answers (paused flag cleared in applyPlanInterruptAnswer).
                    while planBuildPausedForQuestion {
                        try? await Task.sleep(for: .milliseconds(120))
                        guard step == .planBuilding else { return }
                    }
                }
                guard step == .planBuilding else { return }
                try? await Task.sleep(for: .milliseconds(350))
                moveToNextStep()
            }
            return
        }

        Task { @MainActor in
            let interruptAfterPhases = [0, 1] // pause after profile + metabolism rows when Qs remain
            for phase in 0..<planPhases.count {
                guard step == .planBuilding else { return }
                planBuildPhaseIndex = phase
                planBuildProgress = 0
                for tick in 1...12 {
                    // Pause loop while interrupt visible.
                    while planBuildPausedForQuestion {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard step == .planBuilding else { return }
                    }
                    try? await Task.sleep(for: .milliseconds(90))
                    guard step == .planBuilding else { return }
                    planBuildProgress = Double(tick) / 12.0
                }
                if interruptAfterPhases.contains(phase),
                   planInterruptIndex < planInterruptQuestions.count {
                    planBuildPausedForQuestion = true
                    while planBuildPausedForQuestion {
                        try? await Task.sleep(for: .milliseconds(100))
                        guard step == .planBuilding else { return }
                    }
                }
            }
            guard step == .planBuilding else { return }
            // Drain any remaining interrupt Qs.
            while planInterruptIndex < planInterruptQuestions.count {
                planBuildPausedForQuestion = true
                while planBuildPausedForQuestion {
                    try? await Task.sleep(for: .milliseconds(100))
                    guard step == .planBuilding else { return }
                }
            }
            planBuildProgress = 1
            try? await Task.sleep(for: .milliseconds(400))
            guard step == .planBuilding else { return }
            moveToNextStep()
        }
    }

    private func maybeRequestMidflowReview() {
        guard !didRequestMidflowReview else { return }
        didRequestMidflowReview = true
        // Soft mid-flow rate: request once; Apple may suppress the prompt.
        requestReview()
    }

    private func goBack() {
        focusedField = nil
        // Welcome shortcut: "I already have an account" jumps to .account. rawValue-1 would land on
        // .softPaywall (Premium). Send those users back to .welcome instead.
        if step == .account && enteredAccountFromWelcomeShortcut {
            enteredAccountFromWelcomeShortcut = false
            step = .welcome
            return
        }
        guard let previous = Step(rawValue: max(Step.welcome.rawValue, step.rawValue - 1)) else { return }
        step = previous
    }

    private func continueFlow() {
        guard !requiredMeasurementMissing else { return }
        switch step {
        case .reminders:
            guard !notificationRequestBusy else { return }
            Task { @MainActor in
                notificationRequestBusy = true
                await requestNotificationPermissionAfterReminders()
                notificationRequestBusy = false
                moveToNextStep()
            }
        case .account:
            guard hasSignedInAccount else { return }
            draft.continuedWithoutAccount = false
            onComplete(draft)
        case .softPaywall:
            moveToNextStep()
        case .finish, .rateApp, .planBuilding, .weightProjection:
            moveToNextStep()
        default:
            moveToNextStep()
        }
    }

    private var reminderRecapValue: String {
        guard let pref = draft.reminderPreference else { return "Not set · not scheduled" }
        if pref == "Set up later" { return "Set up later · not scheduled" }
        return "\(pref) · local reminders if allowed"
    }

    /// After the reminders preference step, ask iOS for notification permission (system sheet) on MainActor.
    /// Skipped when the user chose “Set up later” / left preference nil.
    /// On grant, schedules gentle local reminders matching the preference (meal times may refine later at finish).
    @MainActor
    private func requestNotificationPermissionAfterReminders() async {
        guard ReminderNotifications.shouldRequest(for: draft.reminderPreference) else { return }
        let granted = await ReminderNotifications.requestAuthorization()
        if granted {
            await ReminderNotifications.reschedule(
                preference: draft.reminderPreference,
                firstMealTime: draft.firstMealTime,
                companionName: draft.sanitizedCompanionName
            )
        }
    }

    private func skipCurrentStep() {
        focusedField = nil
        switch step {
        case .pipName: draft.companionName = "Pip"
        case .userName: draft.userName = ""
        case .reminders: draft.reminderPreference = nil
        case .mealWindow: draft.firstMealTime = ""; draft.lastMealTime = ""
        case .fastingSchedule: draft.fastingSchedulePreference = nil
        case .eatingLocations: draft.eatingLocations = []
        case .dietPreference: draft.dietPreference = nil
        case .foodRestrictions: draft.foodRestrictions = ["No restrictions"]
        case .waterAdequacy: draft.waterAdequacy = nil
        case .habitChanges: draft.habitChanges = ["No change for now"]
        case .weekendEating: draft.weekendEating = nil
        case .cravings: draft.cravingsFrequency = nil
        case .activityLevel: draft.activityLevel = nil
        case .connectHealth:
            draft.healthKitConnected = false
            draft.healthKitSkipped = true
        case .extraGoals: draft.additionalGoals = []
        case .rateApp: break
        case .softPaywall: break
        default: break
        }
        moveToNextStep()
    }

    private func moveToNextStep() {
        guard let next = Step(rawValue: min(Step.allCases.count - 1, step.rawValue + 1)) else { return }
        step = next
    }
}

private struct PipQuestionCompanion: View {
    let assetNames: [String]
    let label: String
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var frameIndex = 0

    private var shouldAnimate: Bool {
        isVisible && scenePhase == .active && !reduceMotion && assetNames.count > 1
    }

    var body: some View {
        Image(assetNames.indices.contains(frameIndex) ? assetNames[frameIndex] : assetNames.first ?? "PP_PipWelcome")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isImage)
            .task(id: shouldAnimate) {
                guard shouldAnimate else { frameIndex = 0; return }
                frameIndex = 0
                while shouldAnimate && !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .milliseconds(2200))
                        guard shouldAnimate, !Task.isCancelled else { return }
                        frameIndex = (frameIndex + 1) % assetNames.count
                    } catch {
                        return
                    }
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
            .onChange(of: scenePhase) { _, phase in isVisible = phase == .active }
            .onChange(of: reduceMotion) { _, reduced in isVisible = !reduced && scenePhase == .active }
    }
}

private struct PipTonePose: View {
    let style: PipStyle
    let size: CGFloat

    private var poseName: String {
        switch style {
        case .cheerleader: "PipToneCheerleader"
        case .gentle: "PipToneGentleFriend"
        case .straightTalker: "PipToneStraightTalker"
        case .mindful: "PipToneMindfulGuide"
        }
    }

    var body: some View {
        Image(poseName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pip in the \(style.rawValue) pose")
    }
}

private struct PipToneShowcase: View {
    let style: PipStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var poseName: String {
        switch style {
        case .cheerleader: "PipToneCheerleader"
        case .gentle: "PipToneGentleFriend"
        case .straightTalker: "PipToneStraightTalker"
        case .mindful: "PipToneMindfulGuide"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(BitePalColor.mintScreen.opacity(0.62))
                Image(poseName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 136, maxHeight: 126)
                    .id(poseName)
                    .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.92)))
                    .accessibilityHidden(true)
            }
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82), value: style)

            Text(style.rawValue)
                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pip’s \(style.rawValue) tone selected")
    }
}
