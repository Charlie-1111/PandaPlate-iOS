import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var step = 0
    @State private var selectedGoal: WellnessGoal = .balanced
    @State private var selectedStyle: PipStyle = .gentle
    @State private var selectedLoggingFamiliarity = "This is new to me"
    @State private var selectedFastingFamiliarity = "No"
    @State private var selectedReminder = "Set up later"
    @State private var selectedMeals = 3
    @State private var petName = "Pip"
    @State private var userName = ""
    @State private var skipRevealAnimation = false
    @State private var teaserIsVisible = false
    @State private var selectedPlaces: Set<String> = ["Cook at home"]
    @State private var selectedSupport: Set<String> = []
    @State private var firstMealTime = ""
    @State private var lastMealTime = ""
    @State private var timeValidationMessage: String?
    private let steps = 15

    private var pipGridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var routineGridColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 84), spacing: 8)]
    }

    var body: some View {
        Group {
            if step == 5 {
                fullScreenTeaser
            } else if step == 6 {
                fullScreenReveal
            } else {
                standardFlow
            }
        }
        .background(PPColor.cream.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: step)
    }

    private var fullScreenTeaser: some View {
        ZStack {
            Group {
                if reduceMotion {
                    Image("PandaPlateHomeCheer")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 28)
                } else if let url = Bundle.main.url(forResource: "red_panda_welcome_animation", withExtension: "mp4") {
                    MutedOneShotVideo(url: url, shouldPlay: teaserIsVisible && scenePhase == .active)
                        .accessibilityLabel("Muted local preview of Pip waving hello")
                } else {
                    Image("PandaPlateHomeCheer")
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 28)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PPColor.mint)
            .ignoresSafeArea()
            .accessibilityHidden(true)

            LinearGradient(
                stops: [
                    .init(color: PPColor.ink.opacity(0.34), location: 0),
                    .init(color: .clear, location: 0.24),
                    .init(color: PPColor.ink.opacity(0.10), location: 0.58),
                    .init(color: PPColor.ink.opacity(0.62), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                onboardingHeader

                Spacer(minLength: 20)
                VStack(spacing: 12) {
                    Text("YOUR LITTLE WORLD")
                        .font(.system(size: 11, weight: .heavy, design: .rounded, relativeTo: .caption2))
                        .tracking(1.5)
                        .foregroundStyle(PPColor.coralInk)
                    Text("Someone’s here to say hello")
                        .font(.system(size: 32, weight: .black, design: .rounded, relativeTo: .largeTitle))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.ink)
                    Text("A friendly new face is waiting just around the corner.")
                        .font(.system(size: 15, weight: .medium, design: .rounded, relativeTo: .subheadline))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.ink.opacity(0.84))
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 22)
                .frame(maxWidth: 430)
                .background(PPColor.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.75), lineWidth: 1))

                Spacer(minLength: 24)
                VStack(spacing: 8) {
                    PrimaryButton(title: "Open", symbol: "arrow.right") { advanceStep() }
                    Button("Skip intro video") { advanceStep() }
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityHint("Skips the local video and continues to Pip’s reveal")
                }
                .frame(maxWidth: 430)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
        }
        .background(PPColor.mint)
        .onAppear { teaserIsVisible = true }
        .onDisappear { teaserIsVisible = false }
        .onChange(of: scenePhase) { _, phase in teaserIsVisible = phase == .active }
    }

    private var standardFlow: some View {
        VStack(spacing: 0) {
            if step > 0 {
                onboardingHeader
            }

            ScrollView(showsIndicators: false) {
                Group {
                    switch step {
                    case 0: welcome
                    case 1: goalSelection
                    case 2: additionalGoals
                    case 3: loggingFamiliaritySetup
                    case 4: fastingFamiliaritySetup
                    case 7: petNameSetup
                    case 8: userNameSetup
                    case 9: pipSelection
                    case 10: reminderSetup
                    case 11: mealCountSetup
                    case 12: mealTimeSetup
                    case 13: eatingPlaceSetup
                    case 14: planPreview
                    default: planPreview
                    }
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, step == 0 ? 34 : 18)
                .padding(.bottom, 22)
            }

            footerButton
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(PPColor.cream.opacity(0.97))
        }
        .background(PPColor.cream.ignoresSafeArea())
    }

    private var fullScreenReveal: some View {
        VStack(spacing: 0) {
            onboardingHeader
            ScrollView(showsIndicators: false) {
                VStack(spacing: 15) {
                    Eyebrow(text: "A little pause")
                    Text("Pip is ready to meet you")
                        .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.ink)
                    Text("Pip’s here for gentle company. No hidden plan, score, streak or perfect day required.")
                        .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.muted)
                    PipRevealAnimationView(animationEnabled: !skipRevealAnimation)
                        .accessibilityLabel("Pip opens the box, pops up to meet you and settles into a happy pose")
                    if reduceMotion {
                        Text("Static Pip art is shown because Reduce Motion is on.")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    } else {
                        Button(skipRevealAnimation ? "Pip is shown as a still image" : "Skip animation") {
                            skipRevealAnimation = true
                        }
                        .disabled(skipRevealAnimation)
                        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    Text("Next, you can name your companion and tell us what to call you.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(PPColor.ink)
                }
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 22)
                .padding(.top, 18)
                .padding(.bottom, 16)
            }
            PrimaryButton(title: "Meet Pip") { advanceStep() }
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(PPColor.cream.opacity(0.97))
        }
        .background(PPColor.cream.ignoresSafeArea())
    }

    private var onboardingHeader: some View {
        let countedStep = step == 0 ? 0 : (step <= 9 ? step : step - 1)
        return HStack(spacing: 12) {
            Button {
                withAnimation { step = max(0, step - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(PPColor.ink)
                    .frame(width: 44, height: 44)
                    .background(PPColor.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to the previous setup step")

            ProgressSegments(current: max(0, countedStep - 1), count: 13)

            Text("\(countedStep)/13")
                .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }

    private var welcome: some View {
        VStack(spacing: 16) {
            HStack {
                Text("PandaPlate")
                    .font(.system(size: 18, weight: .heavy, design: .rounded, relativeTo: .title3))
                    .foregroundStyle(PPColor.coralInk)
                Spacer()
                Image(systemName: "heart.fill")
                    .foregroundStyle(PPColor.coral.opacity(0.8))
            }
            .padding(.bottom, 8)

            Text("Small bites.\nBig little wins.")
                .font(.system(size: 36, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .foregroundStyle(PPColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Start with one small step that feels right for you.")
                .font(.system(size: 15, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
                .multilineTextAlignment(.center)

            Text("No account. Your choices, meals and photos stay in this session and clear when you close the app.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
                .multilineTextAlignment(.center)

            PandaPlateWelcomeMotion()
                .padding(.vertical, 2)

            Text("No perfect routine required.")
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink.opacity(0.76))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(PPColor.lavender.opacity(0.72), in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var goalSelection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your goals")
            Text("What feels right\nfor you?")
                .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Choose a focus. You can change it any time.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipThinking", "PP_PipGentle"], label: "Pip thinks along with you", size: 88)
                .frame(maxWidth: .infinity)

            ForEach(WellnessGoal.allCases) { goal in
                ChoiceRow(title: goal.rawValue, subtitle: goal.detail, symbol: goal.symbol, isSelected: selectedGoal == goal) {
                    selectedGoal = goal
                }
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var additionalGoals: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your goals")
            Text("Anything else you’d like to work on?")
                .font(.system(size: 29, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("These optional tags stay in this session. They don’t change food advice or calculations.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipPeek", "PP_PipLove"], label: "Pip cheers you on", size: 76)
                .frame(maxWidth: .infinity)
            LazyVGrid(columns: pipGridColumns, spacing: 9) {
                supportChip("A kinder food relationship", symbol: "heart.fill")
                supportChip("Everyday wellbeing", symbol: "sun.max.fill")
                supportChip("More daily energy", symbol: "bolt.fill")
                supportChip("More variety", symbol: "carrot.fill")
                supportChip("Feel good about me", symbol: "face.smiling")
                supportChip("Support movement", symbol: "figure.walk")
                supportChip("Less stress", symbol: "wind")
                supportChip("Learn about nutrition", symbol: "book.fill")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loggingFamiliaritySetup: some View {
        VStack(alignment: .leading, spacing: 17) {
            Eyebrow(text: "Your experience")
            Text("Have you used a food log before?")
                .font(.system(size: 30, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("This helps us make the next screens feel familiar. It won’t change nutrition calculations.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipThinking", "PP_PipGentle"], label: "Pip thinks along with you", size: 80)
                .frame(maxWidth: .infinity)
            ForEach(["This is new to me", "I’ve logged before", "I log regularly"], id: \.self) { choice in
                ChoiceRow(title: choice, subtitle: "A different starting point is always okay.", symbol: "square.and.pencil", isSelected: selectedLoggingFamiliarity == choice) {
                    selectedLoggingFamiliarity = choice
                }
            }
        }
    }

    private var fastingFamiliaritySetup: some View {
        VStack(alignment: .leading, spacing: 17) {
            Eyebrow(text: "Your experience")
            Text("Have you heard of intermittent fasting?")
                .font(.system(size: 29, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("This is only a familiarity question. PandaPlate won’t set a fasting window or give fasting advice.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipRest", "PP_PipThinking"], label: "Pip waits while you choose", size: 80)
                .frame(maxWidth: .infinity)
            ForEach(["Yes", "No"], id: \.self) { choice in
                ChoiceRow(title: choice, subtitle: "No follow-up plan or recommendation is attached.", symbol: choice == "Yes" ? "checkmark" : "xmark", isSelected: selectedFastingFamiliarity == choice) {
                    selectedFastingFamiliarity = choice
                }
            }
        }
    }

    private var pipSelection: some View {
        VStack(spacing: 18) {
            Eyebrow(text: "Your daily companion")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Meet your kind\nof encouragement")
                .font(.system(size: 30, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .multilineTextAlignment(.leading)
                .foregroundStyle(PPColor.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Pick the tone that makes check-ins feel comfortable.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipWelcome", "PP_PipLove"], label: "Pip offers a friendly hello", size: 78)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: pipGridColumns, spacing: 10) {
                ForEach(PipStyle.allCases) { style in
                    Button {
                        selectedStyle = style
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: style.symbol)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(selectedStyle == style ? PPColor.coralInk : PPColor.ink)
                            Text(style.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.ink)
                                .multilineTextAlignment(.center)
                            if selectedStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(PPColor.coralInk)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 92)
                        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedStyle == style ? PPColor.coral : PPColor.line.opacity(0.6), lineWidth: selectedStyle == style ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(style.rawValue), \(selectedStyle == style ? "selected" : "not selected")")
                    .accessibilityValue(selectedStyle == style ? "Selected" : "Not selected")
                    .accessibilityHint("Choose Pip’s encouragement style")
                    .accessibilityAddTraits(selectedStyle == style ? .isSelected : [])
                }
            }
        }
    }

    private var reminderSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(text: "Reminder preference · not activated")
            Text("When might a gentle reminder suit you?")
                .font(.system(size: 29, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("This saves a session-only preference. No reminder is scheduled, and no notification permission is requested.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipRest", "PP_PipGentle"], label: "Pip waits quietly", size: 76)
                .frame(maxWidth: .infinity)
            ForEach(["In the morning", "Before each meal", "When Pip is hungry"], id: \.self) { choice in
                ChoiceRow(title: choice, subtitle: "Preference only; notifications are unavailable.", symbol: "bell", isSelected: selectedReminder == choice) {
                    selectedReminder = choice
                }
            }
            ChoiceRow(title: "Set up later", subtitle: "Continue without choosing a reminder time.", symbol: "clock", isSelected: selectedReminder == "Set up later") {
                selectedReminder = "Set up later"
            }
        }
    }

    private var mealCountSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your routine")
            Text("How many meals\nfit your day?")
                .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("A simple reference choice, not a target or prescription.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipChef", "PP_PipThinking"], label: "Pip thinks about meal routines", size: 76)
                .frame(maxWidth: .infinity)

            PPCard {
                VStack(alignment: .leading, spacing: 13) {
                    Text("Meals each day")
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    LazyVGrid(columns: routineGridColumns, spacing: 8) {
                        ForEach([1, 2, 3, 4, 5], id: \.self) { count in
                            Button {
                                selectedMeals = count
                            } label: {
                                Text("\(count) meals")
                                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(selectedMeals == count ? .white : PPColor.ink)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                                    .background(selectedMeals == count ? PPColor.coralInk : PPColor.cream, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(count) meals each day, \(selectedMeals == count ? "selected" : "not selected")")
                            .accessibilityValue(selectedMeals == count ? "Selected" : "Not selected")
                            .accessibilityHint("Choose how many meals to plan for")
                            .accessibilityAddTraits(selectedMeals == count ? .isSelected : [])
                        }
                    }
                }
            }

        }
    }

    private var mealTimeSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your routine")
            Text("When does your\nmeal day begin?")
                .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Optional reference times. PandaPlate won’t set reminders or infer a fasting window.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipRest", "PP_PipGentle"], label: "Pip waits gently while you choose", size: 72)
                .frame(maxWidth: .infinity)

            PPCard {
                VStack(alignment: .leading, spacing: 14) {
                    timeField("First meal", placeholder: "08:30", value: $firstMealTime)
                    timeField("Last meal", placeholder: "19:00", value: $lastMealTime)
                    Text("Use 24-hour time. Leave either or both blank if you’d rather skip.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                    if let timeValidationMessage {
                        Text(timeValidationMessage)
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                    Button("Skip for now") {
                        firstMealTime = ""
                        lastMealTime = ""
                        timeValidationMessage = nil
                        advanceStep()
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }

            Text("Reminders aren’t available yet, and no notification permission is requested.")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }

    private var eatingPlaceSetup: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Your routine")
            Text("Where do you\nusually eat?")
                .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Choose any that fit. Your routine can change from day to day.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipLove", "PP_PipChef"], label: "Pip celebrates every kind of meal", size: 72)
                .frame(maxWidth: .infinity)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 9) {
                    placeButton("Cook at home", symbol: "house.fill")
                    placeButton("Order in", symbol: "bicycle")
                    placeButton("Eat out", symbol: "fork.knife")
                }
            } else {
                HStack(spacing: 9) {
                    placeButton("Cook at home", symbol: "house.fill")
                    placeButton("Order in", symbol: "bicycle")
                    placeButton("Eat out", symbol: "fork.knife")
                }
            }

            PPCard {
                Label("Pick more than one", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private var petNameSetup: some View {
        VStack(alignment: .leading, spacing: 17) {
            Eyebrow(text: "Your companion")
            Text("What would you like to call your pet?")
                .font(.system(size: 30, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Pip is the default. This name is kept only while the app is open.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipPeek", "PP_PipWelcome"], label: "Pip waits for a name", size: 82)
                .frame(maxWidth: .infinity)
            PPCard {
                TextField("Pip", text: $petName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Pet name")
                    .onChange(of: petName) { _, value in
                        if value.count > 24 { petName = String(value.prefix(24)) }
                    }
            }
            Button("Keep Pip’s name") {
                petName = "Pip"
                advanceStep()
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
            .foregroundStyle(PPColor.coralInk)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userNameSetup: some View {
        VStack(alignment: .leading, spacing: 17) {
            Eyebrow(text: "A personal hello")
            Text("What should we call you?")
                .font(.system(size: 30, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Optional, used only for Pip’s greeting during this session.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.muted)
            PipReactionBeat(assetNames: ["PP_PipGentle", "PP_PipLove"], label: "Pip offers a friendly hello", size: 78)
                .frame(maxWidth: .infinity)
            PPCard {
                TextField("Your name", text: $userName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Your name, optional")
                    .onChange(of: userName) { _, value in
                        if value.count > 24 { userName = String(value.prefix(24)) }
                    }
            }
            Button("Skip for now") {
                userName = ""
                advanceStep()
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
            .foregroundStyle(PPColor.coralInk)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeField(_ title: String, placeholder: String, value: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.ink)
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(width: 100, height: 44)
                .accessibilityLabel("\(title) time, optional, 24-hour format")
        }
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.22)) { step = min(steps - 1, step + 1) }
    }

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(text: "Illustrative sample guide")
            Text("A sample guide.\nYour pace.")
                .font(.system(size: 31, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)

            PPCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Illustrative daily guide")
                                .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.muted)
                            Text("2,100 kcal")
                                .font(.system(size: 34, weight: .black, design: .rounded, relativeTo: .largeTitle))
                                .foregroundStyle(PPColor.ink)
                        }
                        Spacer()
                        PipMascot(size: 88)
                    }
                    HStack(spacing: 8) {
                        macroCard("Protein", "105 g", color: PPColor.coral)
                        macroCard("Carbs", "263 g", color: Color(red: 0.44, green: 0.64, blue: 0.43))
                        macroCard("Fat", "70 g", color: Color(red: 0.69, green: 0.59, blue: 0.80))
                    }
                    Text("Illustrative example values—not a personalized or medical nutrition prescription.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
            }

            PPCard {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Water", systemImage: "drop.fill")
                        .foregroundStyle(Color.blue)
                    Text("2,000 ml")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                    Text("Illustrative example only")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
            }
        }
    }

    private var petReveal: some View {
        VStack(spacing: 18) {
            Eyebrow(text: "Your little world")
            Text("Pip is ready to meet you")
                .font(.system(size: 30, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .foregroundStyle(PPColor.ink)
            Text("Your new little companion is here to celebrate small wins and help food logging feel kinder.")
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                .multilineTextAlignment(.center)
                .foregroundStyle(PPColor.muted)
            WelcomeAnimationView()
                .accessibilityLabel("Pip waves hello")
            Text("No streak pressure, guilt, or perfect days required.")
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(PPColor.lavender.opacity(0.72), in: Capsule())
        }
        .frame(maxWidth: .infinity)
    }

    private var footerButton: some View {
        let title = step == 0 ? "Let’s get started" : (step == 5 ? "Open" : (step == 6 ? "Meet Pip" : (step == steps - 1 ? "Open Home" : "Continue")))
        return PrimaryButton(title: title) {
            if step == steps - 1 {
                store.goal = selectedGoal
                store.pipStyle = selectedStyle
                store.companionName = cleanedName(petName, fallback: "Pip")
                store.userName = cleanedName(userName, fallback: "friend")
                store.loggingFamiliarity = selectedLoggingFamiliarity
                store.fastingFamiliarity = selectedFastingFamiliarity
                store.reminderPreference = selectedReminder == "Set up later" ? nil : selectedReminder
                store.mealsPerDay = selectedMeals
                store.firstMealTime = firstMealTime
                store.lastMealTime = lastMealTime
                store.mealPlaces = selectedPlaces
                store.supportFocus = selectedSupport
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    store.finishedOnboarding = true
                }
            } else if step == 12 {
                guard MealTimeValidator.isValidOptional24HourTime(firstMealTime),
                      MealTimeValidator.isValidOptional24HourTime(lastMealTime) else {
                    timeValidationMessage = "Use HH:MM in 24-hour time, or leave a field blank."
                    return
                }
                timeValidationMessage = nil
                advanceStep()
            } else {
                advanceStep()
            }
        }
    }

    private func cleanedName(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : String(trimmed.prefix(24))
    }

    private func supportChip(_ title: String, symbol: String) -> some View {
        let selected = selectedSupport.contains(title)
        return Button {
            if selected { selectedSupport.remove(title) } else { selectedSupport.insert(title) }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(selected ? PPColor.coralInk : PPColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? PPColor.peach : PPColor.mint.opacity(0.78), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(selected ? "selected" : "not selected")")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func placeButton(_ title: String, symbol: String) -> some View {
        let selected = selectedPlaces.contains(title)
        return Button {
            if selectedPlaces.contains(title) {
                selectedPlaces.remove(title)
            } else {
                selectedPlaces.insert(title)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2)).multilineTextAlignment(.center)
            }
            .foregroundStyle(selected ? PPColor.coralInk : PPColor.ink)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 78)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(selected ? PPColor.coralInk : PPColor.line, lineWidth: selected ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PPColor.coralInk)
                        .padding(7)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityRepresentation {
            Toggle(title, isOn: Binding(
                get: { selectedPlaces.contains(title) },
                set: { isOn in
                    if isOn { selectedPlaces.insert(title) }
                    else { selectedPlaces.remove(title) }
                }
            ))
            .accessibilityLabel(title)
            .accessibilityValue(selected ? "Selected" : "Not selected")
            .accessibilityHint("You can choose more than one eating location.")
        }
    }

    private func macroCard(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10, weight: .semibold, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
            Text(value).font(.system(size: 15, weight: .heavy, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.ink)
            Capsule().fill(color).frame(height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 14))
    }
}
