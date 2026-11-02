import SwiftUI

/// Ten session-only water slots. Select a cup and size, then explicitly add or update it.
/// No target or amount keypad.
struct WaterQuickLogView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedServing: WaterServingSize = .glass
    @State private var selectedCupIndex: Int?

    private var filledCount: Int { WaterQuickLogModel.filledCount(for: store.waterServingsML) }
    private var totalML: Int { WaterQuickLogModel.total(for: store.waterServingsML) }
    private var canApplySelectedServing: Bool {
        guard let selectedCupIndex,
              store.waterServingsML.indices.contains(selectedCupIndex),
              WaterQuickLogModel.canSet(selectedServing.milliliters, at: selectedCupIndex, in: store.waterServingsML) else { return false }
        return store.waterServingsML[selectedCupIndex] != selectedServing.milliliters
    }
    private var applyButtonTitle: String {
        guard let selectedCupIndex, store.waterServingsML.indices.contains(selectedCupIndex) else { return "Select a cup" }
        return store.waterServingsML[selectedCupIndex] == nil ? "Add one cup" : "Update cup size"
    }
    private var selectionHint: String {
        guard let selectedCupIndex, store.waterServingsML.indices.contains(selectedCupIndex) else {
            return "Choose a size, tap an empty cup, then add it."
        }
        if let amount = store.waterServingsML[selectedCupIndex] {
            return "Cup \(selectedCupIndex + 1) has \(amount) ml. Choose a size, then tap Update cup size."
        }
        return "Cup \(selectedCupIndex + 1) selected · \(selectedServing.example). Tap Add one cup to log it."
    }

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
                        Text("\(filledCount) of \(WaterQuickLogModel.maximumCups) cups · session total")
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.muted)
                            .accessibilityLabel("\(filledCount) of 10 cups logged. Session total, \(totalML.formatted()) milliliters.")
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

                Text(selectionHint)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    ForEach(WaterServingSize.allCases) { size in
                        servingSizeButton(size)
                    }
                }

                Button {
                    guard let selectedCupIndex,
                          store.setWaterServing(selectedServing.milliliters, at: selectedCupIndex) else { return }
                } label: {
                    Label(applyButtonTitle, systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(canApplySelectedServing ? PPColor.coralInk : PPColor.muted, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canApplySelectedServing)
                .accessibilityIdentifier("waterQuickLogAddCup")

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
            if let serving,
               let matchingSize = WaterServingSize.allCases.first(where: { $0.milliliters == serving }) {
                selectedServing = matchingSize
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
        .accessibilityHint(isFilled ? "Selects this cup; choose a size and tap Update cup size to change it." : "Selects this empty cup; tap Add one cup to log it.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("waterCupSlot\(index)")
    }

    private func servingSizeButton(_ size: WaterServingSize) -> some View {
        let isSelected = selectedServing == size
        return Button {
            selectedServing = size
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
        .accessibilityHint("Selects the size only. Tap Add one cup or Update cup size to apply it.")
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
