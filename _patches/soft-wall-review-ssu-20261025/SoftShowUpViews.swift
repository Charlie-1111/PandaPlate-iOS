// SoftShowUpViews.swift — Soft Show-Up presence + Premium history (#5)
// Clear copy only. Cream/coral. No red X's. No streak language.

import SwiftUI

/// Compact presence card — Progress History / Profile.
struct SoftShowUpPresenceCard: View {
    @ObservedObject var store: SoftShowUpStore = .shared
    let isPremium: Bool
    var onOpenHistory: () -> Void
    var onFreeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(SoftShowUpCopy.title.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(PPColor.muted)

            Text(SoftShowUpCopy.countLabel)
                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)

            Text(store.countHeadline)
                .font(.system(size: 20, weight: .black, design: .rounded, relativeTo: .title3))
                .foregroundStyle(PPColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if store.isFrozenToday {
                recoveryBlock(title: SoftShowUpCopy.freezeTitle, body: SoftShowUpCopy.freezeBody)
            } else if store.seenCount > 0 && !store.isSeenToday {
                recoveryBlock(title: SoftShowUpCopy.napTitle, body: SoftShowUpCopy.napBody)
            }

            HStack(spacing: 10) {
                if store.isFrozenToday {
                    Button(SoftShowUpCopy.unfreezeCTA) { store.unfreezeToday() }
                        .buttonStyle(SoftShowUpSecondaryButtonStyle())
                } else {
                    Button(SoftShowUpCopy.freezeCTA) { store.freezeToday() }
                        .buttonStyle(SoftShowUpSecondaryButtonStyle())
                        .accessibilityHint(SoftShowUpCopy.freezeBody)
                }

                Button {
                    if isPremium { onOpenHistory() } else { onFreeTap() }
                } label: {
                    Text(SoftShowUpCopy.historyTitle)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(SoftShowUpPrimaryButtonStyle())
            }

            Text(SoftShowUpCopy.footer)
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }

    private func recoveryBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.coralInk)
            Text(body)
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.peach.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Premium Soft Show-Up history — calm calendar.
struct SoftShowUpHistoryView: View {
    @ObservedObject var store: SoftShowUpStore = .shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(SoftShowUpCopy.historySubtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)

                    if store.seenCount == 0 && !store.isFrozenToday {
                        Text(SoftShowUpCopy.historyEmpty)
                            .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.ink)
                            .padding(.vertical, 8)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(store.recentHistory) { day in
                            SoftShowUpDayCell(day: day)
                        }
                    }

                    legend
                    Text(SoftShowUpCopy.footer)
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
                .padding(18)
            }
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle(SoftShowUpCopy.historyTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 12, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.coralInk)
                }
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: PPColor.coral, label: SoftShowUpCopy.historySeen)
            legendRow(color: PPColor.peach, label: SoftShowUpCopy.historyMissed)
            legendRow(color: PPColor.muted.opacity(0.45), label: SoftShowUpCopy.historyFrozen)
        }
    }

    private func legendRow(color: Color, label: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
        }
    }
}

private struct SoftShowUpDayCell: View {
    let day: SoftShowUpDay

    var body: some View {
        VStack(spacing: 4) {
            Text(dayLabel)
                .font(.system(size: 9, weight: .bold, design: .rounded, relativeTo: .caption2))
                .foregroundStyle(PPColor.muted)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(fill)
                .frame(height: 36)
                .overlay(
                    Text(shortMark)
                        .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(markColor)
                )
                .accessibilityLabel(accessLabel)
        }
    }

    private var dayLabel: String {
        let parts = day.dateKey.split(separator: "-")
        return parts.count == 3 ? String(parts[2]) : "·"
    }

    private var fill: Color {
        switch day.kind {
        case .seen: return PPColor.coral.opacity(0.85)
        case .quiet: return PPColor.peach.opacity(0.55)
        case .frozen: return PPColor.muted.opacity(0.25)
        }
    }

    private var shortMark: String {
        switch day.kind {
        case .seen: return "·"
        case .quiet: return ""
        case .frozen: return "❄︎"
        }
    }

    private var markColor: Color {
        day.kind == .seen ? .white : PPColor.ink.opacity(0.55)
    }

    private var accessLabel: String {
        switch day.kind {
        case .seen: return SoftShowUpCopy.historySeen
        case .quiet: return SoftShowUpCopy.historyMissed
        case .frozen: return SoftShowUpCopy.historyFrozen
        }
    }
}

private struct SoftShowUpPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
            .foregroundStyle(.white)
            .background(PPColor.coralInk.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
    }
}

private struct SoftShowUpSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
            .foregroundStyle(PPColor.coralInk)
            .frame(minWidth: 110, minHeight: 44)
            .background(PPColor.card.opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

/// Soft repair toast after returning from a gap (optional host).
struct SoftShowUpRepairBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SoftShowUpCopy.repairTitle)
                .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.ink)
            Text(SoftShowUpCopy.repairBody)
                .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                .foregroundStyle(PPColor.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PPColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
