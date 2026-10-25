import Foundation
import StoreKit
import SwiftUI

/// Premium unlock via StoreKit 2 when products are available; DEBUG local unlock is a separate flag.
/// Prices come from StoreKit products only; no fallback price is invented in the UI.
///
/// Persistence:
/// - `pandaplate.isPremium` mirrors the effective Premium state (StoreKit OR DEBUG unlock).
/// - `pandaplate.debugPremiumUnlock` is DEBUG-only. StoreKit refresh clears effective Premium
///   when there is no entitlement **unless** this DEBUG flag is actively set — so a stuck
///   Debug unlock can no longer permanently mask Free locks after a StoreKit refresh.
@MainActor
final class PremiumAccess: ObservableObject {
    static let shared = PremiumAccess()
    nonisolated static let monthlyProductID = "com.charlie.pandaplate.premium.monthly"
    nonisolated static let yearlyProductID = "com.charlie.pandaplate.premium.yearly"
    /// Backward-compatible alias used by older call sites / notes.
    nonisolated static let productID = monthlyProductID
    static let monthlyPriceDisplay = "Price from App Store"
    static let yearlyPriceDisplay = "Price from App Store"
    static let defaultsKey = "pandaplate.isPremium"
    static let debugUnlockKey = "pandaplate.debugPremiumUnlock"

    private let defaults: UserDefaults
    private var updatesTask: Task<Void, Never>?
    /// True when the last StoreKit entitlement scan found an active monthly/yearly subscription.
    private var storeKitEntitled = false

    @Published var isPremium: Bool {
        didSet { defaults.set(isPremium, forKey: Self.defaultsKey) }
    }
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var storeKitUnavailableMessage: String?
    @Published private(set) var purchaseInFlight = false
    @Published var lastPurchaseError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        #if DEBUG
        let debugUnlock = defaults.bool(forKey: Self.debugUnlockKey)
        #else
        // Release never honors a leftover DEBUG unlock key.
        let debugUnlock = false
        if defaults.object(forKey: Self.debugUnlockKey) != nil {
            defaults.removeObject(forKey: Self.debugUnlockKey)
        }
        #endif
        // Prefer explicit DEBUG unlock; otherwise start from persisted mirror (may be cleared by refresh).
        self.isPremium = debugUnlock || defaults.bool(forKey: Self.defaultsKey)
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { await refreshProductsAndEntitlements() }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// DEBUG-only local unlock. Persisted under `debugUnlockKey`, distinct from StoreKit.
    func unlockForTesting() {
        #if DEBUG
        defaults.set(true, forKey: Self.debugUnlockKey)
        isPremium = true
        #endif
    }

    /// DEBUG-only clear of local unlock. Also clears the legacy mirror so Free locks show immediately.
    func lockForTesting() {
        #if DEBUG
        defaults.set(false, forKey: Self.debugUnlockKey)
        defaults.removeObject(forKey: Self.debugUnlockKey)
        isPremium = storeKitEntitled
        defaults.set(isPremium, forKey: Self.defaultsKey)
        #endif
    }

    /// Effective DEBUG unlock (Release always false).
    var hasDebugUnlock: Bool {
        #if DEBUG
        defaults.bool(forKey: Self.debugUnlockKey)
        #else
        false
        #endif
    }

    func refreshProductsAndEntitlements() async {
        await loadProducts()
        await refreshEntitlementsFromStore()
    }

    func loadProducts() async {
        do {
            let ids = [Self.monthlyProductID, Self.yearlyProductID]
            let products = try await Product.products(for: ids)
            monthlyProduct = products.first(where: { $0.id == Self.monthlyProductID })
            yearlyProduct = products.first(where: { $0.id == Self.yearlyProductID })
            if products.isEmpty {
                storeKitUnavailableMessage =
                    "Premium purchases aren’t available yet because subscription products haven’t been configured. Free features remain available."
            } else {
                storeKitUnavailableMessage = nil
            }
        } catch {
            monthlyProduct = nil
            yearlyProduct = nil
            storeKitUnavailableMessage =
                "Couldn’t reach the App Store for prices. Free stays fully usable — try again later, or use Restore if you already subscribed."
        }
    }

    func product(for plan: PremiumPlanChoice) -> Product? {
        switch plan {
        case .monthly: return monthlyProduct
        case .yearly: return yearlyProduct
        }
    }

    func purchase(_ plan: PremiumPlanChoice) async -> Bool {
        lastPurchaseError = nil
        guard let product = product(for: plan) else {
            lastPurchaseError = storeKitUnavailableMessage
                ?? "This subscription option isn’t available right now. Free features remain available."
            return false
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isPremium = true
                await transaction.finish()
                return true
            case .userCancelled:
                return false
            case .pending:
                lastPurchaseError = "Purchase is pending approval. You’ll get Premium when it clears."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastPurchaseError = "Purchase didn’t complete. Nothing was charged beyond what Apple shows — Free stays available."
            return false
        }
    }

    func restorePurchases() async {
        lastPurchaseError = nil
        do {
            try await StoreKit.AppStore.sync()
            await refreshEntitlementsFromStore()
            if !isPremium {
                lastPurchaseError = "No active Premium subscription found for this Apple ID."
            }
        } catch {
            lastPurchaseError = "Restore didn’t finish. Check your network and try again."
        }
    }

    /// Kept name for older call sites.
    func restorePurchasesStub() {
        Task { await restorePurchases() }
    }

    private func refreshEntitlementsFromStore() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyProductID
                || transaction.productID == Self.yearlyProductID {
                entitled = true
                break
            }
        }
        storeKitEntitled = entitled
        #if DEBUG
        let debugUnlock = defaults.bool(forKey: Self.debugUnlockKey)
        #else
        let debugUnlock = false
        #endif
        // StoreKit wins when entitled. Without entitlement, stay Premium only if DEBUG unlock is active.
        // This clears a stuck `pandaplate.isPremium=true` left by an old Debug toggle.
        isPremium = entitled || debugUnlock
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.monthlyProductID
                || transaction.productID == Self.yearlyProductID {
                await transaction.finish()
                await refreshEntitlementsFromStore()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}

enum PremiumPlanChoice: String, CaseIterable, Identifiable {
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
        case .monthly: return "Monthly price shown by Apple"
        case .yearly: return "Yearly price shown by Apple"
        }
    }

    var detail: String {
        switch self {
        case .monthly: return "Monthly subscription"
        case .yearly: return "Yearly subscription"
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Soft first-success prompt: dismissible, no guilt, no fake timers.
    var isSoftPrompt: Bool = false
    var onUnlocked: (() -> Void)? = nil
    @State private var selectedPlan: PremiumPlanChoice = .yearly

    private let benefits: [(String, String, String)] = [
        ("chart.xyaxis.line", "Session nutrition snapshot", "See logged meal calories and water; unknown values stay unknown."),
        ("leaf.fill", "Little World looks", "Unlock Scarf, Gardener, Chef, Nap, Cheer, and Explorer looks for Pip."),
        ("calendar", "Show-up history", "See recent check-in days without a streak counter."),
        ("square.and.arrow.up", "Session CSV export", "Export the current session’s entries as a CSV file."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Hero
                    VStack(spacing: 10) {
                        Image("PP_PipWaveCheer")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 180, maxHeight: 200)
                            .accessibilityLabel("Pip cheering")

                        Text(isSoftPrompt ? "A little more\nwith Pip" : "PandaPlate\nPremium")
                            .font(.ppDisplay(size: 36, relativeTo: .largeTitle))
                            .foregroundStyle(Color.black)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(isSoftPrompt
                             ? "Optional — Free features remain available."
                             : "Unlock extra Pip looks and session tools. Free features remain available.")
                            .font(.system(size: 14, weight: .medium, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)

                    // Plan cards
                    VStack(spacing: 12) {
                        ForEach(Array(PremiumPlanChoice.allCases.reversed())) { plan in
                            planCard(plan)
                        }
                    }

                    // Benefits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Included with Premium")
                            .font(.system(size: 15, weight: .bold, design: .rounded, relativeTo: .subheadline))
                            .foregroundStyle(PPColor.ink)
                        ForEach(benefits, id: \.1) { item in
                            benefitRow(symbol: item.0, title: item.1, detail: item.2)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Text("Food scanning isn’t available in this version. Manual logs, water, workouts, and fasting remain available on Free.")
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                        .multilineTextAlignment(.center)

                    Button {
                        Task {
                            let ok = await premium.purchase(selectedPlan)
                            if ok {
                                onUnlocked?()
                                dismiss()
                            }
                        }
                    } label: {
                        Group {
                            if premium.purchaseInFlight {
                                ProgressView().tint(.white)
                            } else {
                                Text(purchaseButtonTitle)
                                    .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .headline))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(BitePalColor.ctaBlack, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(premium.purchaseInFlight || premium.product(for: selectedPlan) == nil)
                    .accessibilityLabel(purchaseButtonTitle)

                    if isSoftPrompt {
                        Button { dismiss() } label: {
                            Text("Not now — keep Free")
                                .font(.system(size: 15, weight: .semibold, design: .rounded, relativeTo: .body))
                                .foregroundStyle(PPColor.ink.opacity(0.7))
                                .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Dismisses Premium. Free features stay available.")
                    }

                    Button {
                        Task { await premium.restorePurchases() }
                    } label: {
                        Text("Restore purchases")
                            .font(.system(size: 14, weight: .semibold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.muted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)

                    if let err = premium.lastPurchaseError {
                        Text(err)
                            .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                            .foregroundStyle(PPColor.coralInk)
                    }

                    Text(footerHonestyLine)
                        .font(.system(size: 11, weight: .medium, design: .rounded, relativeTo: .caption2))
                        .foregroundStyle(PPColor.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [Color(red: 0.99, green: 0.97, blue: 0.94), Color.white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isSoftPrompt ? "Not now" : "Close") { dismiss() }
                        .tint(PPColor.ink)
                }
            }
            .task {
                await premium.refreshProductsAndEntitlements()
            }
        }
        .transaction { txn in
            if reduceMotion { txn.animation = nil }
        }
    }

    private var purchaseButtonTitle: String {
        if let product = premium.product(for: selectedPlan) {
            return "Continue · \(product.displayPrice)"
        }
        return "Premium unavailable"
    }

    private var footerHonestyLine: String {
        if let note = premium.storeKitUnavailableMessage { return note }
        return "Subscription prices and renewal terms are shown by Apple before purchase. Manage or cancel in Apple ID subscription settings."
    }

    private func planCard(_ plan: PremiumPlanChoice) -> some View {
        let selected = selectedPlan == plan
        return Button {
            selectedPlan = plan
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.system(size: 16, weight: .bold, design: .rounded, relativeTo: .body))
                            .foregroundStyle(PPColor.ink)
                    }
                    Text(plan.detail)
                        .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                        .foregroundStyle(PPColor.muted)
                }
                Spacer(minLength: 0)
                Text(livePrice(for: plan))
                    .font(.system(size: 20, weight: .black, design: .rounded, relativeTo: .title3))
                    .foregroundStyle(PPColor.ink)
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? BitePalColor.ctaBlack : Color.black.opacity(0.08), lineWidth: selected ? 2.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(plan.title), \(livePrice(for: plan))")
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func livePrice(for plan: PremiumPlanChoice) -> String {
        if let product = premium.product(for: plan) {
            return product.displayPrice
        }
        return "Not available"
    }

    private func benefitRow(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BitePalColor.selectGreen)
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
