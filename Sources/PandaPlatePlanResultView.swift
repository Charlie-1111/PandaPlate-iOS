import SwiftUI

/// Presents the session-only routine plan. Edits live only in this view's local state.
struct PandaPlatePlanResultView: View {
    let plan: PandaPlatePlan
    let onFinish: () -> Void
    let onUpgrade: () -> Void

    @ObservedObject private var premiumAccess = PremiumAccess.shared
    @State private var freeDays: [PandaPlatePlanDay]
    @State private var premiumWeeks: [PandaPlatePlanWeek]

    init(plan: PandaPlatePlan, onFinish: @escaping () -> Void, onUpgrade: @escaping () -> Void) {
        self.plan = plan
        self.onFinish = onFinish
        self.onUpgrade = onUpgrade
        _freeDays = State(initialValue: plan.days)
        _premiumWeeks = State(initialValue: plan.premiumWeeks)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PPSpacing.large) {
                VStack(alignment: .leading, spacing: PPSpacing.small) {
                    Eyebrow(text: "Your routine")
                    Text("A flexible 7-day start")
                        .font(PPType.display(30))
                        .foregroundStyle(PPColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your choices shape the rhythm. Edit, skip, or reset any step; changes stay in this screen for this session.")
                        .font(PPType.body(15))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                let boundaryDetails = [plan.safetyNote, plan.bodyNeutralEmphasis].compactMap { $0 }
                noteCard(title: "A gentle boundary", detail: boundaryDetails.joined(separator: " "), symbol: "hand.raised.fill")

                PPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Your focus", systemImage: "leaf.fill")
                            .font(PPType.title())
                            .foregroundStyle(PPColor.forestDeep)
                        Text(plan.weeklyFocus)
                            .font(PPType.body(16, weight: .semibold))
                            .foregroundStyle(PPColor.ink)
                        Text(plan.supportLine)
                            .font(PPType.body(14))
                            .foregroundStyle(PPColor.muted)
                    }
                }

                preferenceSummary

                VStack(alignment: .leading, spacing: PPSpacing.medium) {
                    SectionTitle(title: "Free · 7-day routine")
                    ForEach(freeDays.indices, id: \.self) { index in
                        dayCard(at: index)
                    }
                }

                // Premium visibility depends only on the existing effective entitlement.
                if premiumAccess.isPremium {
                    premiumLayer
                } else {
                    premiumLockedCard
                }

                Text("Built offline from the answers you chose. It makes no food suggestions and calculates no calories, macros, BMI, weight direction, projections, or health outcome.")
                    .font(PPType.caption(12))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
            .padding(PPSpacing.pageInset)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: onFinish) {
                Text("Finish plan & continue")
                    .font(PPType.body(16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 680, minHeight: 54)
                    .background(PPColor.accentCoral, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("planResultFinish")
            .padding(.horizontal, PPSpacing.pageInset)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(PPColor.cream)
        }
        .background(PPColor.cream.ignoresSafeArea())
        .tint(PPColor.forest)
    }

    private var preferenceSummary: some View {
        PPCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Your choices")
                summaryRow("Main focus", plan.context.mainFocus)
                summaryRow("Logging", plan.context.loggingFamiliarity)
                if let meals = plan.context.mealsPerDay {
                    summaryRow("Usual meals", "\(meals) per day")
                }
                let periods = [
                    plan.context.firstMealPeriod.map { "First meal · \($0)" },
                    plan.context.lastMealPeriod.map { "Last meal · \($0)" }
                ].compactMap { $0 }
                if !periods.isEmpty { summaryRow("Meal periods", periods.joined(separator: "  ·  ")) }
                if !plan.context.additionalGoals.isEmpty {
                    summaryRow("Extra focus", plan.context.additionalGoals.joined(separator: ", "))
                }
                if !plan.context.eatingLocations.isEmpty {
                    summaryRow("Usual places", plan.context.eatingLocations.joined(separator: ", "))
                }
                if let diet = plan.context.dietPreference { summaryRow("Food preference", diet) }
                if !plan.context.foodRestrictions.isEmpty {
                    summaryRow("Foods to avoid", plan.context.foodRestrictions.joined(separator: ", "))
                }
                if !plan.context.habitChanges.isEmpty {
                    summaryRow("Chosen habits", plan.context.habitChanges.joined(separator: ", "))
                }
                if let familiarity = plan.context.fastingFamiliarity {
                    summaryRow("Fasting familiarity", familiarity)
                }
                if let fasting = plan.context.fastingSchedulePreference {
                    summaryRow("Fasting", fasting)
                }
                if let water = plan.context.waterAdequacy { summaryRow("Water", water) }
                if let weekend = plan.context.weekendEating { summaryRow("Weekends", weekend) }
                if let cravings = plan.context.cravingsFrequency { summaryRow("Cravings", cravings) }
                if let activity = plan.context.activityLevel { summaryRow("Movement", activity) }
                summaryRow("Pip’s style", plan.context.pipStyle)
                if let reminder = plan.context.reminderPreference {
                    summaryRow("Reminder preference", reminder)
                }
                Text("Preferences are context only. No food or recipe recommendations are generated.")
                    .font(PPType.caption(12))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
    }

    private func dayCard(at index: Int) -> some View {
        let day = freeDays[index]
        return PPCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(day.dayNumber)")
                        .font(PPType.body(15, weight: .bold))
                        .foregroundStyle(PPColor.forestDeep)
                        .frame(width: 38, height: 38)
                        .background(PPColor.selectedWash, in: Circle())
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.title)
                            .font(PPType.body(16, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                        Text(day.detail)
                            .font(PPType.body(14))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Toggle(isOn: $freeDays[index].isComplete) {
                    Text("Done for now")
                        .font(PPType.caption(13))
                        .foregroundStyle(PPColor.muted)
                }
                .tint(PPColor.forest)
                .accessibilityHint("Marks this optional routine note complete in this session")
            }
        }
    }

    private var premiumLayer: some View {
        VStack(alignment: .leading, spacing: PPSpacing.medium) {
            SectionTitle(title: "Premium · 4-week layer")
            Text("A separate, editable set of weekly check-ins. Your free 7-day routine remains available either way.")
                .font(PPType.body(14))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(premiumWeeks.indices, id: \.self) { weekIndex in
                weekCard(at: weekIndex)
            }
        }
    }

    private func weekCard(at index: Int) -> some View {
        let week = premiumWeeks[index]
        return PPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Week \(week.weekNumber)")
                        .font(PPType.caption(12, weight: .bold))
                        .foregroundStyle(PPColor.forestDeep)
                    Spacer(minLength: 8)
                    Text(week.title)
                        .font(PPType.body(16, weight: .bold))
                        .foregroundStyle(PPColor.ink)
                        .multilineTextAlignment(.trailing)
                }

                Text(week.checkInPrompt)
                    .font(PPType.body(15, weight: .semibold))
                    .foregroundStyle(PPColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(week.tasks.indices, id: \.self) { taskIndex in
                    Toggle(isOn: $premiumWeeks[index].tasks[taskIndex].isComplete) {
                        Text(week.tasks[taskIndex].title)
                            .font(PPType.body(14))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .tint(PPColor.forest)
                }

                TextField("Your note for this week (optional)", text: $premiumWeeks[index].reflection, axis: .vertical)
                    .font(PPType.body(14))
                    .lineLimit(2...5)
                    .padding(12)
                    .background(PPColor.softBlue.opacity(0.65), in: RoundedRectangle(cornerRadius: PPRadius.icon, style: .continuous))
                    .accessibilityLabel("Optional note for week \(week.weekNumber)")
            }
        }
    }

    private var premiumLockedCard: some View {
        PPCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(PPColor.forestDeep)
                        .frame(width: 42, height: 42)
                        .background(PPColor.softBlue, in: RoundedRectangle(cornerRadius: PPRadius.icon, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Premium · 4-week layer")
                            .font(PPType.body(16, weight: .bold))
                            .foregroundStyle(PPColor.ink)
                        Text("Four editable weekly check-ins are included with Premium. Your 7-day routine is here either way.")
                            .font(PPType.body(14))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(action: onUpgrade) {
                    Label("See Premium options", systemImage: "sparkles")
                        .font(PPType.body(14, weight: .bold))
                        .foregroundStyle(PPColor.forestDeep)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(PPColor.softBlue, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("planResultUpgrade")
                .accessibilityHint("Opens the existing optional Premium screen. The free 7-day routine remains available.")
            }
        }
    }

    private func noteCard(title: String, detail: String, symbol: String) -> some View {
        PPCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(PPColor.forestDeep)
                    .frame(width: 42, height: 42)
                    .background(PPColor.softBlue, in: RoundedRectangle(cornerRadius: PPRadius.icon, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(PPType.body(15, weight: .bold))
                        .foregroundStyle(PPColor.ink)
                    Text(detail)
                        .font(PPType.body(13))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(PPType.caption(11, weight: .semibold))
                .foregroundStyle(PPColor.muted)
            Text(value)
                .font(PPType.body(14, weight: .medium))
                .foregroundStyle(PPColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
