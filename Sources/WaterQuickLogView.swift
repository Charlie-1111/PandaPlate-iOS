import SwiftUI

/// Session water log. One tap records a small cup, glass, or bottle.
/// Only drinks that exist are listed. No target or amount keypad.
struct WaterQuickLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filledCount: Int { WaterQuickLogModel.filledCount(for: store.waterServingsML) }
    private var totalML: Int { WaterQuickLogModel.total(for: store.waterServingsML) }
    private var isFull: Bool { filledCount >= WaterQuickLogModel.maximumCups }

    private struct LoggedDrink: Identifiable {
        let index: Int
        let milliliters: Int
        var id: Int { index }
    }

    private var loggedDrinks: [LoggedDrink] {
        store.waterServingsML.enumerated().compactMap { index, amount in
            guard let amount else { return nil }
            return LoggedDrink(index: index, milliliters: amount)
        }
    }

    private var drinkCountLabel: String {
        filledCount == 1 ? "1 drink logged" : "\(filledCount) drinks logged"
    }

    var body: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "Water")
                    Text("\(totalML.formatted()) ml")
                        .font(.system(size: 25, weight: .bold, design: .rounded, relativeTo: .title2))
                        .foregroundStyle(PPColor.ink)
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("waterSessionTotal")
                    Text(drinkCountLabel)
                        .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(PPColor.ink)
                        .accessibilityIdentifier("waterDrinkCount")
                    Text(store.sessionPlan.waterCaption)
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    ForEach(WaterServingSize.allCases) { size in
                        servingSizeButton(size)
                    }
                }

                Text(isFull ? "This session log is full." : "One tap logs that drink.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(isFull ? "waterSessionFull" : "waterLogHint")

                if !loggedDrinks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(loggedDrinks) { drink in
                            loggedDrinkRow(index: drink.index, milliliters: drink.milliliters)
                        }
                    }
                }

                Button {
                    guard store.undoLastWaterChange() else { return }
                } label: {
                    Label("Undo last change", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(store.canUndoWaterChange ? PPColor.coralInk : PPColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(PPColor.cream, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!store.canUndoWaterChange)
                .accessibilityLabel(store.canUndoWaterChange ? "Undo last water change" : "Undo unavailable")
                .accessibilityIdentifier("waterQuickLogUndo")

                Text("Cup sizes are examples; choose the closest match. This is a log, not a hydration goal.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: store.waterServingsML)
    }

    private func servingSizeButton(_ size: WaterServingSize) -> some View {
        Button {
            _ = store.addWater(size.milliliters)
        } label: {
            VStack(spacing: 4) {
                Text(size.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .footnote))
                Text(size.example)
                    .font(.system(size: 15, weight: .heavy, design: .rounded, relativeTo: .subheadline))
            }
            .foregroundStyle(isFull ? PPColor.muted : PPColor.ink)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PPColor.line.opacity(isFull ? 0.35 : 0.7), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isFull)
        .accessibilityLabel("\(size.title), \(size.milliliters) milliliters")
        .accessibilityHint(isFull ? "Session log is full." : "Logs one \(size.milliliters) milliliter drink.")
        .accessibilityIdentifier("waterServingSize_\(size.id)")
    }

    private func loggedDrinkRow(index: Int, milliliters: Int) -> some View {
        let size = WaterServingSize.allCases.first { $0.milliliters == milliliters }
        let title = size?.title ?? "Drink"
        return HStack(spacing: 10) {
            Image("PandaPlateWaterCupFilled")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                Text("\(milliliters) ml")
                    .font(.system(size: 12, weight: .semibold, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }
            Spacer(minLength: 0)
            Button {
                _ = store.setWaterServing(nil, at: index)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PPColor.coralInk)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(title), \(milliliters) milliliters")
            .accessibilityIdentifier("waterDrinkRemove\(index)")
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 52)
        .background(PPColor.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .contain)
    }
}

struct WaterQuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                WaterQuickLogView()
                    .padding(18)
            }
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle("Water")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(PPColor.coralInk)
                        .frame(minHeight: 44)
                }
            }
        }
    }
}
