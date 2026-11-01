import SwiftUI

/// Ten session-only water slots. Tap an empty cup to add the selected serving;
/// select a filled cup and a size to edit it. No target or amount keypad.
struct WaterQuickLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedServing: WaterServingSize = .glass
    @State private var selectedCupIndex: Int?

    private var filledCount: Int { WaterQuickLogModel.filledCount(for: store.waterServingsML) }
    private var totalML: Int { WaterQuickLogModel.total(for: store.waterServingsML) }

    var body: some View {
        PPCard(padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "Water")
                        Text("\(totalML.formatted()) ml")
                            .font(.system(size: 25, weight: .bold, design: .rounded, relativeTo: .title2))
                            .foregroundStyle(PPColor.ink)
                            .contentTransition(.numericText())
                        Text(store.sessionPlan.waterCaption)
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .accessibilityLabel("\(store.sessionPlan.waterCaption) \(filledCount) of 10 cups logged. Session total, \(totalML.formatted()) milliliters.")
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(0..<WaterQuickLogModel.maximumCups / 5, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach((row * 5)..<(row * 5 + 5), id: \.self) { index in
                                cupButton(at: index)
                            }
                        }
                    }
                }

                Text(selectedCupIndex.map { "Cup \($0 + 1) selected · choose its size below." } ?? "Tap a cup to add one. Choose a size before or after to match what you drank.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(WaterServingSize.allCases) { size in
                        servingSizeButton(size)
                    }
                }

                HStack(spacing: 10) {
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

                    Button {
                        guard let selectedCupIndex,
                              store.setWaterServing(nil, at: selectedCupIndex) else { return }
                        self.selectedCupIndex = nil
                    } label: {
                        Label("Remove cup", systemImage: "trash")
                            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(selectedCupIndex.flatMap { store.waterServingsML[$0] } == nil ? PPColor.muted : PPColor.coralInk)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(PPColor.cream, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCupIndex.flatMap { store.waterServingsML[$0] } == nil)
                    .accessibilityLabel("Remove selected water cup")
                }

                Text("Cup sizes are examples; choose the closest match. This is a log, not a hydration goal.")
                    .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: store.waterServingsML)
    }

    private func cupButton(at index: Int) -> some View {
        let serving = store.waterServingsML[index]
        let isSelected = selectedCupIndex == index
        let isFilled = serving != nil
        let canSelect = isFilled || WaterQuickLogModel.filledCount(for: store.waterServingsML) < WaterQuickLogModel.maximumCups
        let spokenValue = serving.map { "\($0) milliliters" } ?? "empty"

        return Button {
            selectedCupIndex = index
            if !isFilled {
                _ = store.setWaterServing(selectedServing.milliliters, at: index)
            }
        } label: {
            Image(isFilled ? "PandaPlateWaterCupFilled" : "PandaPlateWaterCupEmpty")
                .resizable()
                .scaledToFit()
                .frame(width: 31, height: 39)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(isSelected ? PPColor.peach : PPColor.cream, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(isSelected ? PPColor.coralInk : PPColor.line.opacity(0.55), lineWidth: isSelected ? 2 : 1)
                }
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSelect)
        .accessibilityLabel("Water cup \(index + 1), \(spokenValue)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(isFilled ? "Selects this cup so you can change its size or remove it." : "Adds a \(selectedServing.milliliters) milliliter serving.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("waterCupSlot\(index)")
    }

    private func servingSizeButton(_ size: WaterServingSize) -> some View {
        let isSelected = selectedServing == size
        return Button {
            selectedServing = size
            if let selectedCupIndex,
               store.waterServingsML[selectedCupIndex] != nil {
                _ = store.setWaterServing(size.milliliters, at: selectedCupIndex)
            }
        } label: {
            VStack(spacing: 3) {
                Text(size.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded, relativeTo: .caption2))
                Text(size.example)
                    .font(.system(size: 11, weight: .semibold, design: .rounded, relativeTo: .caption2))
            }
            .foregroundStyle(isSelected ? PPColor.coralInk : PPColor.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isSelected ? PPColor.peach : PPColor.cream, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isSelected ? PPColor.coralInk : PPColor.line.opacity(0.7), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(size.title), \(size.milliliters) milliliters")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(selectedCupIndex.flatMap { store.waterServingsML[$0] } == nil ? "Sets the size for the next cup." : "Changes the selected cup to this size.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("waterServingSize_\(size.id)")
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
