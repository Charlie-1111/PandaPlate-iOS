import SwiftUI

/// BitePal-style barrel wheel: selected value large/black; neighbors fade + shrink.
struct PandaPlateSnapValueSelector: View {
    let title: String
    let unit: String
    let values: [Int]
    var isRequired = true
    var allowsDirectEntry = true
    /// When false, omit outer title / padding / card so dual time columns can share one parent card.
    var showsChrome = true
    /// Optional alternate unit label shown in a toggle (display only — selection stays in `values` units).
    var alternateUnit: String? = nil
    var onAlternateUnitChange: ((Bool) -> Void)? = nil
    @Binding var selection: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var directEntry = ""
    @State private var entryError: String?
    @State private var useAlternateUnit = false
    @State private var scrollID: Int?
    @FocusState private var directEntryFocused: Bool

    private var isAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }
    private var uniqueValues: [Int] { Array(Set(values)).sorted() }
    private var rowHeight: CGFloat { isAccessibilityLayout ? 56 : 48 }
    private var wheelHeight: CGFloat { isAccessibilityLayout ? 220 : 260 }

    var body: some View {
        VStack(alignment: .leading, spacing: showsChrome ? 7 : 4) {
            if showsChrome {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
            }

            HStack(alignment: .center, spacing: showsChrome ? 12 : 6) {
                barrelWheel
                    .frame(maxWidth: .infinity)
                    .frame(height: wheelHeight)

                unitChrome
            }

            if allowsDirectEntry {
                directEntryControl
            }
        }
        .padding(showsChrome ? 12 : 0)
        .background {
            if showsChrome {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(BitePalColor.whiteCard)
            }
        }
        .onAppear {
            if scrollID == nil {
                scrollID = selection ?? uniqueValues[safe: uniqueValues.count / 2]
            }
            directEntry = selection.map { String($0) } ?? ""
        }
        .onChange(of: selection) { _, newValue in
            if !directEntryFocused {
                directEntry = newValue.map { String($0) } ?? ""
            }
            if let newValue, scrollID != newValue {
                scrollID = newValue
            }
        }
    }

    @ViewBuilder
    private var unitChrome: some View {
        if let alternateUnit {
            VStack(spacing: 8) {
                unitPill(unit, active: !useAlternateUnit) {
                    useAlternateUnit = false
                    onAlternateUnitChange?(false)
                }
                unitPill(alternateUnit, active: useAlternateUnit) {
                    useAlternateUnit = true
                    onAlternateUnitChange?(true)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Unit")
        } else {
            Text(unit)
                .font(.system(size: showsChrome ? 18 : 14, weight: .bold, design: .rounded, relativeTo: showsChrome ? .title3 : .caption))
                .foregroundStyle(PPColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .accessibilityHidden(true)
        }
    }

    private func unitPill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(active ? .white : PPColor.ink)
                .frame(minWidth: 48, minHeight: 36)
                .padding(.horizontal, 10)
                .background(active ? BitePalColor.ctaBlack : BitePalColor.tipPill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(active ? ", selected" : "")")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var barrelWheel: some View {
        GeometryReader { geo in
            let midY = geo.size.height / 2
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(uniqueValues, id: \.self) { value in
                            Text(displayLabel(for: value))
                                .font(.system(size: showsChrome ? 34 : 28, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                                .foregroundStyle(PPColor.ink)
                                .frame(maxWidth: .infinity)
                                .frame(height: rowHeight)
                                .id(value)
                                .visualEffect { content, proxy in
                                    let frame = proxy.frame(in: .named("barrelWheel"))
                                    let distance = abs(frame.midY - midY)
                                    let t = min(1, distance / (rowHeight * 2.4))
                                    let scale = reduceMotion ? (distance < rowHeight * 0.55 ? 1.0 : 0.72) : (1.0 - (0.42 * t))
                                    let opacity = reduceMotion ? (distance < rowHeight * 0.55 ? 1.0 : 0.35) : (1.0 - (0.78 * t))
                                    return content
                                        .scaleEffect(max(0.55, scale), anchor: .center)
                                        .opacity(max(0.18, opacity))
                                }
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.vertical, (wheelHeight - rowHeight) / 2)
                }
                .coordinateSpace(name: "barrelWheel")
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $scrollID)
                .onChange(of: scrollID) { _, newValue in
                    guard let newValue, uniqueValues.contains(newValue) else { return }
                    selection = newValue
                    if !directEntryFocused { directEntry = String(newValue) }
                    entryError = nil
                }
                .onAppear {
                    let target = selection ?? uniqueValues[safe: uniqueValues.count / 2]
                    if let target {
                        proxy.scrollTo(target, anchor: .center)
                        scrollID = target
                    }
                }
            }
        }
        .frame(height: wheelHeight)
        .clipped()
        .accessibilityLabel("\(title), \(isRequired ? "required" : "optional"), \(unit)")
        .accessibilityValue(selection.map { String($0) } ?? "Not selected")
        .accessibilityIdentifier("onboarding-snap-value-\(title.replacingOccurrences(of: " ", with: "-").lowercased())")
    }

    private func displayLabel(for value: Int) -> String {
        guard useAlternateUnit, let alternateUnit else { return "\(value)" }
        // Height cm ↔ ft display (approx); weight kg ↔ lbs display.
        if unit == "cm", alternateUnit == "ft" {
            let totalInches = Double(value) / 2.54
            let feet = Int(totalInches / 12.0)
            let inches = Int((totalInches - Double(feet * 12)).rounded())
            return "\(feet)'\(inches)\""
        }
        if unit == "kg", alternateUnit == "lbs" {
            return "\(Int((Double(value) * 2.20462).rounded()))"
        }
        if unit == "years" { return "\(value)" }
        return "\(value)"
    }

    private var directEntryControl: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Or type a value")
                .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)

            if isAccessibilityLayout {
                VStack(spacing: 8) {
                    directEntryField
                    applyDirectEntryButton
                }
            } else {
                HStack(spacing: 8) {
                    directEntryField
                    applyDirectEntryButton
                }
            }

            Text("Valid range: \(uniqueValues.first ?? 0)–\(uniqueValues.last ?? 0) \(unit)")
                .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let entryError {
                Text(entryError)
                    .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var directEntryField: some View {
        TextField("Type number", text: $directEntry)
            .keyboardType(.numberPad)
            .font(.system(size: 16, weight: .medium, design: .rounded, relativeTo: .body))
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(PPColor.line, lineWidth: 1))
            .focused($directEntryFocused)
            .accessibilityLabel("Enter \(title) in \(unit)")
            .accessibilityHint("Enter a whole number from \(uniqueValues.first ?? 0) to \(uniqueValues.last ?? 0). Tap Set value to apply it.")
            .onChange(of: directEntry) { _, _ in
                guard directEntryFocused else { return }
                entryError = nil
            }
    }

    private var applyDirectEntryButton: some View {
        Button("Set value", action: applyDirectEntry)
            .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minWidth: 44, minHeight: 44)
            .background(directEntry.isEmpty ? PPColor.muted : BitePalColor.ctaBlack, in: Capsule())
            .contentShape(Capsule())
            .accessibilityLabel("Set \(title) value")
            .disabled(directEntry.isEmpty)
    }

    private func applyDirectEntry() {
        guard let value = Int(directEntry.trimmingCharacters(in: .whitespacesAndNewlines)),
              uniqueValues.contains(value) else {
            let bounds = "\(uniqueValues.first ?? 0) to \(uniqueValues.last ?? 0) \(unit)"
            entryError = "Enter a whole number in the range \(bounds)."
            return
        }
        entryError = nil
        directEntry = String(value)
        selection = value
        scrollID = value
        directEntryFocused = false
    }
}

/// Dual barrel (whole + one decimal) for weight, kg/lbs toggle. Stores whole kilograms in `selectionKg`.
/// Wheel digit units ALWAYS match the unit toggle (kg wheels ↔ lbs wheels).
struct PandaPlateDecimalWeightSelector: View {
    let title: String
    @Binding var selectionKg: Int?
    var preciseKgBinding: Binding<Double?>? = nil
    var wholeRange: ClosedRange<Int> = 25...300

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var useLbs = false
    @State private var whole: Int?
    @State private var tenth: Int = 0
    @State private var wholeScroll: Int?
    @State private var tenthScroll: Int?

    private var rowHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 56 : 48 }
    private var wheelHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 220 : 260 }

    /// Whole-number range in the *display* unit.
    private var wholes: [Int] {
        if useLbs {
            // ~55…661 lbs covers 25…300 kg
            return Array(55...661)
        }
        return Array(wholeRange)
    }
    private var tenths: [Int] { Array(0...9) }

    /// Precise kg from current display wheels.
    var preciseKg: Double? {
        guard let whole else { return nil }
        let display = Double(whole) + Double(tenth) / 10.0
        if useLbs {
            return display / 2.20462
        }
        return display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.ink)

            HStack(alignment: .center, spacing: 8) {
                wheel(values: wholes, scrollID: $wholeScroll, label: { "\($0)" })
                Text(".")
                    .font(.system(size: 34, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                    .foregroundStyle(PPColor.ink)
                wheel(values: tenths, scrollID: $tenthScroll, label: { "\($0)" })
                    .frame(maxWidth: 72)

                VStack(spacing: 8) {
                    unitPill("kg", active: !useLbs) { setUnit(lbs: false) }
                    unitPill("lbs", active: useLbs) { setUnit(lbs: true) }
                }
            }
            .frame(height: wheelHeight)

            Text(statusLine)
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
        }
        .padding(12)
        .background(BitePalColor.whiteCard, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear {
            let seedKg = selectionKg.map(Double.init) ?? 70.0
            applyKgToWheels(seedKg, keepUnit: true)
        }
        .onChange(of: wholeScroll) { _, v in
            guard let v else { return }
            whole = v
            commit()
        }
        .onChange(of: tenthScroll) { _, v in
            guard let v else { return }
            tenth = v
            commit()
        }
    }

    private var statusLine: String {
        guard let preciseKg else { return "Select a weight to continue." }
        if useLbs {
            let lbs = preciseKg * 2.20462
            return String(format: "Selected · %.1f lbs (%.1f kg stored)", lbs, preciseKg)
        }
        return String(format: "Selected · %.1f kg", preciseKg)
    }

    private func commit() {
        guard let preciseKg else { return }
        // Clamp to allowed kg range.
        let clamped = min(max(preciseKg, Double(wholeRange.lowerBound)), Double(wholeRange.upperBound))
        selectionKg = Int(clamped.rounded())
        preciseKgBinding?.wrappedValue = clamped
    }

    private func setUnit(lbs: Bool) {
        guard useLbs != lbs else { return }
        let currentKg = preciseKg ?? (selectionKg.map(Double.init) ?? 70.0)
        useLbs = lbs
        applyKgToWheels(currentKg, keepUnit: true)
    }

    private func applyKgToWheels(_ kg: Double, keepUnit: Bool) {
        let display: Double
        if useLbs {
            display = kg * 2.20462
        } else {
            display = kg
        }
        let w = Int(display.rounded(.towardZero))
        let t = Int(((display - Double(w)) * 10.0).rounded())
        let clampedWhole = min(max(w, wholes.first ?? w), wholes.last ?? w)
        let clampedTenth = min(max(t, 0), 9)
        whole = clampedWhole
        tenth = clampedTenth
        wholeScroll = clampedWhole
        tenthScroll = clampedTenth
    }

    private func unitPill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(active ? .white : PPColor.ink)
                .frame(minWidth: 48, minHeight: 36)
                .padding(.horizontal, 10)
                .background(active ? BitePalColor.ctaBlack : BitePalColor.tipPill, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label)\(active ? ", selected" : "")")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func wheel(values: [Int], scrollID: Binding<Int?>, label: @escaping (Int) -> String) -> some View {
        GeometryReader { geo in
            let midY = geo.size.height / 2
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(values, id: \.self) { value in
                        Text(label(value))
                            .font(.system(size: 34, weight: .bold, design: .rounded, relativeTo: .largeTitle))
                            .foregroundStyle(PPColor.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: rowHeight)
                            .id(value)
                            .visualEffect { content, proxy in
                                let frame = proxy.frame(in: .named("decimalWheel-\(values.first ?? 0)-\(useLbs)"))
                                let distance = abs(frame.midY - midY)
                                let t = min(1, distance / (rowHeight * 2.4))
                                let scale = reduceMotion ? (distance < rowHeight * 0.55 ? 1.0 : 0.72) : (1.0 - (0.42 * t))
                                let opacity = reduceMotion ? (distance < rowHeight * 0.55 ? 1.0 : 0.35) : (1.0 - (0.78 * t))
                                return content.scaleEffect(max(0.55, scale)).opacity(max(0.18, opacity))
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.vertical, (wheelHeight - rowHeight) / 2)
            }
            .coordinateSpace(name: "decimalWheel-\(values.first ?? 0)-\(useLbs)")
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: scrollID)
        }
        .frame(maxWidth: .infinity)
        .frame(height: wheelHeight)
        .clipped()
        .accessibilityLabel("\(title), \(useLbs ? "lbs" : "kg")")
    }
}


private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
