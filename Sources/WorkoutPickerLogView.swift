import SwiftUI

/// A standalone workout picker and session log. The host supplies the existing
/// session-only workout array and decides what to do after a newly saved entry.
struct WorkoutPickerLogView: View {
    @Binding var workouts: [WorkoutEntry]
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: WorkoutInputField?
    @State private var activityType: WorkoutActivityType = .casualWalk
    @State private var customActivityName = ""
    @State private var durationChoice: WorkoutDurationChoice = .preset(30)
    @State private var customDurationMinutes = ""
    @State private var editingWorkoutID: UUID?
    @State private var validationMessage: String?

    private let activityColumns = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]

    private enum WorkoutInputField: Hashable {
        case activity
        case duration
    }

    private var resolvedActivity: String? {
        WorkoutFeatureRules.resolvedActivityName(for: activityType, customName: customActivityName)
    }

    private var resolvedDuration: Int? {
        WorkoutFeatureRules.resolvedDuration(for: durationChoice, customMinutes: customDurationMinutes)
    }

    private var canSave: Bool {
        editingWorkoutID != nil || workouts.count < WorkoutFeatureRules.maximumSessionEntries
    }


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    activityPicker
                    if activityType == .other {
                        customActivityField
                    }
                    durationPicker
                    if let validationMessage {
                        Text(validationMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.coralInk)
                    }
                    saveControls
                    sessionLog
                    Text("Kcal shows only from Apple Health when synced. Manual logs stay Unknown — blank is not zero. Not medical advice.")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(PPColor.coralInk)
                }
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(editingWorkoutID == nil ? "Log an activity" : "Edit activity")
                .font(.system(size: 25, weight: .black, design: .rounded, relativeTo: .largeTitle))
                .foregroundStyle(PPColor.ink)
            Text("Choose what you did and for how long. Your log stays in this session.")
                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.muted)
        }
    }

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Activity")
            LazyVGrid(columns: activityColumns, spacing: 9) {
                ForEach(WorkoutActivityType.allCases) { choice in
                    activityButton(choice)
                }
            }
        }
    }

    private func activityButton(_ choice: WorkoutActivityType) -> some View {
        let selected = activityType == choice
        return Button {
            activityType = choice
            validationMessage = nil
            focusedField = nil
        } label: {
            HStack(spacing: 9) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(selected ? PPColor.coralInk : PPColor.ink)
                    .frame(width: 22)
                Text(choice.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PPColor.coralInk)
                }
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .background(selected ? PPColor.peach : PPColor.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(selected ? PPColor.coral : PPColor.line.opacity(0.7), lineWidth: selected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(choice.rawValue)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var customActivityField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("What would you like to call it?")
                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)
            TextField("e.g. Pilates", text: $customActivityName)
                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                .textContentType(.none)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .activity)
                .submitLabel(.done)
                .onSubmit { focusedField = nil }
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(PPColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PPColor.line, lineWidth: 1))
                .accessibilityLabel("Custom activity name")
            Text("Up to \(WorkoutFeatureRules.maximumActivityNameLength) characters")
                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
        .onChange(of: customActivityName) { _, newValue in
            if newValue.count > WorkoutFeatureRules.maximumActivityNameLength {
                customActivityName = String(newValue.prefix(WorkoutFeatureRules.maximumActivityNameLength))
            }
            validationMessage = nil
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "How many minutes?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WorkoutFeatureRules.presetDurations, id: \.self) { minutes in
                        durationButton(title: "\(minutes) min", choice: .preset(minutes))
                    }
                    durationButton(title: "Custom", choice: .custom)
                }
            }
            if durationChoice == .custom {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            let current = Int(customDurationMinutes) ?? 30
                            customDurationMinutes = String(max(1, current - 5))
                            validationMessage = nil
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Decrease duration by 5 minutes")

                        TextField("Minutes", text: $customDurationMinutes)
                            .font(.system(size: 22, weight: .bold, design: .rounded, relativeTo: .title2))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .duration)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .accessibilityLabel("Workout duration in minutes")
                            .onChange(of: customDurationMinutes) { _, _ in validationMessage = nil }

                        Text("min")
                            .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)

                        Button {
                            let current = Int(customDurationMinutes) ?? 30
                            customDurationMinutes = String(min(WorkoutFeatureRules.maximumCustomDuration, current + 5))
                            validationMessage = nil
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(PPColor.coralInk)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Increase duration by 5 minutes")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PPColor.line, lineWidth: 1))

                    // Fine-grain minute wheel
                    Picker("Minutes", selection: Binding(
                        get: { Int(customDurationMinutes) ?? 30 },
                        set: { customDurationMinutes = String($0); validationMessage = nil }
                    )) {
                        ForEach(Array(stride(from: 1, through: 180, by: 1)), id: \.self) { m in
                            Text("\(m) min").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 120)
                    .accessibilityLabel("Duration minute picker")

                    Text("Pick minutes (1–\(WorkoutFeatureRules.maximumCustomDuration)). Kcal stays Unknown unless Apple Health provides it.")
                        .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
                .onAppear {
                    if customDurationMinutes.isEmpty { customDurationMinutes = "30" }
                }
            }

            // Honesty: no invented burn. Manual draft always Unknown (blank ≠ 0).
            HStack(spacing: 8) {
                Image(systemName: "flame")
                    .foregroundStyle(PPColor.muted)
                Text("Burned energy: Unknown")
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                Spacer()
            }
            .padding(12)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityLabel("Burned energy Unknown. Only Apple Health synced workouts show kcal.")

        }
    }

    private func durationButton(title: String, choice: WorkoutDurationChoice) -> some View {
        let selected = durationChoice == choice
        return Button {
            durationChoice = choice
            validationMessage = nil
            if case .custom = choice, customDurationMinutes.isEmpty {
                customDurationMinutes = "30"
            }
            if choice != .custom { focusedField = nil }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(selected ? .white : PPColor.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? PPColor.coralInk : PPColor.card, in: Capsule())
                .overlay(Capsule().stroke(selected ? PPColor.coralInk : PPColor.line, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var saveControls: some View {
        VStack(spacing: 9) {
            Button(action: saveWorkout) {
                Text(editingWorkoutID == nil ? "Save workout" : "Save changes")
                    .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(canSave ? PPColor.coralInk : PPColor.muted.opacity(0.55), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .accessibilityHint(editingWorkoutID == nil ? "Adds this activity to the session log" : "Updates this session log entry")

            if editingWorkoutID != nil {
                Button("Stop editing") {
                    cancelEditing()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
                .frame(minHeight: 40)
            } else if workouts.count >= WorkoutFeatureRules.maximumSessionEntries {
                Text("This session has reached its log limit.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
        }
    }

    private var sessionLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Session log · \(workouts.count)")
            if workouts.isEmpty {
                PPCard(padding: 15) {
                    Text("Your saved activities will appear here.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(workouts.sorted { $0.time > $1.time }) { workout in
                        workoutRow(workout)
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: WorkoutFeatureRules.activityType(forLoggedName: workout.activity).symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PPColor.coralInk)
                .frame(width: 36, height: 36)
                .background(PPColor.peach, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activity)
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                    .lineLimit(2)
                Text(workoutKcalLine(workout))
                    .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer(minLength: 2)
            Button {
                beginEditing(workout)
            } label: {
                Text("Edit")
                    .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(workout.activity)")
            Button {
                deleteWorkout(workout)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minWidth: 40, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(workout.activity)")
        }
        .padding(.leading, 11)
        .padding(.trailing, 5)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(PPColor.line.opacity(0.65), lineWidth: 1))
    }

    private func workoutKcalLine(_ workout: WorkoutEntry) -> String {
        let time = workout.time.formatted(date: .abbreviated, time: .shortened)
        if let kcal = workout.activeEnergyKcal {
            return "\(workout.durationMinutes) min · \(kcal) kcal (Health) · \(time)"
        }
        return "\(workout.durationMinutes) min · kcal Unknown · \(time)"
    }

    private func beginEditing(_ workout: WorkoutEntry) {
        focusedField = nil
        editingWorkoutID = workout.id
        activityType = WorkoutFeatureRules.activityType(forLoggedName: workout.activity)
        customActivityName = activityType == .other ? workout.activity : ""
        if WorkoutFeatureRules.presetDurations.contains(workout.durationMinutes) {
            durationChoice = .preset(workout.durationMinutes)
            customDurationMinutes = ""
        } else {
            durationChoice = .custom
            customDurationMinutes = String(workout.durationMinutes)
        }
        validationMessage = nil
    }

    private func saveWorkout() {
        guard let activity = resolvedActivity else {
            validationMessage = "Add a name for this activity."
            focusedField = .activity
            return
        }
        guard let duration = resolvedDuration else {
            validationMessage = "Pick a duration chip or enter 1–\(WorkoutFeatureRules.maximumCustomDuration) minutes."
            if durationChoice == .custom { focusedField = .duration }
            return
        }

        if let editingWorkoutID {
            guard let index = workouts.firstIndex(where: { $0.id == editingWorkoutID }) else {
                self.editingWorkoutID = nil
                validationMessage = "This workout no longer appears in the session log. Choose a new entry."
                return
            }
            guard let updated = WorkoutFeatureRules.makeEntry(
                activity: activity,
                durationMinutes: duration,
                time: workouts[index].time,
                activeEnergyKcal: workouts[index].activeEnergyKcal
            ) else {
                validationMessage = "Check the activity name and duration, then try again."
                return
            }
            workouts[index] = updated
            self.editingWorkoutID = nil
            resetDraft()
            validationMessage = "Workout updated."
            return
        }

        guard workouts.count < WorkoutFeatureRules.maximumSessionEntries else {
            validationMessage = "This session has reached its log limit."
            return
        }
        guard let entry = WorkoutFeatureRules.makeEntry(activity: activity, durationMinutes: duration) else {
            validationMessage = "Check the activity name and duration, then try again."
            return
        }
        workouts.append(entry)
        onFinish()
    }

    private func deleteWorkout(_ workout: WorkoutEntry) {
        workouts.removeAll { $0.id == workout.id }
        if editingWorkoutID == workout.id {
            cancelEditing()
        }
    }

    private func cancelEditing() {
        editingWorkoutID = nil
        validationMessage = nil
        resetDraft()
    }

    private func resetDraft() {
        focusedField = nil
        activityType = .casualWalk
        customActivityName = ""
        durationChoice = .preset(30)
        customDurationMinutes = ""
    }
}
