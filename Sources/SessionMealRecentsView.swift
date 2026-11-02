import SwiftUI

/// A reviewed copy of a meal entry. It deliberately carries no image or persistence metadata.
struct SessionMealReviewDraft: Equatable, Hashable {
    var name: String
    /// nil means unknown. An explicit 0 remains 0.
    var calories: Int?
}

/// Pure helpers for the session-only recent-meal list and copy review.
enum SessionMealRecents {
    static let maximumVisibleItems = 8
    static let maximumMealNameLength = 120
    static let maximumCalories = 10_000

    /// Returns the latest entry for each non-empty meal name, newest first.
    /// The input is only the current in-memory session; nothing is persisted.
    static func latestUniqueMeals(from meals: [MealEntry], limit: Int = maximumVisibleItems) -> [MealEntry] {
        let boundedLimit = min(max(0, limit), maximumVisibleItems)
        guard boundedLimit > 0 else { return [] }

        let newestFirst = meals.enumerated().sorted { lhs, rhs in
            if lhs.element.time != rhs.element.time {
                return lhs.element.time > rhs.element.time
            }
            // For identical timestamps, the item appended later wins.
            return lhs.offset > rhs.offset
        }

        var seenNames = Set<String>()
        var result: [MealEntry] = []
        for (_, meal) in newestFirst {
            let name = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard !key.isEmpty, seenNames.insert(key).inserted else { continue }
            result.append(meal)
            if result.count == boundedLimit { break }
        }
        return result
    }

    /// Copies only the name and the exact calorie value. Unknown stays nil; photos are never copied.
    static func reviewDraft(copying meal: MealEntry) -> SessionMealReviewDraft {
        SessionMealReviewDraft(
            name: meal.name.trimmingCharacters(in: .whitespacesAndNewlines),
            calories: meal.calories
        )
    }

    static func isValidCaloriesInput(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || parsedCalories(from: trimmed) != nil
    }

    /// Empty means unknown. A typed 0 is an explicit value and remains 0.
    static func parsedCalories(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let value = Int(trimmed),
              (0...maximumCalories).contains(value) else { return nil }
        return value
    }

    static func isValidMealName(_ text: String) -> Bool {
        let count = text.trimmingCharacters(in: .whitespacesAndNewlines).count
        return (1...maximumMealNameLength).contains(count)
    }
}

/// A reusable session-only recents picker. Selecting a row opens an editable review;
/// `onSave` is called only after the user explicitly taps “Save meal”.
struct SessionMealRecentsView: View {
    let meals: [MealEntry]
    let onSave: (SessionMealReviewDraft) -> Void
    let onClose: () -> Void

    @State private var showingReview = false
    @State private var reviewName = ""
    @State private var reviewCaloriesText = ""

    private var recentMeals: [MealEntry] {
        SessionMealRecents.latestUniqueMeals(from: meals)
    }

    private var canSaveReview: Bool {
        SessionMealRecents.isValidMealName(reviewName)
            && SessionMealRecents.isValidCaloriesInput(reviewCaloriesText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Recent meals")
                            .font(.system(size: 27, weight: .heavy, design: .rounded, relativeTo: .largeTitle))
                            .foregroundStyle(PPColor.ink)
                        Text("From this session only. Copy opens a review; nothing is saved until you tap Save meal.")
                            .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let latest = recentMeals.first {
                        Button {
                            beginReview(copying: latest)
                        } label: {
                            Label("Copy last meal", systemImage: "doc.on.doc")
                                .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(PPColor.coral, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the latest meal in an editable review. It is not saved yet.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "This session")
                        if recentMeals.isEmpty {
                            PPCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("No recent meals yet", systemImage: "fork.knife")
                                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                                        .foregroundStyle(PPColor.ink)
                                    Text("Log a meal in this session and it’ll appear here.")
                                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .body))
                                        .foregroundStyle(PPColor.muted)
                                }
                            }
                        } else {
                            ForEach(recentMeals) { meal in
                                recentMealRow(meal)
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle("Quick repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                        .tint(PPColor.coralInk)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .navigationDestination(isPresented: $showingReview) {
                reviewScreen
            }
        }
        .tint(PPColor.coralInk)
    }

    private func recentMealRow(_ meal: MealEntry) -> some View {
        Button {
            beginReview(copying: meal)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(width: 44, height: 44)
                    .background(PPColor.peach, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.name.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(meal.calories.map { "\($0.formatted()) kcal" } ?? "Calories unknown")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .body))
                        .foregroundStyle(PPColor.muted)
                    Text("Logged \(meal.time.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(PPColor.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PPColor.line.opacity(0.6), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Review copy of \(meal.name.trimmingCharacters(in: .whitespacesAndNewlines))")
        .accessibilityValue(meal.calories.map { "\($0) calories" } ?? "Calories unknown")
        .accessibilityHint("Opens an editable copy. Nothing is saved until you confirm.")
    }

    private var reviewScreen: some View {
        Form {
            Section("Review copied meal") {
                TextField("Meal name", text: $reviewName)
                    .accessibilityLabel("Meal name")
                    .textInputAutocapitalization(.sentences)
                if !SessionMealRecents.isValidMealName(reviewName) {
                    Text("Enter a meal name up to 120 characters.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                }

                HStack {
                    Text("Calories, if known")
                    Spacer()
                    TextField("Unknown", text: $reviewCaloriesText)
                        .accessibilityLabel("Calories, optional estimate")
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                if !SessionMealRecents.isValidCaloriesInput(reviewCaloriesText) {
                    Text("Enter a whole number from 0 to 10,000, or leave it blank.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                }
                Text("Blank stays unknown, not zero. The earlier photo isn’t copied.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }

            Section {
                Button {
                    guard canSaveReview else { return }
                    let draft = SessionMealReviewDraft(
                        name: reviewName.trimmingCharacters(in: .whitespacesAndNewlines),
                        calories: SessionMealRecents.parsedCalories(from: reviewCaloriesText)
                    )
                    onSave(draft)
                    onClose()
                } label: {
                    Text("Save meal")
                        .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .disabled(!canSaveReview)
                .accessibilityHint("Adds this reviewed meal to the current session")
            } footer: {
                Text("This creates a new session entry only after you confirm.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(PPColor.cream)
        .navigationTitle("Review copy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", action: { showingReview = false })
                    .tint(PPColor.coralInk)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
    }

    private func beginReview(copying meal: MealEntry) {
        let draft = SessionMealRecents.reviewDraft(copying: meal)
        reviewName = draft.name
        reviewCaloriesText = draft.calories.map(String.init) ?? ""
        showingReview = true
    }
}
