import SwiftUI

/// Optional 24-hour time composed from the PandaPlate snap scroller rather than a system wheel.
/// Compact dual-column layout so Hour + Minute + unit labels fit on mini/SE widths without clipping.
struct PandaPlateSnapTimeSelector: View {
    let title: String
    @Binding var time: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hour: Int?
    @State private var minute: Int?

    private var isAccessibilityLayout: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                .foregroundStyle(PPColor.ink)

            if isAccessibilityLayout {
                VStack(spacing: 8) {
                    hourSelector
                    minuteSelector
                }
            } else {
                GeometryReader { geo in
                    let gap: CGFloat = 4
                    let colonW: CGFloat = 14
                    let colW = max(96, (geo.size.width - colonW - gap * 2) / 2)
                    HStack(alignment: .center, spacing: gap) {
                        hourSelector
                            .frame(width: colW, alignment: .leading)
                        Text(":")
                            .font(.system(size: 22, weight: .bold, design: .rounded, relativeTo: .title2))
                            .foregroundStyle(PPColor.ink)
                            .frame(width: colonW)
                            .accessibilityHidden(true)
                        minuteSelector
                            .frame(width: colW, alignment: .leading)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                }
                .frame(height: 280)
            }

            HStack {
                Text(time.isEmpty ? "Optional · 24-hour time · choose both to save" : "Selected · 24-hour time · \(time)")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .accessibilityLabel(time.isEmpty ? "No optional time selected. Choose both hour and minute to save." : "Selected time, 24-hour clock, \(time)")
                Spacer(minLength: 8)
                if !time.isEmpty || hour != nil || minute != nil {
                    Button("Clear time") {
                        hour = nil
                        minute = nil
                        time = ""
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(10)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear(perform: syncFromTime)
        .onChange(of: hour) { _, _ in updateTime() }
        .onChange(of: minute) { _, _ in updateTime() }
    }

    private var hourSelector: some View {
        PandaPlateSnapValueSelector(
            title: "Hour",
            unit: "hr",
            values: Array(0...23),
            isRequired: false,
            allowsDirectEntry: false,
            showsChrome: false,
            selection: $hour
        )
    }

    private var minuteSelector: some View {
        PandaPlateSnapValueSelector(
            title: "Minute",
            unit: "min",
            values: Array(0...59),
            isRequired: false,
            allowsDirectEntry: false,
            showsChrome: false,
            selection: $minute
        )
    }

    private func syncFromTime() {
        let components = time.split(separator: ":")
        guard components.count == 2,
              let parsedHour = Int(components[0]), (0...23).contains(parsedHour),
              let parsedMinute = Int(components[1]), (0...59).contains(parsedMinute) else {
            if time.isEmpty { hour = nil; minute = nil }
            return
        }
        if hour != parsedHour { hour = parsedHour }
        if minute != parsedMinute { minute = parsedMinute }
    }

    private func updateTime() {
        guard let hour, let minute else {
            if !time.isEmpty { time = "" }
            return
        }
        let formatted = String(format: "%02d:%02d", hour, minute)
        if time != formatted { time = formatted }
    }
}
