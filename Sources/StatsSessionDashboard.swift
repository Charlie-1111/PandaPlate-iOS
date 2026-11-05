import SwiftUI

struct ProgressDashboard: View {
    private enum Section: String, CaseIterable {
        case progress = "Overview"
        case history = "History"
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var store: AppStore
    @ObservedObject private var premium = PremiumAccess.shared
    @State private var selectedSection: Section
    @State private var showPaywall = false
    @State private var exportError: String?
    @State private var showSoftShowUpHistory = false
    @State private var showMoreSessionDetails = false

    let onOpenQuickLog: () -> Void

    init(showingHistory: Bool, onOpenQuickLog: @escaping () -> Void = {}) {
        _selectedSection = State(initialValue: showingHistory ? .history : .progress)
        self.onOpenQuickLog = onOpenQuickLog
    }

    private var sessionIsEmpty: Bool {
        store.meals.isEmpty && store.waterML == 0 && store.workouts.isEmpty
            && store.weightLogs.isEmpty && store.fastingEntries.isEmpty && store.fastingStartedAt == nil
    }

    private var gridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }
        return [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 17) {
                Text("Progress")
                    .font(.system(size: 27, weight: .black, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
                sectionPicker
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

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(Section.allCases, id: \.self) { section in
                let isSelected = selectedSection == section
                Button { selectedSection = section } label: {
                    Text(section.rawValue)
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(isSelected ? .white : PPColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? PPColor.accentCoral : PPColor.card, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(section.rawValue)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var progressContent: some View {
        let mealsWithCalories = store.meals.filter { $0.calories != nil }.count
        let mealsWithoutCalories = store.meals.count - mealsWithCalories
        let movementMinutes = store.workouts.reduce(0) { $0 + $1.durationMinutes }
        let workoutCalories = store.workouts.compactMap(\.activeEnergyKcal).reduce(0, +)
        let latestWeight = store.weightLogs.max { $0.time < $1.time }
        let fastingSeconds = store.fastingEntries.reduce(0) { $0 + $1.durationSeconds }

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your session so far")
                    .font(.system(size: 22, weight: .black, design: .rounded, relativeTo: .title2))
                    .foregroundStyle(PPColor.ink)
                    .accessibilityIdentifier("stats-session-so-far")
                Text("Session-only recap · clears when you close the app. No targets, scores, or trends.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if sessionIsEmpty {
                statsEmptyState
            }

            LazyVGrid(columns: gridColumns, spacing: 10) {
                recapTile(
                    title: "Plates logged",
                    value: "\(store.meals.count)",
                    footnote: store.meals.isEmpty ? "None yet" : "\(mealsWithCalories) with estimate · \(mealsWithoutCalories) unknown",
                    symbol: "fork.knife",
                    tint: PPColor.accentCoral
                )
                recapTile(
                    title: "Water",
                    value: store.waterML > 0 ? "\(store.waterML.formatted()) ml" : "—",
                    footnote: store.waterML > 0 ? "Session total" : "Optional",
                    symbol: "drop.fill",
                    tint: PPColor.softBlue
                )
                recapTile(
                    title: "Movement",
                    value: store.workouts.isEmpty ? "—" : "\(movementMinutes) min",
                    footnote: store.workouts.isEmpty ? "Optional" : "\(store.workouts.count) logged",
                    symbol: "figure.walk",
                    tint: PPColor.sage
                )
                .gridCellColumns(gridColumns.count)
            }

            DisclosureGroup(isExpanded: $showMoreSessionDetails) {
                VStack(spacing: 10) {
                    moreRow(
                        title: "Saved calorie estimates",
                        value: premiumCalorieSummary,
                        detail: premiumCalorieDetail,
                        locked: !premium.isPremium
                    )
                    moreRow(
                        title: "Weight check-ins",
                        value: "\(store.weightLogs.count)",
                        detail: latestWeight.map {
                            "Latest \(String(format: "%.1f", $0.kilograms)) kg · \($0.time.formatted(date: .abbreviated, time: .shortened))"
                        } ?? "None this session",
                        locked: false
                    )
                    moreRow(
                        title: "Fasting logs",
                        value: "\(store.fastingEntries.count)",
                        detail: fastingSeconds > 0
                            ? "Recorded \(fastingSeconds / 3_600)h \((fastingSeconds % 3_600) / 60)m total"
                            : "None completed this session",
                        locked: false
                    )
                    if workoutCalories > 0 {
                        moreRow(
                            title: "Movement energy (Health)",
                            value: "\(workoutCalories.formatted()) kcal",
                            detail: "From Apple Health for session workouts only — not a goal.",
                            locked: false
                        )
                    }
                }
                .padding(.top, 8)
            } label: {
                Text("More this session")
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
            }
            .accessibilityIdentifier("stats-more-this-session")
        }
    }

    private var premiumCalorieSummary: String {
        if !premium.isPremium { return "Premium" }
        return store.caloriesEaten.map { "\($0.formatted()) kcal" } ?? "Unknown"
    }

    private var premiumCalorieDetail: String {
        if !premium.isPremium {
            return "Optional Premium unlock for session calorie snapshot detail on Home and here."
        }
        if store.caloriesEaten == nil {
            return "Unknown until a meal stores an estimate — never counted as zero."
        }
        return "Sum of saved estimates only; no target calculated."
    }

    private var statsEmptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                PipMascot(size: 40)
                    .accessibilityLabel("Pip, calm coach")
                Text(PipCoachCopy.emptyHome(store: store))
                    .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Nothing logged yet this session.")
                .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.ink)
            Text("When you add a meal, water, or movement, a calm recap will show up here.")
                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
            Button(action: onOpenQuickLog) {
                Label("Open quick log", systemImage: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(PPColor.accentCoral, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stats-empty-open-quick-log")
        }
        .padding(16)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recapTile(title: String, value: String, footnote: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PPColor.forestDeep)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded, relativeTo: .title2))
                .foregroundStyle(PPColor.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(footnote)
                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(PPColor.line.opacity(0.65), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("stats-tile-\(title.lowercased())")
    }

    private func moreRow(title: String, value: String, detail: String, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if locked {
                Button { showPaywall = true } label: {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(PPColor.forestDeep)
                        .frame(width: 44, height: 44)
                        .background(PPColor.sage.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Unlock session nutrition snapshot with optional Premium")
            }
        }
        .padding(12)
        .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Session history · newest first · clears when the app closes")
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)

            if !store.meals.isEmpty {
                Text(PipCoachCopy.historyPlatesHeader(count: store.meals.count))
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                    .accessibilityAddTraits(.isHeader)
                ForEach(store.meals.reversed()) { meal in
                    PlateStoryCard(meal: meal)
                }
            }

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

            if sessionIsEmpty {
                statsEmptyState
            }

            if store.waterML > 0 {
                Text("Water this session: \(store.waterML.formatted()) ml total. Individual cup times aren’t stored — this isn’t a timestamped log row.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("stats-history-water-note")
            }

            ForEach(chronologicalHistoryRows) { row in
                historyRow(row)
            }
        }
    }

    private struct HistoryRow: Identifiable {
        let id: String
        let title: String
        let time: Date
        let trailing: String
        let symbol: String
    }

    private var chronologicalHistoryRows: [HistoryRow] {
        var rows: [HistoryRow] = []
        for meal in store.meals {
            rows.append(HistoryRow(
                id: "meal-\(meal.id.uuidString)",
                title: "Meal · \(meal.name)",
                time: meal.time,
                trailing: meal.calories.map { "\($0) kcal" } ?? "Unknown",
                symbol: "fork.knife"
            ))
        }
        for workout in store.workouts {
            rows.append(HistoryRow(
                id: "workout-\(workout.id.uuidString)",
                title: "Workout · \(workout.activity) · \(workout.durationMinutes) min",
                time: workout.time,
                trailing: workout.activeEnergyKcal.map { "\($0) kcal" } ?? "—",
                symbol: "figure.walk"
            ))
        }
        for entry in store.fastingEntries {
            let durationText = entry.durationSeconds < 60
                ? "under 1 min"
                : "\(entry.durationSeconds / 3_600)h \((entry.durationSeconds % 3_600) / 60)m"
            rows.append(HistoryRow(
                id: "fast-\(entry.id.uuidString)",
                title: "Fasting log · \(durationText)",
                time: entry.endedAt,
                trailing: "Completed",
                symbol: "moon.stars.fill"
            ))
        }
        if let started = store.fastingStartedAt {
            rows.append(HistoryRow(
                id: "fast-active",
                title: "Fasting session started",
                time: started,
                trailing: "In progress",
                symbol: "moon.stars.fill"
            ))
        }
        for weight in store.weightLogs {
            rows.append(HistoryRow(
                id: "weight-\(weight.id.uuidString)",
                title: "Weight · \(String(format: "%.1f", weight.kilograms)) kg",
                time: weight.time,
                trailing: "Check-in",
                symbol: "scalemass.fill"
            ))
        }
        return rows.sorted { $0.time > $1.time }
    }

    private func historyRow(_ row: HistoryRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PPColor.forestDeep)
                .frame(width: 28)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.time.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer(minLength: 0)
            Text(row.trailing)
                .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
        .padding(13)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
