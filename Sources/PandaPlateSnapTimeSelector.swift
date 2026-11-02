import SwiftUI

/// Required hour-only meal time selector. The model stores canonical HH:00 values,
/// while the UI shows a readable 12-hour value such as “8 AM”.
struct PandaPlateSnapTimeSelector: View {
    let title: String
    @Binding var time: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var directHourFieldFocused: Bool
    @State private var selectedHour: Int?
    @State private var selectedPeriod: String?
    @State private var centeredHourID: Int?
    @State private var directHourText = ""
    @State private var directEntryMessage: String?
    @State private var didUserScroll = false

    private let hours = Array(1...12)
    private let periods = ["AM", "PM"]

    private var identifier: String {
        title.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    private var selectedTimeText: String? {
        guard let selectedHour, let selectedPeriod else { return nil }
        return "\(selectedHour) \(selectedPeriod)"
    }

    private var selectionStatus: String {
        if let selectedTimeText { return "Selected · \(selectedTimeText)" }
        if let selectedHour { return "\(selectedHour) selected · pick AM or PM" }
        if let selectedPeriod { return "\(selectedPeriod) selected · select an hour" }
        return "No time selected"
    }

    private var directEntryHour: Int? {
        let digits = directHourText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !digits.isEmpty, digits.allSatisfy({ $0.isNumber }),
              let hour = Int(digits), (1...12).contains(hour) else { return nil }
        return hour
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                    .foregroundStyle(PPColor.ink)
                Spacer(minLength: 8)
                if let selectedTimeText {
                    Text(selectedTimeText)
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.forestDeep)
                        .accessibilityLabel("Selected time, \(selectedTimeText)")
                }
            }

            Text("Tap or scroll to select an hour from 1 to 12.")
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            hourScroller

            HStack(spacing: 10) {
                ForEach(periods, id: \.self) { period in
                    periodButton(period)
                }
            }

            directEntrySection

            HStack(spacing: 8) {
                Text(selectionStatus)
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(selectedTimeText == nil ? PPColor.muted : PPColor.forestDeep)
                    .accessibilityLabel(selectionStatus)
                Spacer(minLength: 8)
                Button("Clear") {
                    clearSelection()
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.forestDeep)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
                .disabled(time.isEmpty && selectedHour == nil && selectedPeriod == nil && directHourText.isEmpty)
                .opacity(time.isEmpty && selectedHour == nil && selectedPeriod == nil && directHourText.isEmpty ? 0.45 : 1)
                .accessibilityLabel("Clear \(title.lowercased()) time")
            }
        }
        .padding(14)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(PPColor.line.opacity(0.7), lineWidth: 1))
        .onAppear { restoreSelection(from: time) }
        .onChange(of: time) { _, newValue in restoreSelection(from: newValue) }
    }

    private var hourScroller: some View {
        ScrollViewReader { proxy in
            hourStrip
                .onAppear {
                    guard let selectedHour else { return }
                    centeredHourID = selectedHour
                    proxy.scrollTo(selectedHour, anchor: .center)
                }
                .onChange(of: selectedHour) { _, newValue in
                    guard let newValue else { return }
                    let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.18)
                    withAnimation(animation) {
                        centeredHourID = newValue
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
        }
    }

    @ViewBuilder
    private var hourStrip: some View {
        if #available(iOS 18.0, *) {
            baseHourStrip
                .onScrollPhaseChange { _, newPhase in
                    if newPhase == .tracking || newPhase == .interacting || newPhase == .decelerating {
                        didUserScroll = true
                    } else if newPhase == .idle, didUserScroll {
                        didUserScroll = false
                        if let centeredHourID { selectHour(centeredHourID) }
                    }
                }
        } else {
            baseHourStrip
                .simultaneousGesture(
                    DragGesture(minimumDistance: 5)
                        .onEnded { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                if let centeredHourID { selectHour(centeredHourID) }
                            }
                        }
                )
        }
    }

    private var baseHourStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(hours, id: \.self) { hour in
                    hourButton(hour)
                        .id(hour)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centeredHourID, anchor: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Hours for \(title)")
        .accessibilityHint("Swipe horizontally to browse hours from 1 to 12. Tap an hour to select it.")
    }

    private func hourButton(_ hour: Int) -> some View {
        let selected = selectedHour == hour
        return Button {
            selectHour(hour)
        } label: {
            Text("\(hour)")
                .font(.system(size: 20, weight: .bold, design: .rounded, relativeTo: .title3))
                .foregroundStyle(selected ? .white : PPColor.ink)
                .frame(width: 58, height: 56)
                .background(selected ? PPColor.forestDeep : PPColor.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(selected ? PPColor.forestDeep : PPColor.line, lineWidth: selected ? 2 : 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), hour \(hour)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint("Select hour \(hour), then select AM or PM.")
        .accessibilityIdentifier("mealTime-\(identifier)-hour-\(hour)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func periodButton(_ period: String) -> some View {
        let selected = selectedPeriod == period
        return Button {
            let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.16)
            withAnimation(animation) { selectedPeriod = period }
            commitTime()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .accessibilityHidden(true)
                Text(period)
                    .font(.system(size: 17, weight: .bold, design: .rounded, relativeTo: .headline))
            }
            .foregroundStyle(selected ? .white : PPColor.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(selected ? PPColor.forestDeep : PPColor.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? PPColor.forestDeep : PPColor.line.opacity(0.8), lineWidth: selected ? 1.5 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(period)")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityIdentifier("mealPeriod-\(identifier)-\(period.lowercased())")
        .accessibilityHint("Select \(period) for the chosen hour.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var directEntrySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Or enter an hour")
                .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)

            HStack(spacing: 10) {
                TextField("1–12", text: $directHourText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 17, weight: .semibold, design: .rounded, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .frame(minHeight: 48)
                    .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(PPColor.line, lineWidth: 1))
                    .focused($directHourFieldFocused)
                    .accessibilityLabel("Enter hour from 1 to 12 for \(title)")
                    .onChange(of: directHourText) { _, newValue in
                        let digits = String(newValue.filter { $0.isNumber }.prefix(2))
                        if digits != newValue { directHourText = digits }
                        if let entered = Int(digits), !(1...12).contains(entered) {
                            directEntryMessage = "Enter a number from 1 to 12."
                        } else {
                            directEntryMessage = nil
                        }
                    }

                Button("Use hour") {
                    guard let directEntryHour else { return }
                    directHourFieldFocused = false
                    selectHour(directEntryHour)
                }
                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 48)
                .background(PPColor.forestDeep, in: Capsule())
                .buttonStyle(.plain)
                .disabled(directEntryHour == nil)
                .opacity(directEntryHour == nil ? 0.45 : 1)
                .accessibilityHint("Sets the hour shown in the selector. Select AM or PM below.")
            }

            if let directEntryMessage {
                Text(directEntryMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.accentCoral)
                    .accessibilityLabel("Hour entry error: \(directEntryMessage)")
            }
        }
    }

    private func selectHour(_ hour: Int) {
        guard (1...12).contains(hour) else { return }
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.18)
        withAnimation(animation) {
            selectedHour = hour
            centeredHourID = hour
            directHourText = String(hour)
        }
        directEntryMessage = nil
        commitTime()
    }

    private func commitTime() {
        guard let selectedHour, let selectedPeriod else {
            time = ""
            return
        }
        let hour24 = (selectedHour % 12) + (selectedPeriod == "PM" ? 12 : 0)
        time = String(format: "%02d:00", hour24)
    }

    private func restoreSelection(from value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.isEmpty {
            selectedHour = nil
            selectedPeriod = nil
            centeredHourID = nil
            directHourText = ""
            directEntryMessage = nil
            return
        }

        // Keep an earlier AM/PM-only draft visible, but require an explicit hour before Continue.
        if periods.contains(normalized) {
            selectedHour = nil
            selectedPeriod = normalized
            centeredHourID = nil
            directHourText = ""
            return
        }

        if MealTimeValidator.isValidOptional24HourTime(normalized), normalized.count == 5,
           let hour24 = Int(normalized.prefix(2)), (0...23).contains(hour24) {
            let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
            selectedHour = hour12
            selectedPeriod = hour24 < 12 ? "AM" : "PM"
            centeredHourID = hour12
            directHourText = String(hour12)
            return
        }

        // Also accept a previously formatted value such as “8 AM”.
        let parts = normalized.split(separator: " ")
        if parts.count == 2, let hour12 = Int(parts[0]), (1...12).contains(hour12), periods.contains(String(parts[1])) {
            selectedHour = hour12
            selectedPeriod = String(parts[1])
            centeredHourID = hour12
            directHourText = String(hour12)
            return
        }

        selectedHour = nil
        selectedPeriod = nil
        centeredHourID = nil
        directHourText = ""
    }

    private func clearSelection() {
        let animation: Animation? = reduceMotion ? nil : .easeInOut(duration: 0.16)
        withAnimation(animation) {
            time = ""
            selectedHour = nil
            selectedPeriod = nil
            centeredHourID = nil
            directHourText = ""
            directEntryMessage = nil
        }
        directHourFieldFocused = false
    }
}
