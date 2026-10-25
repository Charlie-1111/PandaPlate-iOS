import Foundation
import SwiftUI

/// Local premium unlock for development until StoreKit is wired.
/// Locked offer copy: $7.99/mo or $49.99/yr.
@MainActor
final class PremiumAccess: ObservableObject {
    static let shared = PremiumAccess()
    static let monthlyProductID = "com.charlie.pandaplate.premium.monthly"
    static let yearlyProductID = "com.charlie.pandaplate.premium.yearly"
    /// Backward-compatible alias used by older call sites / notes.
    static let productID = monthlyProductID
    static let monthlyPriceDisplay = "$7.99/mo"
    static let yearlyPriceDisplay = "$49.99/yr"
    static let defaultsKey = "pandaplate.isPremium"

    private let defaults: UserDefaults

    @Published var isPremium: Bool {
        didSet { defaults.set(isPremium, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isPremium = defaults.bool(forKey: Self.defaultsKey)
    }

    func unlockForTesting() {
        isPremium = true
    }

    func lockForTesting() {
        isPremium = false
    }

    func restorePurchasesStub() {
        // StoreKit restore will land later; keep honest no-op for now.
    }
}

private enum PremiumPlanChoice: String, CaseIterable, Identifiable {
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var priceLine: String {
        switch self {
        case .monthly: return PremiumAccess.monthlyPriceDisplay
        case .yearly: return PremiumAccess.yearlyPriceDisplay
        }
    }

    var detail: String {
        switch self {
        case .monthly: return "Flexible month to month"
        case .yearly: return "Best value · save vs monthly"
        }
    }

    var productID: String {
        switch self {
        case .monthly: return PremiumAccess.monthlyProductID
        case .yearly: return PremiumAccess.yearlyProductID
        }
    }
}

struct PremiumPaywallView: View {
    @ObservedObject private var premium = PremiumAccess.shared
    @Environment(\.dismiss) private var dismiss
    var onUnlocked: (() -> Void)? = nil
    @State private var selectedPlan: PremiumPlanChoice = .yearly

    private let benefits: [(String, String, String)] = [
        ("camera.viewfinder", "Unlimited Food Scans", "No daily cap — camera or library → identify → you edit & save."),
        ("face.smiling", "Pip reaction packs", "More soft Pip moments after you log — never a grade."),
        ("leaf.fill", "Little World cosmetics", "Dress up Pip’s world when cosmetics land."),
        ("calendar", "Soft Show-Up history", "Gentle check-ins history without streak shame."),
        ("text.bubble", "Feel-check tags → Pip phrases", "Tag how you feel; Pip answers with soft phrases."),
        ("square.and.arrow.up", "Export this session", "Share today’s session log as CSV — not a full history backup."),
        ("pin.fill", "Pin USDA favorites", "Keep handy FoodData Central matches for faster edits."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("PandaPlate Premium")
                                .font(.system(size: 26, weight: .black, design: .rounded, relativeTo: .title))
                                .foregroundStyle(PPColor.ink)
                            Text("Unlimited scans and Pip extras — still your call what to save.")
                                .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .body))
                                .foregroundStyle(PPColor.muted)
                        }
                        Spacer(minLength: 8)
                        PipMascot(size: 64, assetName: "PP_PipCelebrate")
                    }

                    planPicker

                    PPCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("INCLUDED")
                                .font(.system(size: 9, weight: .heavy, design: .rounded, relativeTo: .caption2))
                                .tracking(1.1)
                                .foregroundStyle(PPColor.muted)
                            ForEach(benefits, id: \.1) { item in
                                benefitRow(symbol: item.0, title: item.1, detail: item.2)
                            }
                        }
                    }

                    Text("Pip’s with you. 3 Food Scans a day, log by hand, water + workouts + fasting, gentle plan — no calorie theater.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)

                    Button {
                        // Dev unlock until StoreKit product IDs are wired.
                        _ = selectedPlan.productID
                        premium.unlockForTesting()
                        onUnlocked?()
                        dismiss()
                    } label: {
                        Text("Unlock Premium · \(selectedPlan.priceLine)")
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(PPColor.coralInk, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Unlock Premium, \(selectedPlan.priceLine)")

                    Button {
                        premium.restorePurchasesStub()
                    } label: {
                        Text("Restore")
                            .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.coralInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    Text("Prices shown for planning: \(PremiumAccess.monthlyPriceDisplay) or \(PremiumAccess.yearlyPriceDisplay). StoreKit isn’t connected yet — Unlock uses a local testing flag. Product IDs: \(PremiumAccess.monthlyProductID), \(PremiumAccess.yearlyProductID).")
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                }
                .padding(20)
            }
            .background(PPColor.cream.ignoresSafeArea())
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.tint(PPColor.coralInk)
                }
            }
        }
    }

    private var planPicker: some View {
        HStack(spacing: 10) {
            ForEach(PremiumPlanChoice.allCases) { plan in
                let selected = selectedPlan == plan
                Button {
                    selectedPlan = plan
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.ink)
                        Text(plan.priceLine)
                            .font(.system(size: 18, weight: .black, design: .rounded, relativeTo: .title3))
                            .foregroundStyle(selected ? PPColor.coralInk : PPColor.ink)
                        Text(plan.detail)
                            .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                            .foregroundStyle(PPColor.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                    .padding(14)
                    .background(PPColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? PPColor.coral : PPColor.line, lineWidth: selected ? 2 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(plan.title), \(plan.priceLine)")
                .accessibilityValue(selected ? "Selected" : "Not selected")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func benefitRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PPColor.coralInk)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded, relativeTo: .subheadline))
                    .foregroundStyle(PPColor.ink)
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
            }
        }
    }
}
