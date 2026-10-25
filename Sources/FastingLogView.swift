import Foundation
import SwiftUI

/// Formatting and validation shared by the fasting log screen and its unit tests.
enum FastingLogDuration {
    static let maximumSeconds: TimeInterval = 172_800

    static func seconds(startedAt: Date, endedAt: Date) -> Int? {
        let interval = endedAt.timeIntervalSince(startedAt)
        guard interval > 0, interval <= maximumSeconds else { return nil }
        return Int(interval)
    }

    static func clockText(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        let hours = safeSeconds / 3_600
        let minutes = (safeSeconds % 3_600) / 60
        let remainder = safeSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainder)
    }

    static func summaryText(seconds: Int) -> String {
        let safeSeconds = max(0, seconds)
        guard safeSeconds >= 60 else { return "\(safeSeconds)s" }
        let totalMinutes = safeSeconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(totalMinutes)m"
    }
}

/// A calm, session-only fasting timer and record editor. The app shell can present this
/// independently; it intentionally does not own navigation or mutate other log types.
struct FastingLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let onFinish: () -> Void

    @State private var editingEntry: FastingEntry?
    @State private var showingCancelConfirmation = false
    @State private var showingSaveError = false

    private var recentEntries: [FastingEntry] {
        Array(store.fastingEntries.suffix(6).reversed())
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GeometryReader { proxy in
                    Image("PandaPlateFastingBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PPCard { pageIntro }
                        if let startedAt = store.fastingStartedAt {
                            runningCard(startedAt: startedAt)
                        } else {
                            readyCard
                        }
                        sessionRecords
                        Text("Optional time log · held for this app session only")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(PPColor.card.opacity(0.92), in: Capsule())
                            .padding(.top, 2)
                            .padding(.bottom, 20)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
                .background(Color.clear)
            }
            .navigationTitle("Fasting log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.10, green: 0.24, blue: 0.29), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .tint(PPColor.peach)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .sheet(item: $editingEntry) { entry in
                FastingRecordEditor(entry: entry) { startedAt, endedAt in
                    update(entry, startedAt: startedAt, endedAt: endedAt)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                "Cancel this timer start?",
                isPresented: $showingCancelConfirmation,
                titleVisibility: .visible
            ) {
                Button("Keep timer running", role: .cancel) { }
                Button("Cancel start", role: .destructive) {
                    store.cancelFasting()
                }
            } message: {
                Text("This clears the current start without adding a session record.")
            }
            .alert("This session couldn’t be saved", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Check that the end time is after the start and within 48 hours.")
            }
        }
        .preferredColorScheme(.light)
    }

    private var pageIntro: some View {
        VStack(alignment: .leading, spacing: 7) {
            Eyebrow(text: "OPTIONAL · NO TARGETS")
            Text("A simple time log")
                .font(.system(size: 25, weight: .bold, design: .rounded, relativeTo: .title))
                .foregroundStyle(PPColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Start when you like, then end the log whenever you’re ready.")
                .font(.system(size: 15, weight: .regular, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(width: 44, height: 44)
                    .background(PPColor.peach, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Nothing is running")
                        .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .headline))
                        .foregroundStyle(PPColor.ink)
                    Text("Ready when you are")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.muted)
                }
                Spacer(minLength: 0)
            }

            Text("This only records elapsed time. There’s no target, countdown or reminder.")
                .font(.system(size: 14, weight: .regular, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                store.startFasting()
            } label: {
                Label("Start session log", systemImage: "play.fill")
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(PPColor.coralInk, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start session log")
            .accessibilityHint("Starts a timer that you can end or cancel at any time")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PPColor.line.opacity(0.65), lineWidth: 1))
    }

    private func runningCard(startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let elapsed = max(0, Int(timeline.date.timeIntervalSince(startedAt)))
            let canSave = FastingLogDuration.seconds(startedAt: startedAt, endedAt: timeline.date) != nil

            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 9) {
                    Circle()
                        .fill(PPColor.coralInk)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)
                    Text("In progress")
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                    Spacer()
                    Text("TIMER RUNNING")
                        .font(.system(size: 10, weight: .bold, design: .rounded, relativeTo: .caption2))
                        .tracking(0.8)
                        .foregroundStyle(PPColor.muted)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Elapsed time")
                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.muted)
                    Text(FastingLogDuration.clockText(seconds: elapsed))
                        .font(.system(size: 38, weight: .bold, design: .rounded, relativeTo: .largeTitle).monospacedDigit())
                        .foregroundStyle(PPColor.ink)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(FastingLogDuration.clockText(seconds: elapsed))
                    Text("Started \(startedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                Button {
                    guard store.endFasting(at: Date()) else {
                        showingSaveError = true
                        return
                    }
                    onFinish()
                } label: {
                    Label("End and save session log", systemImage: "stop.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .headline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(PPColor.coralInk, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.55)
                .accessibilityLabel("End and save session log")
                .accessibilityHint("Saves the elapsed time as a session record")

                if !canSave {
                    Text("This timer is beyond the 48-hour log limit. Cancel the start to clear it.")
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Cancel this start") {
                    showingCancelConfirmation = true
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .body))
                .foregroundStyle(PPColor.coralInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .accessibilityHint("Clears the running timer without saving a record")
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PPColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(PPColor.line.opacity(0.65), lineWidth: 1))
        }
    }

    private var sessionRecords: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Session records")
            if recentEntries.isEmpty {
                Text("Saved logs will appear here. You can edit their recorded times.")
                    .font(.system(size: 14, weight: .regular, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 9) {
                    ForEach(recentEntries) { entry in
                        recordRow(entry)
                    }
                }
            }
        }
        .padding(14)
        .background(PPColor.card.opacity(0.96), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func recordRow(_ entry: FastingEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PPColor.coralInk)
                .frame(width: 40, height: 40)
                .background(PPColor.peach.opacity(0.75), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(FastingLogDuration.summaryText(seconds: entry.durationSeconds))
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                    .foregroundStyle(PPColor.ink)
                Text("\(entry.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(entry.endedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 4)

            Button {
                editingEntry = entry
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minWidth: 54, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit session record")
            .accessibilityHint("Changes the recorded start and end times")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(PPColor.line.opacity(0.55), lineWidth: 1))
    }

    private func update(_ entry: FastingEntry, startedAt: Date, endedAt: Date) -> Bool {
        guard let duration = FastingLogDuration.seconds(startedAt: startedAt, endedAt: endedAt),
              let index = store.fastingEntries.firstIndex(where: { $0.id == entry.id }) else { return false }

        var updatedEntry = store.fastingEntries[index]
        updatedEntry.startedAt = startedAt
        updatedEntry.endedAt = endedAt
        updatedEntry.durationSeconds = duration
        var updatedEntries = store.fastingEntries
        updatedEntries[index] = updatedEntry
        store.fastingEntries = updatedEntries
        return true
    }
}

private struct FastingRecordEditor: View {
    @Environment(\.dismiss) private var dismiss

    let entry: FastingEntry
    let onSave: (Date, Date) -> Bool

    @State private var startedAt: Date
    @State private var endedAt: Date
    @State private var showingSaveError = false

    init(entry: FastingEntry, onSave: @escaping (Date, Date) -> Bool) {
        self.entry = entry
        self.onSave = onSave
        _startedAt = State(initialValue: entry.startedAt)
        _endedAt = State(initialValue: entry.endedAt)
    }

    private var duration: Int? {
        FastingLogDuration.seconds(startedAt: startedAt, endedAt: endedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recorded times") {
                    DatePicker("Started", selection: $startedAt, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Ended", selection: $endedAt, displayedComponents: [.date, .hourAndMinute])
                }

                Section {
                    if let duration {
                        LabeledContent("Recorded duration", value: FastingLogDuration.summaryText(seconds: duration))
                    } else {
                        Text("Choose an end time after the start and within 48 hours.")
                            .foregroundStyle(PPColor.muted)
                    }
                }

                Section {
                    Text("This is an editable time record only. It doesn’t set a goal or reminder.")
                        .foregroundStyle(PPColor.muted)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PPColor.cream)
            .navigationTitle("Edit session log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard onSave(startedAt, endedAt) else {
                            showingSaveError = true
                            return
                        }
                        dismiss()
                    }
                    .disabled(duration == nil)
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .alert("Couldn’t save this change", isPresented: $showingSaveError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The record may have changed. Close this editor and try again.")
            }
        }
        .preferredColorScheme(.light)
    }
}
