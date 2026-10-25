import SwiftUI
import PhotosUI
import StoreKit
import UIKit

private enum RootTab: Hashable {
    case home, pip, progress, profile
}

private enum MealLogMode: Equatable {
    case scan
    case manual
    case photo
}

private enum RootSheet: Identifiable {
    case quickLog
    case log(MealLogMode)
    case settings
    case workout
    case fasting

    var id: String {
        switch self {
        case .quickLog: return "quick-log"
        case .log(.scan): return "log-scan"
        case .log(.photo): return "log-photo"
        case .log(.manual): return "log-manual"
        case .settings: return "settings"
        case .workout: return "workout"
        case .fasting: return "fasting"
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
    @State private var statsShowsHistory = false
    /// Soft paywall after first success — dismissible; never required for Free.
    @State private var showSoftWall = false

    var body: some View {
        Group {
            switch tab {
            case .home:
                TodayDashboard(
                    onQuickLogTap: { activeSheet = .quickLog },
                    onScanTap: { openMealLog(.scan) },
                    onManualTap: { openMealLog(.manual) }
                )
            case .pip:
                PipWorldDashboard(onQuickLogTap: { activeSheet = .quickLog }).environmentObject(store)
            case .progress:
                ProgressDashboard(showingHistory: statsShowsHistory).id(statsShowsHistory).environmentObject(store)
            case .profile:
                ProfileView().environmentObject(store)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .background(PPColor.cream.ignoresSafeArea())
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .quickLog:
                QuickLogSheet(onAddFood: { mode in
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { openMealLog(mode) }
                }, onWorkout: {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .workout }
                }, onFasting: {
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { activeSheet = .fasting }
                })
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .log(let mode):
                Group {
                    if mode == .scan {
                        FoodScanSheet()
                            .environmentObject(store)
                    } else {
                        LogMealSheet(initialMode: mode)
                            .environmentObject(store)
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            case .settings:
                ProfileView()
                .environmentObject(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .workout:
                WorkoutPickerLogView(workouts: $store.workouts, onFinish: {
                    activeSheet = nil
                    statsShowsHistory = true
                    tab = .progress
                })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .fasting:
                FastingLogView(onFinish: {
                    activeSheet = nil
                    statsShowsHistory = true
                    tab = .progress
                })
                    .environmentObject(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        // Soft wall: only when no other sheet is up (never cold-launch, never quota Unlock path).
        .sheet(isPresented: $showSoftWall, onDismiss: {
            firstSuccess.markSoftWallDismissed()
        }) {
            PremiumPaywallView()
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
        activeSheet = .log(mode)
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(.home, title: "Home", symbol: "house.fill")
            tabButton(.pip, title: "Pip", symbol: "pawprint.fill")
            Button { activeSheet = .quickLog } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(PPColor.coralInk, in: Circle())
                    .contentShape(Circle())
                    .offset(y: -10)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Quick actions")
            .accessibilityHint("Opens Food Scan, manual meal entry, water, workout and fasting logs")
            tabButton(.progress, title: "Progress", symbol: "chart.bar.fill")
            tabButton(.profile, title: "You", symbol: "person.fill")
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(PPColor.cream.opacity(0.97).shadow(color: .black.opacity(0.05), radius: 8, y: -3))
    }

    private func tabButton(_ item: RootTab, title: String, symbol: String) -> some View {
        Button {
            if item == .progress { statsShowsHistory = false }
            tab = item
        } label: {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(title).font(.system(size: 10, weight: .semibold, design: .rounded, relativeTo: .caption2))
                }
            }
            .foregroundStyle(tab == item ? PPColor.coralInk : PPColor.muted)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(tab == item ? PPColor.peach.opacity(0.72) : .clear, in: Capsule())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(tab == item ? "Selected" : "Not selected")
        .accessibilityAddTraits(tab == item ? .isSelected : [])
    }
}

private struct TodayDashboard: View {
        @EnvironmentObject private var store: AppStore
        let onQuickLogTap: () -> Void
    let onScanTap: () -> Void
    let onManualTap: () -> Void

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 17) {
                    topBar
                    sessionSummary
                    waterLog
                    nutritionCard
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
        .background(PPColor.cream.ignoresSafeArea())
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
            Text("Visit Pip")
                .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.coralInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PPColor.peach.opacity(0.7), in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private var sessionSummary: some View {
        HStack(spacing: 9) {
            sessionSummaryItem("Meals", value: "\(store.meals.count) this session", symbol: "fork.knife")
            sessionSummaryItem("Water", value: "\(store.waterML) ml this session", symbol: "drop.fill")
        }
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
                quickAction("Food Scan", symbol: "camera.viewfinder", detail: "Camera or library → identify → edit & save", action: onScanTap)
                quickAction("Quick log", symbol: "plus.circle.fill", detail: "Scan, manual, water, workout or fasting", action: onQuickLogTap)
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

    private var dateStrip: some View {
        HStack(spacing: 0) {
            ForEach(currentWeek, id: \.self) { date in
                let isToday = Calendar.current.isDateInToday(date)
                VStack(spacing: 8) {
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                    Text(date.formatted(.dateTime.day()))
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(isToday ? .white : PPColor.ink)
                        .frame(width: 31, height: 31)
                        .background(isToday ? PPColor.coralInk : Color.clear, in: Circle())
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 11)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week. Today is highlighted.")
    }

    private var currentWeek: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var nutritionCard: some View {
        PPCard(padding: 17) {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SESSION NUTRITION")
                            .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                            .tracking(1.1).foregroundStyle(PPColor.muted)
                        Text("What’s been logged")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body)).foregroundStyle(PPColor.ink)
                    }
                    Spacer()
                    Text("SESSION ONLY")
                        .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(PPColor.muted)
                }
                Text(store.caloriesEaten.map { "\($0) kcal with an estimate" } ?? "No calorie estimates yet")
                    .font(.system(size: 24, weight: .black, design: .rounded, relativeTo: .title2))
                    .foregroundStyle(PPColor.ink)
                Text("Only saved meals with an estimate are included; unknown calories stay unknown.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)

                HStack(spacing: 8) {
                    nutritionChip("Sample protein", "63 g", color: PPColor.coral)
                    nutritionChip("Sample carbs", "158 g", color: Color(red: 0.43, green: 0.66, blue: 0.48))
                    nutritionChip("Sample fat", "42 g", color: Color(red: 0.64, green: 0.55, blue: 0.77))
                }
                Text("Sample macros are illustrative only—not measured from your meals, personalized guidance or medical advice.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
            }
        }
    }

    private var waterLog: some View {
        WaterQuickLogView(
            waterML: Binding(
                get: { store.waterML },
                set: { store.waterML = WaterQuickLogModel.cappedTotal($0) }
            )
        )
    }

    @ViewBuilder private var mealsSection: some View {
        if store.meals.isEmpty {
            PPCard {
                HStack {
                    Image(systemName: "fork.knife.circle.fill").font(.system(size: 28)).foregroundStyle(PPColor.coral)
                    VStack(alignment: .leading) {
                        Text("Your first meal goes here").font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        Text("Tap + to add a meal").font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                    }
                }
            }
        } else {
            VStack(spacing: 9) {
                ForEach(store.meals) { meal in
                    HStack(spacing: 12) {
                        if let data = meal.imageData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        } else {
                            RoundedRectangle(cornerRadius: 13).fill(PPColor.peach).frame(width: 48, height: 48)
                                .overlay(Image(systemName: "fork.knife").foregroundStyle(PPColor.coral))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meal.name).font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                            Text(meal.time.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                        }
                        Spacer()
                        Text(meal.calories.map { "\($0) kcal" } ?? "No estimate")
                            .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                    }
                    .padding(11)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 17))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { store.removeMeal(id: meal.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .accessibilityAction(named: "Delete meal") { store.removeMeal(id: meal.id) }
                }
            }
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let greetings = [
        "Hey — Pip’s here.",
        "What sounds good right now?",
        "No rush. One small step.",
    ]

    private enum RitualPhase: Equatable {
        case welcome
        case saidHi
        case napping
    }

    @State private var greetingIndex = 0
    @State private var phase: RitualPhase = .welcome
    @State private var celebrateLove = false

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

    private var heroAssetName: String {
        switch phase {
        case .welcome:
            return "PP_PipWelcome"
        case .saidHi:
            return celebrateLove ? "PP_PipLove" : "PP_PipCelebrate"
        case .napping:
            return "PP_PipRest"
        }
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pip’s little world")
                    .font(.system(size: 28, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)

                ZStack(alignment: .bottom) {
                    Image("PP_GardenBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .clipped()
                        .accessibilityHidden(true)

                    VStack(spacing: 10) {
                        ritualHero
                        Text(captionLine)
                            .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(PPColor.card.opacity(0.92), in: Capsule())
                            .padding(.bottom, 14)
                            .accessibilityLabel(captionLine)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PPColor.line.opacity(0.6), lineWidth: 1)
                )

                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("A soft hello")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.ink)
                        Text("No scores, no grades, no macros — just \(companionDisplayName) when you want company.")
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

                Text("Free ritual · no Premium gate · visit at your own pace.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 12)
            }
            .padding(18)
        }
        .background(PPColor.cream.ignoresSafeArea())
        .onAppear(perform: rotateGreetingOnAppear)
    }

    @ViewBuilder
    private var ritualHero: some View {
        // Reduce Motion → static Image, no bounce. Motion path uses soft static/frame beat only.
        if reduceMotion {
            Image(heroAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .accessibilityLabel("\(companionDisplayName) in the forest garden")
        } else if phase == .welcome {
            PipReactionBeat(
                assetNames: ["PP_PipWelcome"],
                label: "\(companionDisplayName) waves hello in the forest garden",
                size: 200
            )
        } else if phase == .saidHi {
            PipReactionBeat(
                assetNames: celebrateLove ? ["PP_PipLove"] : ["PP_PipCelebrate"],
                label: "\(companionDisplayName) is glad you showed up",
                size: 200
            )
        } else {
            Image("PP_PipRest")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .accessibilityLabel("\(companionDisplayName) is napping")
        }
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
    private let days = [("M", 0.58), ("T", 0.81), ("W", 0.43), ("T", 0.9), ("F", 0.73), ("S", 0.28), ("S", 0.15)]

    init(showingHistory: Bool) {
        _selectedSection = State(initialValue: showingHistory ? .history : .progress)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                Text("Progress")
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
        VStack(alignment: .leading, spacing: 15) {
            Text("Illustrative sample charts · no personal trend is calculated")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
            PPCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Consistency, not perfection · sample", systemImage: "leaf.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(Color(red: 0.34, green: 0.56, blue: 0.36))
                    Text("5 of 7 days · example only").font(.system(size: 20, weight: .black, design: .rounded, relativeTo: .title2)).foregroundStyle(PPColor.ink)
                    HStack(alignment: .bottom, spacing: 11) {
                        ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                            VStack(spacing: 6) {
                                Capsule().fill(day.1 > 0.55 ? PPColor.coral : PPColor.peach).frame(height: 72 * day.1 + 8)
                                Text(day.0).font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 100, alignment: .bottom)
                }
            }
            PPCard {
                VStack(alignment: .leading, spacing: 13) {
                    Label("Sample weight trend", systemImage: "chart.xyaxis.line")
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.muted)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("65.0 kg").font(.system(size: 24, weight: .black, design: .rounded, relativeTo: .title2)).foregroundStyle(PPColor.ink)
                        Text("Illustrative only").font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.coralInk)
                    }
                    Sparkline(values: [0.55, 0.49, 0.58, 0.46, 0.51, 0.43, 0.48])
                        .stroke(Color(red: 0.56, green: 0.48, blue: 0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(height: 74)
                        .padding(.horizontal, 2)
                }
            }
            HStack(spacing: 10) {
                smallProgress(title: "Sample water", value: "4 days", symbol: "drop.fill", tint: .blue)
                smallProgress(title: "Sample movement", value: "150 min", symbol: "figure.walk", tint: Color(red: 0.36, green: 0.63, blue: 0.41))
            }
            PPCard {
                HStack(spacing: 13) {
                    Image("PandaPlateFeedbackReader")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 58, height: 58)
                        .accessibilityHidden(true)
                    Text("Example values only. No real activity, weight, or health trend is saved.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                }
            }
        }
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

    private func smallProgress(title: String, value: String, symbol: String, tint: Color) -> some View {
        PPCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                Text(value).font(.system(size: 14, weight: .black, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.ink)
            }
        }
    }
}

private struct Sparkline: Shape {
    let values: [CGFloat]
    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        var path = Path()
        for (index, value) in values.enumerated() {
            let point = CGPoint(x: rect.width * CGFloat(index) / CGFloat(values.count - 1), y: rect.height * (1 - value))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var quota = ScanQuotaStore.shared
    @ObservedObject private var premium = PremiumAccess.shared
    @ObservedObject private var favorites = USDAFavoritesStore.shared
    @State private var showResetConfirmation = false
    @State private var showPaywall = false
    @State private var prefillNotice: String?
    @State private var showSoftShowUpHistory = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Text("Settings")
                        .font(.system(size: 27, weight: .black, design: .rounded, relativeTo: .largeTitle)).foregroundStyle(PPColor.ink)
                    Spacer()
                    PipMascot(size: 55)
                    Button("Close") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                        .frame(minWidth: 54, minHeight: 44)
                        .contentShape(Rectangle())
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FOOD SCANS").font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2)).tracking(1).foregroundStyle(PPColor.muted)
                        Text(quota.quotaSummaryLine)
                            .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                        Text("Free: 3 Food Scans/day + core logging. Premium: \(PremiumAccess.monthlyPriceDisplay) or \(PremiumAccess.yearlyPriceDisplay) — unlimited scans & Pip extras.")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                        Button { showPaywall = true } label: {
                            Text(premium.isPremium ? "Premium benefits" : "Unlock Premium · \(PremiumAccess.monthlyPriceDisplay)")
                                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(PPColor.coralInk, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Toggle("Debug: Premium unlocked", isOn: Binding(
                            get: { premium.isPremium },
                            set: { premium.isPremium = $0 }
                        ))
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .tint(PPColor.coral)
                    }
                }
                .sheet(isPresented: $showPaywall) {
                    PremiumPaywallView()
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SESSION EXPORT").font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2)).tracking(1).foregroundStyle(PPColor.muted)
                        SessionCSVExportButton(
                            entries: WeekLogExport.rows(from: store),
                            isPremium: premium.isPremium,
                            onFreeTap: { showPaywall = true }
                        )
                    }
                }
                PPCard {
                    SoftShowUpPresenceCard(
                        isPremium: premium.isPremium,
                        onOpenHistory: { showSoftShowUpHistory = true },
                        onFreeTap: { showPaywall = true }
                    )
                }
                .sheet(isPresented: $showSoftShowUpHistory) {
                    SoftShowUpHistoryView()
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PINNED USDA").font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2)).tracking(1).foregroundStyle(PPColor.muted)
                        Text("Pins store FDC id + name only. Calories stay blank unless already known. Picking a pin never skips scan consent.")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
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
                PPCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ABOUT YOU").font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2)).tracking(1).foregroundStyle(PPColor.muted)
                        profileInfo("Your name", value: store.userName.isEmpty ? "Not set" : store.userName)
                        profileInfo("Pet name", value: store.companionName)
                        profileInfo("Focus", value: store.goal.rawValue)
                        profileInfo("Pip’s style", value: store.pipStyle.rawValue)
                        profileInfo("Meals per day", value: "\(store.mealsPerDay)")
                        profileInfo("Eating settings", value: store.mealPlaces.isEmpty ? "No preference selected" : store.mealPlaces.sorted().joined(separator: ", "))
                        if !store.supportFocus.isEmpty {
                            profileInfo("Extra support", value: store.supportFocus.sorted().joined(separator: ", "))
                        }
                    }
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Reminders")
                            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                        Text("Reminder scheduling isn’t available in this prototype.")
                            .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                    }
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Units").font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        Text("Metric units only in this demo. Unit switching isn’t available yet.")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    }
                }
                PPCard {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("Your data stays here", systemImage: "lock.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                        Text("Meals, photos, water and preferences stay in memory only and reset when the app closes. Nothing syncs to an account or cloud.")
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                    }
                }
                Button(role: .destructive) { showResetConfirmation = true } label: {
                    Label("Clear demo session", systemImage: "trash")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Removes this session’s meals, photos, water and choices")
                Text("PandaPlate · early prototype\nWellness support, not medical advice.")
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
            }
            .padding(18)
            .padding(.bottom, 18)
        }
        .background(PPColor.cream)
        .confirmationDialog("Clear this demo session?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Clear session", role: .destructive) { store.resetDemoSession() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes meals, photos, water and choices held in memory for this session.")
        }
    }

    private func profileInfo(_ title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(PPColor.muted)
            Spacer()
            Text(value).foregroundStyle(PPColor.ink).multilineTextAlignment(.trailing)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
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
                        Text("This demo holds up to 20 meal entries. Clear the session in Your space before adding another.")
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
    @State private var selected: String?
    let onAddFood: (MealLogMode) -> Void
    let onWorkout: () -> Void
    let onFasting: () -> Void

    private let options: [(String, String, String, Bool)] = [
        ("Food Scan", "Camera or library → Pip helps identify → you edit & save", "camera.viewfinder", true),
        ("Manual entry", "Add a meal by hand", "square.and.pencil", true),
        ("Water", "Add one 250 ml cup", "drop.fill", true),
        ("Workout", "Log an activity", "figure.walk", true),
        ("Fasting", "Optional elapsed-time log", "moon.stars.fill", true),
        ("Weight", "Unavailable in this prototype", "scalemass", false)
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 15) {
                    Text("What would you like to add?")
                        .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline)).foregroundStyle(PPColor.muted)
                    Text("Food Scan is the main path. Manual entry stays available when you prefer to type.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(options, id: \.0) { option in
                            Button {
                                guard option.3 else { return }
                                selected = option.0
                                if option.0 == "Food Scan" || option.0 == "Manual entry" {
                                    let mode: MealLogMode = option.0 == "Food Scan" ? .scan : .manual
                                    dismiss()
                                    onAddFood(mode)
                                } else if option.0 == "Workout" {
                                    dismiss()
                                    onWorkout()
                                } else if option.0 == "Fasting" {
                                    dismiss()
                                    onFasting()
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    Image(systemName: option.2).font(.system(size: 18, weight: .semibold)).foregroundStyle(option.3 ? PPColor.coralInk : PPColor.muted)
                                    Text(option.0).font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption)).foregroundStyle(PPColor.ink)
                                    Text(option.1).font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                                }
                                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                .padding(12)
                                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected == option.0 ? PPColor.coral : PPColor.line, lineWidth: selected == option.0 ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(!option.3)
                            .opacity(option.3 ? 1 : 0.72)
                            .accessibilityLabel(option.0)
                            .accessibilityValue(option.3 ? "Available" : "Not available in this prototype")
                        }
                    }
                    if selected == "Water" {
                        WaterQuickLogView(
                            waterML: Binding(
                                get: { store.waterML },
                                set: { store.waterML = min(4_000, max(0, $0)) }
                            )
                        )
                    }
                    Text("Workout and fasting logs stay in this session until the app closes. They don’t set goals or calculate calories.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2)).foregroundStyle(PPColor.muted)
                }
                .padding(18)
            }
            .background(PPColor.cream)
            .navigationTitle("Quick log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(PPColor.coral)
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
