import SwiftUI
import UserNotifications
import PhotosUI
import StoreKit
import UIKit

private enum RootTab: Hashable {
    case home, challenges, stats
}

private enum MealLogMode: Equatable {
    case scan
    case manual
    case photo
}

private enum RootSheet: Identifiable, Equatable {
    case quickLog
    case log(MealLogMode)
    case settings
    case water
    case workout
    case fasting
    case weight

    var id: String {
        switch self {
        case .quickLog: return "quick-log"
        case .log(.scan): return "log-scan"
        case .log(.photo): return "log-photo"
        case .log(.manual): return "log-manual"
        case .settings: return "settings"
        case .water: return "water"
        case .workout: return "workout"
        case .fasting: return "fasting"
        case .weight: return "weight"
        }
    }
}

struct MainShellView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.requestReview) private var requestReview
    @ObservedObject private var firstSuccess = FirstSuccessMoments.shared
    @State private var tab: RootTab = .home
    @State private var activeSheet: RootSheet?
    @State private var showFoodScan = false
    @State private var statsShowsHistory = false
    /// Soft paywall after first success — dismissible; never required for Free.
    @State private var showSoftWall = false

    var body: some View {
        Group {
            switch tab {
            case .home:
                TodayDashboard(
                    onQuickLogTap: { activeSheet = .quickLog },
                    onSettingsTap: { activeSheet = .settings },
                    onScanTap: { openMealLog(.scan) },
                    onManualTap: { openMealLog(.manual) }
                )
            case .challenges:
                ChallengesDashboard(
                    onMealTap: { openMealLog(.manual) },
                    onWaterTap: { activeSheet = .water },
                    onWorkoutTap: { activeSheet = .workout }
                )
                .environmentObject(store)
            case .stats:
                ProgressDashboard(showingHistory: statsShowsHistory).id(statsShowsHistory).environmentObject(store)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .background {
            if tab == .home {
                GeometryReader { proxy in
                    Image("PandaPlateHomeWorldBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            } else {
                PPColor.cream.ignoresSafeArea()
            }
        }
        .fullScreenCover(isPresented: $showFoodScan) {
            FoodScanSheet()
                .environmentObject(store)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quickLog:
                QuickLogSheet(
                    onFoodCamera: {
                        activeSheet = nil
                        // Food → camera directly (FoodScanSheet opens on camera step).
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { openMealLog(.scan) }
                    },
                    onWaterTap: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .water }
                    },
                    onWorkout: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .workout }
                    },
                    onWeight: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .weight }
                    },
                    onFasting: {
                        activeSheet = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .fasting }
                    }
                )
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .log(let mode):
                // Food Scan uses fullScreenCover (showFoodScan); sheet path is manual/other only.
                LogMealSheet(initialMode: mode == .scan ? .manual : mode)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .settings:
                ProfileView(isPresentedAsSheet: true)
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .water:
                WaterQuickLogSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .workout:
                WorkoutPickerLogView(workouts: $store.workouts, onFinish: {
                    activeSheet = nil
                    statsShowsHistory = true
                    tab = .stats
                })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .fasting:
                FastingLogView(onFinish: {
                    activeSheet = nil
                    statsShowsHistory = true
                    tab = .stats
                })
                    .environmentObject(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .weight:
                WeightLogSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        // Soft wall: only when no other sheet is up (never cold-launch, never quota Unlock path).
        .sheet(isPresented: $showSoftWall, onDismiss: {
            firstSuccess.markSoftWallDismissed()
        }) {
            PremiumPaywallView(isSoftPrompt: true)
        }
        .onChange(of: firstSuccess.pendingNativeReview) { _, pending in
            guard pending else { return }
            requestNativeReview()
        }
        .onChange(of: firstSuccess.shouldPresentSoftWall) { _, want in
            guard want else { return }
            presentSoftWallIfIdle()
        }
        .onChange(of: activeSheet) { _, sheet in
            if sheet == nil, firstSuccess.shouldPresentSoftWall {
                // Wait for dismiss animation so soft wall isn't stacked on log sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    presentSoftWallIfIdle()
                }
            }
        }
        .onAppear {
            if firstSuccess.pendingNativeReview {
                requestNativeReview()
            }
            if firstSuccess.shouldPresentSoftWall {
                presentSoftWallIfIdle()
            }
        }
    }

    private func presentSoftWallIfIdle() {
        guard firstSuccess.shouldPresentSoftWall else { return }
        guard activeSheet == nil else { return }
        guard !PremiumAccess.shared.isPremium else {
            firstSuccess.markSoftWallDismissed()
            return
        }
        guard !showSoftWall else { return }
        showSoftWall = true
    }

    private func requestNativeReview() {
        guard firstSuccess.pendingNativeReview else { return }
        // Prefer SwiftUI RequestReviewAction; Apple may suppress — no custom review UI.
        requestReview()
        firstSuccess.markReviewRequested()
    }

    private func openMealLog(_ mode: MealLogMode) {
        if mode == .scan {
            // Full-screen Food Scan → system camera immediately (not a half-sheet chrome flash).
            showFoodScan = true
        } else {
            activeSheet = .log(mode)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {
                tabButton(.home, title: "Home", symbol: "house.fill")
                tabButton(.challenges, title: "Challenges", symbol: "star.fill")
                tabButton(.stats, title: "Stats", symbol: "chart.bar.fill")
            }
            .padding(4)
            .frame(maxWidth: 248, minHeight: 62)
            .background(Color(red: 0.93, green: 0.93, blue: 0.95), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)

            Spacer(minLength: 18)

            Button { activeSheet = .quickLog } label: {
                Image(systemName: "plus")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 68, height: 68)
                    .background(BitePalColor.ctaBlack, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quick actions")
            .accessibilityHint("Opens meal, water, workout, weight and fasting actions")
        }
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private func tabButton(_ item: RootTab, title: String, symbol: String) -> some View {
        let selected = tab == item
        return Button {
            if item == .stats { statsShowsHistory = false }
            tab = item
        } label: {
            ZStack {
                if selected {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
                        .frame(width: 46, height: 46)
                }
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: selected ? .bold : .semibold))
                    .foregroundStyle(selected ? BitePalColor.ctaBlack : Color(red: 0.69, green: 0.69, blue: 0.72))
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ChallengesDashboard: View {
    @EnvironmentObject private var store: AppStore
    let onMealTap: () -> Void
    let onWaterTap: () -> Void
    let onWorkoutTap: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Challenges")
                    .font(.system(size: 27, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
                Text("Three small choices from PandaPlate. Progress follows your actual logs, at your pace.")
                    .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                challengeCard(
                    title: "Save a meal note",
                    detail: "Add one meal entry this session.",
                    symbol: "fork.knife",
                    progress: PandaPlateChallengeProgress.mealNotes(in: store),
                    target: 1,
                    actionTitle: "Log a meal",
                    action: onMealTap
                )
                challengeCard(
                    title: "Take a water break",
                    detail: "Record a cup, glass or bottle you actually drank.",
                    symbol: "drop.fill",
                    progress: PandaPlateChallengeProgress.waterCups(in: store),
                    target: 1,
                    actionTitle: "Choose a size",
                    action: onWaterTap
                )
                challengeCard(
                    title: "Move your way",
                    detail: "Log one activity this session.",
                    symbol: "figure.walk",
                    progress: PandaPlateChallengeProgress.activities(in: store),
                    target: 1,
                    actionTitle: "Log an activity",
                    action: onWorkoutTap
                )

                Text("These app-set challenges use session-only logs. They don’t estimate calories or create health scores.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
        }
        .background(PPColor.cream)
    }

    private func challengeCard(
        title: String,
        detail: String,
        symbol: String,
        progress: Int,
        target: Int,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let value = min(target, max(0, progress))
        return PPCard {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PPColor.coralInk)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .headline))
                            .foregroundStyle(PPColor.ink)
                        Text(detail)
                            .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.muted)
                    }
                    Spacer(minLength: 0)
                    Text("\(value)/\(target)")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                        .accessibilityLabel("\(value) of \(target) completed this session")
                }

                ProgressView(value: Double(value), total: Double(target))
                    .tint(PPColor.coralInk)

                Button(action: action) {
                    Text(value >= target ? "Done this session" : actionTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(value >= target ? PPColor.muted : .white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(value >= target ? PPColor.line : PPColor.coralInk, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(value >= target)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TodayDashboard: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var premium = PremiumAccess.shared
    let onQuickLogTap: () -> Void
    let onSettingsTap: () -> Void
    let onScanTap: () -> Void
    let onManualTap: () -> Void

    @State private var showNutritionPaywall = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    private var mealsWithCalories: Int {
        store.meals.filter { $0.calories != nil }.count
    }

    private var mealsMissingCalories: Int {
        store.meals.filter { $0.calories == nil }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                topBar
                PipWorldDashboard(onQuickLogTap: onQuickLogTap)
                    .environmentObject(store)
                sessionSummary
                waterLog
                advancedNutritionCard
                quickActions
                missionCard
                Text("PandaPlate is a gentle wellness tracker, not medical advice.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 3)
                    .padding(.bottom, 16)
            }
            .padding(.horizontal, 18)
            .padding(.top, 13)
        }
        .background(Color.clear)
        .sheet(isPresented: $showNutritionPaywall) {
            PremiumPaywallView(isSoftPrompt: true)
        }
    }

    private var topBar: some View {
        HStack(spacing: 11) {
            PipMascot(size: 50)
                .padding(4)
                .background(PPColor.peach, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(store.userName.isEmpty ? greeting + "!" : "\(greeting), \(store.userName)!")
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                Text("Home")
                    .font(.system(size: 28, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
            }
            Spacer()
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PPColor.ink)
                    .frame(width: 44, height: 44)
                    .background(PPColor.card, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
    }

    private var sessionSummary: some View {
        VStack(spacing: 9) {
            HStack(spacing: 9) {
                sessionSummaryItem("Meals", value: "\(store.meals.count) this session", symbol: "fork.knife")
                sessionSummaryItem("Water", value: "\(store.waterML) ml this session", symbol: "drop.fill")
            }
            healthStepsSummary
        }
    }

    private var healthStepsSummary: some View {
        let sync = HealthKitActivitySync.shared
        let connected = store.healthKitConnected || sync.isConnected
        let steps = store.todayStepsFromHealth ?? sync.todaySteps
        let line: String = {
            if !connected { return "Connect Health" }
            if let steps { return "\(steps) steps today" }
            return "No steps synced yet"
        }()
        return HStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BitePalColor.selectGreen)
            VStack(alignment: .leading, spacing: 3) {
                Text("Movement")
                    .font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.ink)
                Text(line)
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer(minLength: 0)
            if !connected {
                Text("Optional")
                    .font(.system(size: 10, weight: .semibold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 11)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityLabel("Movement, \(line)")
    }

    private func sessionSummaryItem(_ title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PPColor.coralInk)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.ink)
                Text(value)
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.horizontal, 11)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Quick actions")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                quickAction("Food", symbol: "camera.fill", detail: "Opens camera to scan", action: onScanTap)
                quickAction("Quick log", symbol: "plus.circle.fill", detail: "Food, water, workout, weight, fasting", action: onQuickLogTap)
            }
        }
    }

    private func quickAction(_ title: String, symbol: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                Text(detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(12)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }

    /// BitePal-style Advanced nutrition analysis. Premium: honest session data. Free: locked overlay.
    /// Macros stay Unknown unless stored on meals — never invent sample protein/carbs/fat.
    private var advancedNutritionCard: some View {
        ZStack {
            nutritionUnlockedContent
                .blur(radius: premium.isPremium ? 0 : 5)
                .allowsHitTesting(premium.isPremium)

            if !premium.isPremium {
                nutritionLockOverlay
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: premium.isPremium ? .contain : .ignore)
        .accessibilityLabel(premium.isPremium
            ? "Advanced nutrition analysis for this session"
            : "Session nutrition snapshot locked. Optional Premium unlock. Food recognition isn’t connected in this build.")
    }

    private var nutritionUnlockedContent: some View {
        PPCard(padding: 17) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ADVANCED NUTRITION ANALYSIS")
                            .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                            .tracking(1.1).foregroundStyle(PPColor.muted)
                        Text("This session")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body)).foregroundStyle(PPColor.ink)
                    }
                    Spacer()
                    Text(premium.isPremium ? "PREMIUM" : "LOCKED")
                        .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(premium.isPremium ? PPColor.coralInk : PPColor.muted)
                }

                Text(store.caloriesEaten.map { "\($0) kcal logged" } ?? "Calories unknown")
                    .font(.system(size: 24, weight: .black, design: .rounded, relativeTo: .title2))
                    .foregroundStyle(PPColor.ink)

                Text(caloriesHonestyLine)
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)

                HStack(spacing: 8) {
                    nutritionChip("Protein", "Unknown", color: PPColor.coral)
                    nutritionChip("Carbs", "Unknown", color: Color(red: 0.43, green: 0.66, blue: 0.48))
                    nutritionChip("Fat", "Unknown", color: Color(red: 0.64, green: 0.55, blue: 0.77))
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(insightLines, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PPColor.coralInk)
                                .padding(.top, 2)
                                .accessibilityHidden(true)
                            Text(line)
                                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Text("Macros stay Unknown until a meal stores them. Blank calories stay unknown — never counted as zero. Not medical advice.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
        }
    }

    private var nutritionLockOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(PPColor.coralInk)
            Text("Session nutrition snapshot")
                .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.ink)
            Text("See logged calorie estimates and session water with Premium. Unknown nutrition stays unknown. Food recognition isn’t connected in this build.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button {
                showNutritionPaywall = true
            } label: {
                Text("Unlock with Premium")
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(PPColor.coralInk, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .accessibilityHint("Opens a dismissible Premium sheet. Free continues either way.")
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PPColor.cream.opacity(0.72))
    }

    private var caloriesHonestyLine: String {
        if store.meals.isEmpty {
            return "No meals logged yet this session."
        }
        if store.caloriesEaten == nil {
            return "\(store.meals.count) meal(s) logged — calorie estimates still unknown."
        }
        if mealsMissingCalories > 0 {
            return "\(mealsWithCalories) with an estimate · \(mealsMissingCalories) unknown (not counted as zero)."
        }
        return "All \(store.meals.count) logged meal(s) include an estimate."
    }

    private var insightLines: [String] {
        var lines: [String] = []
        if store.meals.isEmpty {
            lines.append("Log a meal to start a gentle session snapshot.")
        } else {
            lines.append("You’ve logged \(store.meals.count) meal(s) this session.")
            if store.caloriesEaten != nil {
                lines.append("Calorie total only includes meals with an estimate.")
            } else {
                lines.append("Calories stay unknown until an estimate is saved — we won’t invent one.")
            }
        }
        if store.waterML > 0 {
            lines.append("Water so far: \(store.waterML) ml this session.")
        } else {
            lines.append("No water logged yet — optional, at your pace.")
        }
        lines.append("Protein, carbs and fat stay Unknown — this build doesn’t store macros yet.")
        return lines
    }

    private var waterLog: some View {
        WaterQuickLogView()
            .environmentObject(store)
    }

    private var missionCard: some View {
        Button(action: onQuickLogTap) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PPColor.coral)
                    .frame(width: 42, height: 42)
                    .background(PPColor.peach, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick log")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                    Text("Meal, water, workout or fasting")
                        .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(PPColor.muted)
            }
            .padding(13)
            .background(PPColor.mint.opacity(0.48), in: RoundedRectangle(cornerRadius: 19))
        }
        .buttonStyle(.plain)
    }

    private func nutritionChip(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 9, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
            Text(value).font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.ink)
            Capsule().fill(color).frame(height: 4)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct PipWorldDashboard: View {
    let onQuickLogTap: () -> Void
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var premium = PremiumAccess.shared
    @ObservedObject private var lookStore = PipLookStore.shared
    @ObservedObject private var heartsStore = PipHeartsStore.shared

    private static let greetings = [
        "What sounds good right now?",
        "No rush. One small step.",
    ]

    @State private var greetingIndex = 0
    @State private var phase: PipRitualPhase = .welcome
    @State private var celebrateLove = false
    @State private var showLookPaywall = false

    private var companionDisplayName: String {
        let trimmed = store.companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pip" : trimmed
    }

    private var greetingLine: String {
        Self.greetings[greetingIndex % Self.greetings.count]
    }

    private var softResponse: String {
        "\(companionDisplayName)’s glad you showed up."
    }

    private var selectedLook: PipLook { lookStore.selectedLook }

    private var heroStillName: String {
        selectedLook.stillForPhase(phase, celebrateLove: celebrateLove)
    }

    private var lifeLoopName: String {
        PipLook.lifeLoopResource(for: phase, celebrateLove: celebrateLove)
    }

    private var captionLine: String {
        switch phase {
        case .welcome:
            return greetingLine
        case .saidHi:
            return softResponse
        case .napping:
            return "Pip’s napping. Come back when you’re ready."
        }
    }

    var body: some View {
        // Embedded on Home (no nested ScrollView) — BitePal puts the pet on Home.
        VStack(alignment: .leading, spacing: 16) {
                Text("Pip’s little world")
                    .font(.system(size: 20, weight: .black, design: .rounded, relativeTo: .title3))
                    .foregroundStyle(PPColor.ink)

                VStack(spacing: 10) {
                    ritualHero
                    Text(captionLine)
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(PPColor.card.opacity(0.92), in: Capsule())
                        .accessibilityLabel(captionLine)

                    pipHeartsRow
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 6)

                dressPipSection

                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A soft hello")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.ink)
                        Text("Just a little hello from \(companionDisplayName) when you want company.")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)

                        if phase != .saidHi {
                            Button(action: sayHi) {
                                Text("Say hi to Pip")
                                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(PPColor.coralInk, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Say hi to Pip")
                        } else {
                            Text(softResponse)
                                .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if phase != .napping {
                            Button(action: startNap) {
                                Text("Let Pip rest")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(PPColor.muted)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Let Pip rest")
                        } else {
                            Button(action: wakeGently) {
                                Text("I’m back")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(PPColor.coralInk)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("I’m back")
                        }

                        Button(action: onQuickLogTap) {
                            Label("Log something gently", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(PPColor.peach.opacity(0.72), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Free ritual · no Premium gate · at your own pace.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity)
            }
        .onAppear {
            lookStore.reconcileWithPremium()
            heartsStore.refreshDecayIfNeeded(showUpDays: SoftShowUpStore.shared.days)
            rotateGreetingOnAppear()
        }
        .onChange(of: premium.isPremium) { _, _ in
            lookStore.reconcileWithPremium()
        }
        .sheet(isPresented: $showLookPaywall) {
            PremiumPaywallView(isSoftPrompt: true)
        }
    }

    @ViewBuilder
    private var ritualHero: some View {
        if selectedLook == .base {
            PipLifeLoopView(
                resourceName: lifeLoopName,
                stillAssetName: heroStillName,
                size: 200,
                accessibilityLabel: heroAccessibilityLabel
            )
        } else {
            Image(heroStillName)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .accessibilityLabel("\(selectedLook.displayName) Pip look")
                .accessibilityAddTraits(.isImage)
        }
    }

    private var heroAccessibilityLabel: String {
        switch phase {
        case .welcome:
            return "\(companionDisplayName) waves hello in the forest garden"
        case .saidHi:
            return "\(companionDisplayName) is glad you showed up"
        case .napping:
            return "\(companionDisplayName) is napping"
        }
    }

    private var pipHeartsRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<PipHeartsStore.maxHearts, id: \.self) { index in
                    Image(systemName: index < heartsStore.hearts ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(index < heartsStore.hearts ? PPColor.coral : PPColor.line)
                        .accessibilityHidden(true)
                }
            }
            Text(heartsStore.softStatusLine)
                .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.ink.opacity(0.78))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(PPColor.card.opacity(0.92), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pip hearts \(heartsStore.hearts) of \(PipHeartsStore.maxHearts). \(heartsStore.softStatusLine)")
    }

    private var dressPipSection: some View {
        PPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Dress Pip")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                    Spacer()
                    if premium.isPremium {
                        Text("Premium")
                            .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    } else {
                        Text("Base free · looks with Premium")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PipLook.allCases) { look in
                            lookChip(look)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func lookChip(_ look: PipLook) -> some View {
        let selected = lookStore.selectedLook == look
        let locked = look.requiresPremium && !premium.isPremium
        return Button {
            if lookStore.select(look) {
                // Applied.
            } else {
                showLookPaywall = true
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(look.stillAssetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .padding(6)
                        .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selected ? PPColor.coralInk : PPColor.line.opacity(0.7), lineWidth: selected ? 2 : 1)
                        )
                        .opacity(locked ? 0.45 : 1)

                    if locked {
                        // Soft coral lock — larger so Free locks are obvious; chip opens soft Premium sheet.
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Color(red: 0.94, green: 0.58, blue: 0.52).opacity(0.98), in: Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                            .offset(x: 6, y: -6)
                            .accessibilityHidden(true)
                    }
                }
                Text(look.displayName)
                    .font(.system(size: 11, weight: selected ? .bold : .semibold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(selected ? PPColor.coralInk : PPColor.ink)
            }
            .frame(width: 78)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(locked ? "\(look.displayName), locked. Opens optional Premium." : "\(look.displayName) look")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func rotateGreetingOnAppear() {
        greetingIndex = Int.random(in: 0..<Self.greetings.count)
        if phase == .napping { return }
        if phase != .saidHi {
            phase = .welcome
        }
    }

    private func sayHi() {
        celebrateLove = Bool.random()
        phase = .saidHi
        // Soft Show-Up: Pip saw you today (not a streak).
        SoftShowUpStore.shared.markSeen()
        // First Pip ritual success — soft wall + review milestone (Free path stays open).
        FirstSuccessMoments.shared.notePipRitualCompleted()
    }

    private func startNap() {
        phase = .napping
    }

    private func wakeGently() {
        greetingIndex = Int.random(in: 0..<Self.greetings.count)
        phase = .welcome
    }
}

private struct ProgressDashboard: View {
    private enum Section: String, CaseIterable {
        case progress = "Overview"
        case history = "History"
    }

    @EnvironmentObject private var store: AppStore
    @ObservedObject private var premium = PremiumAccess.shared
    @State private var selectedSection: Section
    @State private var showPaywall = false
    @State private var exportError: String?
    @State private var showSoftShowUpHistory = false

    init(showingHistory: Bool) {
        _selectedSection = State(initialValue: showingHistory ? .history : .progress)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                Text("Stats")
                    .font(.system(size: 27, weight: .black, design: .rounded, relativeTo: .largeTitle)).foregroundStyle(PPColor.ink)
                HStack(spacing: 8) {
                    ForEach(Section.allCases, id: \.self) { section in
                        let isSelected = selectedSection == section
                        Button { selectedSection = section } label: {
                            Text(section.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(isSelected ? .white : PPColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(isSelected ? PPColor.coralInk : PPColor.card, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(section.rawValue)
                        .accessibilityValue(isSelected ? "Selected" : "Not selected")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                if selectedSection == .progress {
                    progressContent
                } else {
                    historyContent
                }
            }
            .padding(18)
            .padding(.bottom, 18)
        }
        .background(PPColor.cream)
    }

    private var progressContent: some View {
        let mealsWithCalories = store.meals.filter { $0.calories != nil }.count
        let mealsWithoutCalories = store.meals.count - mealsWithCalories
        let movementMinutes = store.workouts.reduce(0) { $0 + $1.durationMinutes }
        let workoutCalories = store.workouts.compactMap(\.activeEnergyKcal).reduce(0, +)
        let latestWeight = store.weightLogs.max { $0.time < $1.time }
        let fastingSeconds = store.fastingEntries.reduce(0) { $0 + $1.durationSeconds }

        return VStack(alignment: .leading, spacing: 15) {
            Text("Current session only · these totals change when you log something. They clear when the app closes.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if store.meals.isEmpty && store.waterML == 0 && store.workouts.isEmpty && store.weightLogs.isEmpty && store.fastingEntries.isEmpty && store.fastingStartedAt == nil {
                PPCard {
                    Text("No entries yet. Stats will fill in from things you actually log.")
                        .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            sessionStatCard(
                title: "Meals",
                value: "\(store.meals.count)",
                detail: "\(mealsWithCalories) with a saved calorie estimate · \(mealsWithoutCalories) unknown",
                symbol: "fork.knife",
                tint: PPColor.coralInk
            )
            sessionStatCard(
                title: "Saved calorie estimates",
                value: store.caloriesEaten.map { "\($0.formatted()) kcal" } ?? "Unknown",
                detail: store.caloriesEaten == nil ? "No estimate has been saved this session." : "Sum of saved meal estimates; no target is calculated.",
                symbol: "sum",
                tint: PPColor.coralInk
            )
            sessionStatCard(
                title: "Water",
                value: "\(store.waterML.formatted()) ml",
                detail: "Session total from your water logs.",
                symbol: "drop.fill",
                tint: Color(red: 0.20, green: 0.48, blue: 0.90)
            )
            sessionStatCard(
                title: "Movement",
                value: "\(store.workouts.count) activities · \(movementMinutes) min",
                detail: workoutCalories > 0 ? "Apple Health recorded \(workoutCalories.formatted()) kcal for these session logs." : "No calorie-burn estimate is available for these logs.",
                symbol: "figure.walk",
                tint: Color(red: 0.36, green: 0.63, blue: 0.41)
            )
            sessionStatCard(
                title: "Weight check-ins",
                value: "\(store.weightLogs.count)",
                detail: latestWeight.map { "Most recent: \(String(format: "%.1f", $0.kilograms)) kg, \($0.time.formatted(date: .abbreviated, time: .shortened))." } ?? "No weight check-in logged this session.",
                symbol: "scalemass.fill",
                tint: Color(red: 0.48, green: 0.42, blue: 0.67)
            )
            sessionStatCard(
                title: "Completed fasting logs",
                value: "\(store.fastingEntries.count)",
                detail: fastingSeconds > 0 ? "Total recorded time: \(fastingSeconds / 3_600)h \((fastingSeconds % 3_600) / 60)m." : "No completed fasting time logs this session.",
                symbol: "moon.stars.fill",
                tint: Color(red: 0.45, green: 0.38, blue: 0.72)
            )
        }
    }

    private func sessionStatCard(title: String, value: String, detail: String, symbol: String, tint: Color) -> some View {
        PPCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(PPColor.peach.opacity(0.6), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                    Text(value)
                        .font(.system(size: 19, weight: .black, design: .rounded, relativeTo: .title3))
                        .foregroundStyle(PPColor.ink)
                    Text(detail)
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current session only · clears when the app closes")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
            PPCard {
                SoftShowUpPresenceCard(
                    isPremium: premium.isPremium,
                    onOpenHistory: { showSoftShowUpHistory = true },
                    onFreeTap: { showPaywall = true }
                )
                if SoftShowUpStore.shared.seenCount > 0 && SoftShowUpStore.shared.isSeenToday {
                    SoftShowUpRepairBanner()
                }
            }
            .sheet(isPresented: $showSoftShowUpHistory) {
                SoftShowUpHistoryView()
            }
            PPCard {
                VStack(alignment: .leading, spacing: 10) {
                    SessionCSVExportButton(
                        entries: WeekLogExport.rows(from: store),
                        isPremium: premium.isPremium,
                        onFreeTap: { showPaywall = true },
                        onError: { exportError = $0 }
                    )
                    if let exportError {
                        Text(exportError)
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PremiumPaywallView()
            }
            if store.meals.isEmpty && store.waterML == 0 && store.workouts.isEmpty && store.fastingEntries.isEmpty && store.fastingStartedAt == nil {
                PPCard {
                    Text("No entries logged in this session yet.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.ink)
                }
            }
            ForEach(store.meals) { meal in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Meal · \(meal.name)")
                            .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                        Text(meal.time.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    }
                    Spacer()
                    Text(meal.calories.map { "\($0) kcal" } ?? "No estimate")
                        .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.ink)
                }
                .padding(13)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if store.waterML > 0 {
                HStack {
                    Label("Water · session total", systemImage: "drop.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.ink)
                    Spacer()
                    Text("\(store.waterML) ml")
                        .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
                .padding(13)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            ForEach(store.workouts) { workout in
                Label("Workout · \(workout.activity) · \(workout.durationMinutes) min", systemImage: "figure.walk")
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            ForEach(store.fastingEntries) { entry in
                let durationText = entry.durationSeconds < 60
                    ? "under 1 min"
                    : "\(entry.durationSeconds / 3_600)h \((entry.durationSeconds % 3_600) / 60)m"
                Label("Fasting log · \(durationText)", systemImage: "moon.stars.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if let started = store.fastingStartedAt {
                Label("Fasting session started · \(started.formatted(date: .omitted, time: .shortened))", systemImage: "moon.stars.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .padding(13)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

}

private struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var quota = ScanQuotaStore.shared
    @ObservedObject private var premium = PremiumAccess.shared
    @ObservedObject private var favorites = USDAFavoritesStore.shared
    var isPresentedAsSheet: Bool = false

    @State private var showResetConfirmation = false
    @State private var showPaywall = false
    @State private var prefillNotice: String?
    @State private var showSoftShowUpHistory = false
    #if DEBUG
    @State private var showAdvancedDeveloper = false
    @State private var scanBaseURLDraft = UserDefaults.standard.string(forKey: FoodScanClient.baseURLDefaultsKey) ?? FoodScanClient.defaultBaseURL
    @State private var scanTokenDraft = ""
    @State private var scanTokenSaved = FoodScanClient.configuredScanToken != nil
    @State private var scanURLError: String?
    #endif
    @State private var presentedLegalDocument: PandaPlateLegal.Document? = nil
    @State private var notificationAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var remindersEnabled = true
    @State private var notificationBusy = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                youHeroCard

                premiumCard

                softShowUpCard

                exportCard

                pinsCard

                aboutYouCard

                healthCard

                remindersAndUnitsCard

                privacyCard

                #if DEBUG
                advancedDeveloperDisclosure
                #endif

                #if DEBUG
                clearSessionButton
                #endif

                Text("PandaPlate\nWellness support, not medical advice. Ages 13+.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(18)
            .padding(.bottom, 18)
        }
        .background(PPColor.cream.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            PremiumPaywallView()
        }
        .sheet(isPresented: $showSoftShowUpHistory) {
            SoftShowUpHistoryView()
        }
        .sheet(item: $presentedLegalDocument) { doc in
            PandaPlateLegalDocumentSheet(document: doc)
        }
        .confirmationDialog("Clear this session?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Clear session", role: .destructive) { store.resetDemoSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes meals, photos, water and choices held in memory for this session.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("You")
                    .font(.system(size: 28, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
                Text("Your space with Pip")
                    .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer()
            PipMascot(size: 56)
                .padding(4)
                .background(PPColor.peach.opacity(0.85), in: Circle())
            if isPresentedAsSheet {
                Button("Close") { dismiss() }
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minWidth: 54, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    private var youHeroCard: some View {
        PPCard(padding: 16) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.userName.isEmpty ? "Friend" : store.userName)
                        .font(.system(size: 20, weight: .bold, design: .rounded, relativeTo: .title3))
                        .foregroundStyle(PPColor.ink)
                    Text("with \(store.companionName.isEmpty ? "Pip" : store.companionName)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                    Text(premium.isPremium ? "Premium features active" : "Free plan")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(PPColor.coral)
                    .accessibilityHidden(true)
            }
        }
    }

    private var premiumCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Premium")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Text("Premium includes extra Pip looks, recent show-up history, and session CSV export. Prices and renewal terms come from Apple before purchase.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                Button { showPaywall = true } label: {
                    Text(premium.isPremium ? "Premium benefits" : "View Premium plans")
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(PPColor.coralInk, in: Capsule())
                }
                .buttonStyle(.plain)
                #if DEBUG
                Toggle("Debug: Premium unlocked", isOn: Binding(
                    get: { premium.hasDebugUnlock || premium.isPremium },
                    set: { on in
                        if on {
                            premium.unlockForTesting()
                        } else {
                            premium.lockForTesting()
                        }
                    }
                ))
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .tint(PPColor.coral)
                #endif
            }
        }
    }

    private var softShowUpCard: some View {
        PPCard(padding: 16) {
            SoftShowUpPresenceCard(
                isPremium: premium.isPremium,
                onOpenHistory: { showSoftShowUpHistory = true },
                onFreeTap: { showPaywall = true }
            )
        }
    }

    private var exportCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Export")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Text("Session CSV of meals, water, workouts and fasting — Premium.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                SessionCSVExportButton(
                    entries: WeekLogExport.rows(from: store),
                    isPremium: premium.isPremium,
                    onFreeTap: { showPaywall = true }
                )
            }
        }
    }

    private var pinsCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pinned foods")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Text("Pins store FDC id + name only. Calories stay blank unless already known. Picking a pin never skips scan consent.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                USDAFavoritesList { prefill in
                    favorites.queuePrefill(prefill)
                    let kcalNote = prefill.calories.map { "\($0) kcal" } ?? "kcal unknown"
                    prefillNotice = "Ready for Manual entry: \(prefill.dishName) · \(kcalNote). Food Scan still requires consent."
                }
                if let prefillNotice {
                    Text(prefillNotice)
                        .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.coralInk)
                }
            }
        }
    }

    private var healthCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Apple Health")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Text(healthStatusLine)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                if store.activityCalorieMode == .smart || store.activityCalorieMode == .addAll {
                    Text("Activity calories: \(store.activityCalorieMode.title) (preference only)")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
                Button {
                    Task { @MainActor in
                        let state = await HealthKitActivitySync.shared.requestAuthorization()
                        store.healthKitConnected = (state == .connected)
                        store.todayStepsFromHealth = HealthKitActivitySync.shared.todaySteps
                        if state == .connected {
                            await HealthKitActivitySync.shared.refreshTodaySummary()
                            store.todayStepsFromHealth = HealthKitActivitySync.shared.todaySteps
                            await HealthKitActivitySync.shared.importRecentWorkouts(into: store)
                        }
                    }
                } label: {
                    Text(healthButtonTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Connects Apple Health for steps and workouts, or refreshes today’s summary.")
            }
        }
    }

    private var healthStatusLine: String {
        let sync = HealthKitActivitySync.shared
        if store.healthKitConnected || sync.isConnected {
            if let steps = store.todayStepsFromHealth ?? sync.todaySteps {
                return "Connected · \(steps) steps today"
            }
            return "Connected · No steps synced yet (Simulator may not provide Health data)."
        }
        if sync.connectionState == .denied {
            return "Not connected · Access wasn’t granted. You can try again anytime."
        }
        return "Not connected · Optional read of steps, active energy, exercise time, and workouts."
    }

    private var healthButtonTitle: String {
        if store.healthKitConnected || HealthKitActivitySync.shared.isConnected {
            return "Manage / Refresh Health"
        }
        return "Connect Apple Health"
    }

        private var aboutYouCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("About you")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                profileInfo("Your name", value: store.userName.isEmpty ? "Not set" : store.userName)
                profileInfo("Pet name", value: store.companionName)
                profileInfo("Focus", value: store.goal.rawValue)
                profileInfo("Pip’s style", value: store.pipStyle.rawValue)
                profileInfo("Meals per day", value: "\(store.mealsPerDay)")
                profileInfo("Activity calories", value: store.activityCalorieMode.title)
                profileInfo("Apple Health", value: store.healthKitConnected ? "Connected" : "Not connected")
                profileInfo("Eating settings", value: store.mealPlaces.isEmpty ? "No preference selected" : store.mealPlaces.sorted().joined(separator: ", "))
                if !store.supportFocus.isEmpty {
                    profileInfo("Extra support", value: store.supportFocus.sorted().joined(separator: ", "))
                }
            }
        }
    }

    private var remindersAndUnitsCard: some View {
        VStack(spacing: 12) {
            PPCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reminders")
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)

                    Text(reminderPreferenceLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)

                    Text(notificationStatusLabel)
                        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.ink)

                    switch notificationAuthStatus {
                    case .notDetermined:
                        Button {
                            Task { @MainActor in
                                notificationBusy = true
                                let granted = await ReminderNotifications.requestAuthorization()
                                notificationAuthStatus = await ReminderNotifications.authorizationStatus()
                                if granted {
                                    remindersEnabled = true
                                    await ReminderNotifications.reschedule(
                                        preference: store.reminderPreference,
                                        firstMealTime: store.firstMealTime,
                                        companionName: store.companionName
                                    )
                                }
                                notificationBusy = false
                            }
                        } label: {
                            Text(notificationBusy ? "Asking iOS…" : "Allow notifications")
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(PPColor.coralInk, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(notificationBusy || !ReminderNotifications.shouldRequest(for: store.reminderPreference))
                        .opacity((notificationBusy || !ReminderNotifications.shouldRequest(for: store.reminderPreference)) ? 0.5 : 1)
                        if !ReminderNotifications.shouldRequest(for: store.reminderPreference) {
                            Text("Pick a reminder preference during setup (or clear session and re-run onboarding) to enable scheduling.")
                                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                                .foregroundStyle(PPColor.muted)
                        }
                    case .authorized, .provisional, .ephemeral:
                        if ReminderNotifications.shouldRequest(for: store.reminderPreference) {
                            Toggle(isOn: Binding(
                                get: { remindersEnabled },
                                set: { newValue in
                                    remindersEnabled = newValue
                                    Task { @MainActor in
                                        if newValue {
                                            await ReminderNotifications.reschedule(
                                                preference: store.reminderPreference,
                                                firstMealTime: store.firstMealTime,
                                                companionName: store.companionName
                                            )
                                        } else {
                                            ReminderNotifications.cancelAll()
                                        }
                                    }
                                }
                            )) {
                                Text("Local reminders on")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(PPColor.ink)
                            }
                            .tint(PPColor.coralInk)
                            Text("Gentle daily nudges on this device. Best-effort local delivery — not a guarantee, and nothing syncs to a server.")
                                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                                .foregroundStyle(PPColor.muted)
                        } else {
                            Text("No reminder preference saved for this session. Local notifications stay off until you choose one in setup.")
                                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.muted)
                        }
                    case .denied:
                        Text("Notifications are off in iOS Settings. You can turn them on there anytime — PandaPlate won’t nag.")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                        Button {
                            ReminderNotifications.openSystemSettings()
                        } label: {
                            Text("Open iOS Settings")
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(PPColor.cream, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    @unknown default:
                        Text("Notification status unknown on this device.")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                    }
                }
            }
            .task {
                notificationAuthStatus = await ReminderNotifications.authorizationStatus()
            }
            PPCard(padding: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Units")
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                    Text("Metric units only in this version. Unit switching isn’t available yet.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
            }
        }
    }

    private var reminderPreferenceLabel: String {
        guard let pref = store.reminderPreference, !pref.isEmpty else {
            return "Preference: not set this session"
        }
        return "Preference: \(pref)"
    }

    private var notificationStatusLabel: String {
        switch notificationAuthStatus {
        case .notDetermined: return "Permission: not asked yet"
        case .denied: return "Permission: denied in iOS Settings"
        case .authorized: return "Permission: allowed"
        case .provisional: return "Permission: provisional"
        case .ephemeral: return "Permission: ephemeral"
        @unknown default: return "Permission: unknown"
        }
    }

    private var privacyCard: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Your data stays here", systemImage: "lock.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                Text("Meals, photos, water and preferences stay in memory only and reset when the app closes. Nothing syncs to an account or cloud. Clear this session also removes the Sign in with Apple identifier from this device.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                PandaPlateLegalLinksRow(style: .profile, presentedDocument: $presentedLegalDocument)
                    .padding(.top, 4)
            }
        }
    }

    #if DEBUG
    private var advancedDeveloperDisclosure: some View {
        DisclosureGroup(isExpanded: $showAdvancedDeveloper) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Local scan server")
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .padding(.top, 8)
                Text("Simulator stays on 127.0.0.1. A device on your LAN can use a private address only. The server must stay on loopback unless PANDAPLATE_ALLOW_LAN=1 and a scan token of at least 24 characters are set. Public hosts are rejected.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                TextField("http://127.0.0.1:8787", text: $scanBaseURLDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .padding(12)
                    .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                SecureField("Scan token (leave empty on loopback)", text: $scanTokenDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .padding(12)
                    .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                if let scanURLError {
                    Text(scanURLError)
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.coralInk)
                }
                Button {
                    let trimmed = scanBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        UserDefaults.standard.removeObject(forKey: FoodScanClient.baseURLDefaultsKey)
                        scanBaseURLDraft = FoodScanClient.defaultBaseURL
                        scanURLError = nil
                    } else if FoodScanClient.isPrivateScanBaseURL(trimmed) {
                        UserDefaults.standard.set(trimmed, forKey: FoodScanClient.baseURLDefaultsKey)
                        scanBaseURLDraft = trimmed
                        scanURLError = nil
                    } else {
                        scanURLError = "That address isn’t a loopback or private LAN host, so it wasn’t saved."
                    }
                    let token = scanTokenDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !token.isEmpty {
                        UserDefaults.standard.set(token, forKey: FoodScanClient.scanTokenDefaultsKey)
                        scanTokenDraft = ""
                        scanTokenSaved = true
                    }
                } label: {
                    Text("Save scan server")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PPColor.coralInk, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("Active: \(FoodScanClient.configuredBaseURL.absoluteString). Token: \(scanTokenSaved ? "saved" : "not set"). Leave the token blank to keep the saved one.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                if scanTokenSaved {
                    Button("Remove saved token") {
                        UserDefaults.standard.removeObject(forKey: FoodScanClient.scanTokenDefaultsKey)
                        scanTokenDraft = ""
                        scanTokenSaved = false
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        } label: {
            HStack {
                Text("Advanced / Developer")
                    .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.muted)
                Spacer()
            }
        }
        .padding(14)
        .background(PPColor.card.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .tint(PPColor.coralInk)
    }

    #endif

    private var clearSessionButton: some View {
        Button(role: .destructive) { showResetConfirmation = true } label: {
            Label("Clear this session", systemImage: "trash")
                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Removes this session’s meals, photos, water and choices")
    }

    private func profileInfo(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).foregroundStyle(PPColor.muted)
            Spacer()
            Text(value).foregroundStyle(PPColor.ink).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
    }
}

private struct LogMealSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var entryMode: MealLogMode
    private let initialMode: MealLogMode
    @State private var mealName = "Lunch"
    @State private var foodDescription = ""
    @State private var calories = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var photoLoadID = UUID()

    init(initialMode: MealLogMode) {
        self.initialMode = initialMode
        _entryMode = State(initialValue: initialMode)
    }

    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    private var parsedCalories: Int? {
        let value = calories.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, let number = Int(value), (0...10_000).contains(number) else { return nil }
        return number
    }
    private var caloriesAreValid: Bool {
        let value = calories.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || parsedCalories != nil
    }
    private var descriptionIsValid: Bool {
        foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).count <= 120
    }
    private var canSave: Bool {
        !mealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && caloriesAreValid && descriptionIsValid && !isLoadingPhoto && store.meals.count < AppStore.maximumMealsPerSession
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal entry") {
                    HStack(spacing: 8) {
                        entryModeButton(.manual, title: "Manual", symbol: "square.and.pencil")
                        entryModeButton(.photo, title: "Photo note", symbol: "photo")
                    }
                }
                Section("Meal type") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(mealTypes, id: \.self) { type in
                            let selected = mealName == type
                            Button { mealName = type } label: {
                                Text(type)
                                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(selected ? .white : PPColor.ink)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(selected ? PPColor.coralInk : PPColor.cream, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(type)
                            .accessibilityValue(selected ? "Selected" : "Not selected")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    TextField("Food or meal description, optional", text: $foodDescription)
                        .accessibilityLabel("Food or meal description")
                    if !descriptionIsValid {
                        Text("Keep the description to 120 characters or fewer.")
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                    HStack {
                        Text("Calories, if known")
                        Spacer()
                        TextField("No estimate", text: $calories)
                            .accessibilityLabel("Calories, optional estimate")
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                    if !caloriesAreValid {
                        Text("Enter a whole number from 0 to 10,000, or leave it blank.")
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                    Text("A blank estimate stays unknown; it won’t be counted as zero.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                    if store.meals.count >= AppStore.maximumMealsPerSession {
                        Text("This version holds up to 20 meal entries in a session. Clear the session in Your space before adding another.")
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                }
                Section("Photo note · this session only") {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        Label(imageData == nil ? "Choose a photo" : "Change photo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { _, item in loadPhoto(item) }
                    .accessibilityLabel(imageData == nil ? "Choose a photo" : "Change photo")
                    .accessibilityIdentifier("meal-photo-picker")
                    .accessibilityHint("Selects one photo from your library for this session")

                    if isLoadingPhoto {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Loading and reducing photo size…")
                                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        }
                    }
                    if let photoError {
                        Text(photoError)
                            .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.coralInk)
                    }
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityLabel("Selected meal photo")
                        Button(role: .destructive) { removePhoto() } label: {
                            Label("Remove photo", systemImage: "trash")
                        }
                    }
                    Text("Optional photo note for manual entry. For recognition, use Food Scan instead. This photo isn’t uploaded and clears with the session.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PPColor.cream)
            .navigationTitle(entryMode == .photo ? "Photo note" : "Manual entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(PPColor.coralInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let description = foodDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        let name = description.isEmpty ? mealName : "\(mealName) · \(description)"
                        store.addMeal(name: name, calories: calories.isEmpty ? nil : parsedCalories, imageData: imageData)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .tint(PPColor.coralInk)
                    .disabled(!canSave)
                }
            }
            }
        .tint(PPColor.coralInk)
        .onChange(of: initialMode) { _, mode in entryMode = mode }
        .onAppear {
            // Prefill from USDA favorite — name + optional kcal only. Never invent; never sets consent.
            if let pre = USDAFavoritesStore.shared.consumePendingPrefill() {
                foodDescription = pre.dishName
                if let kcal = pre.calories {
                    calories = String(kcal)
                } else {
                    calories = ""
                }
            }
        }
        .onDisappear { photoLoadTask?.cancel() }
    }

    private func entryModeButton(_ mode: MealLogMode, title: String, symbol: String) -> some View {
        let selected = entryMode == mode
        return Button { entryMode = mode } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(selected ? .white : PPColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? PPColor.coralInk : PPColor.cream, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        photoLoadTask?.cancel()
        photoLoadID = UUID()
        let id = photoLoadID
        photoError = nil
        imageData = nil
        guard let item else { isLoadingPhoto = false; return }
        isLoadingPhoto = true
        photoLoadTask = Task { @MainActor in
            defer { if photoLoadID == id { isLoadingPhoto = false } }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    if photoLoadID == id { photoError = "Couldn’t load that photo. Try another." }
                    return
                }
                guard BoundedPhotoLoader.mayPublishResult(requestID: id, activeID: photoLoadID, isCancelled: Task.isCancelled) else { return }
                guard data.count <= BoundedPhotoLoader.maximumInputBytes else {
                    photoError = "That photo is too large. Choose one under 12 MB."
                    return
                }
                guard let reduced = BoundedPhotoLoader.jpegData(from: data), reduced.count <= 1_000_000 else {
                    photoError = "Couldn’t prepare that photo safely. Try a smaller image."
                    return
                }
                imageData = reduced
            } catch {
                if photoLoadID == id { photoError = "Couldn’t load that photo. Try another." }
            }
        }
    }

    private func removePhoto() {
        photoLoadTask?.cancel()
        photoLoadID = UUID()
        selectedPhoto = nil
        imageData = nil
        photoError = nil
        isLoadingPhoto = false
    }
}

private struct QuickLogSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    /// Food opens camera-first FoodScanSheet directly (gallery still reachable inside that UI).
    let onFoodCamera: () -> Void
    let onWaterTap: () -> Void
    let onWorkout: () -> Void
    let onWeight: () -> Void
    let onFasting: () -> Void

    private struct ActionTile: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let tint: Color
        let fill: Color
    }

    private var tiles: [ActionTile] {
        [
            ActionTile(id: "food", title: "Food", subtitle: "Camera → log", symbol: "camera.fill",
                       tint: Color(red: 0.22, green: 0.55, blue: 0.32),
                       fill: Color(red: 0.82, green: 0.93, blue: 0.84)),
            ActionTile(id: "water", title: "Water", subtitle: "Add a glass", symbol: "drop.fill",
                       tint: Color(red: 0.20, green: 0.48, blue: 0.90),
                       fill: Color(red: 0.82, green: 0.90, blue: 0.98)),
            ActionTile(id: "workout", title: "Workout", subtitle: "Log activity", symbol: "figure.walk",
                       tint: Color(red: 0.36, green: 0.55, blue: 0.28),
                       fill: Color(red: 0.88, green: 0.94, blue: 0.82)),
            ActionTile(id: "weight", title: "Weight", subtitle: "Check in", symbol: "scalemass.fill",
                       tint: Color(red: 0.85, green: 0.40, blue: 0.32),
                       fill: Color(red: 0.98, green: 0.88, blue: 0.84)),
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What would you like to add?")
                        .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.muted)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(tiles) { tile in
                            Button {
                                handle(tile.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Image(systemName: tile.symbol)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(tile.tint)
                                        .frame(width: 44, height: 44)
                                        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    Text(tile.title)
                                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .headline))
                                        .foregroundStyle(PPColor.ink)
                                    Text(tile.subtitle)
                                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                                        .foregroundStyle(PPColor.muted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                .padding(14)
                                .background(tile.fill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tile.title)
                            .accessibilityHint(tile.subtitle)
                        }
                    }

                    // Secondary BitePal-adjacent action
                    Button {
                        dismiss()
                        onFasting()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(red: 0.45, green: 0.38, blue: 0.72))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fasting")
                                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                    .foregroundStyle(PPColor.ink)
                                Text("Optional elapsed-time log")
                                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                                    .foregroundStyle(PPColor.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(PPColor.muted)
                        }
                        .padding(14)
                        .background(Color(red: 0.90, green: 0.88, blue: 0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fasting")

                    Text("Food opens the camera. Workout kcal shows only from Apple Health when synced — otherwise Unknown (blank is not zero).")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
                .padding(18)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(BitePalColor.ctaBlack)
                }
            }
        }
    }

    private func handle(_ id: String) {
        switch id {
        case "food":
            dismiss()
            onFoodCamera()
        case "water":
            dismiss()
            onWaterTap()
        case "workout":
            dismiss()
            onWorkout()
        case "weight":
            dismiss()
            onWeight()
        default:
            break
        }
    }
}

/// Session weight check-in from the BitePal-style + sheet.
private struct WeightLogSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var kilogramsText: String = ""
    @State private var message: String?

    private var parsedKg: Double? {
        let trimmed = kilogramsText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(trimmed), (25...300).contains(value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Weight check-in")
                        .font(.system(size: 24, weight: .bold, design: .rounded, relativeTo: .title2))
                        .foregroundStyle(PPColor.ink)
                    Text("Log today’s weight for this session. Not medical advice.")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)

                    HStack(spacing: 10) {
                        TextField("e.g. 68.5", text: $kilogramsText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold, design: .rounded, relativeTo: .title))
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .accessibilityLabel("Weight in kilograms")
                        Text("kg")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.muted)
                    }
                    .padding(.horizontal, 16)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PPColor.line, lineWidth: 1))

                    if let message {
                        Text(message)
                            .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.coralInk)
                    }

                    Button {
                        guard let kg = parsedKg else {
                            message = "Enter a weight between 25 and 300 kg."
                            return
                        }
                        guard store.addWeight(kilograms: kg) else {
                            message = "Couldn’t save that weight right now."
                            return
                        }
                        dismiss()
                    } label: {
                        Text("Save weight")
                            .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(BitePalColor.ctaBlack, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(parsedKg == nil)
                    .opacity(parsedKg == nil ? 0.45 : 1)

                    if !store.weightLogs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This session")
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(PPColor.ink)
                            ForEach(store.weightLogs.prefix(8)) { entry in
                                HStack {
                                    Text(String(format: "%.1f kg", entry.kilograms))
                                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                    Spacer()
                                    Text(entry.time.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                                        .foregroundStyle(PPColor.muted)
                                }
                                .padding(12)
                                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(BitePalColor.ctaBlack)
                }
            }
            .onAppear {
                if let precise = store.currentWeightKilogramsPrecise {
                    kilogramsText = String(format: "%.1f", precise)
                } else if let kg = store.currentWeightKilograms {
                    kilogramsText = String(kg)
                }
            }
        }
    }
}

private struct LogFastingSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Image("PandaPlateFastingBackground")
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.12))
                    .ignoresSafeArea()
                VStack(spacing: 18) {
                    PipMascot(size: 118, assetName: "PP_PipGentle")
                        .accessibilityLabel("Pip is here with you")
                    Text("Fasting log")
                        .font(.system(size: 27, weight: .black, design: .rounded, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                    Text("A simple optional session record. No target, recommendation, countdown or reminder.")
                        .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    if let started = store.fastingStartedAt {
                        VStack(spacing: 8) {
                            Text("Session started")
                                .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .headline))
                                .foregroundStyle(.white)
                            Text(started.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .body))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Button {
                            guard store.endFasting() else { return }
                            onFinish()
                        } label: {
                            Text("End and save session log")
                                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                .foregroundStyle(PPColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(PPColor.peach, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        Button("Cancel this start") {
                            store.cancelFasting()
                            onFinish()
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(minHeight: 44)
                    } else {
                        Button { store.startFasting() } label: {
                            Text("Start session log")
                                .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .headline))
                                .foregroundStyle(PPColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 50)
                                .background(PPColor.peach, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Text("You can end or cancel it any time. It clears when the app closes.")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 0)
                }
                .padding(22)
                .padding(.top, 14)
            }
            .navigationTitle("Fasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.tint(.white) }
            }
        }
        .preferredColorScheme(.dark)
    }
}
