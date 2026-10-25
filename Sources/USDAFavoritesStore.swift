// USDAFavoritesStore.swift — Premium Harvest pin USDA favorites
// HONESTY LOCKS (Clear):
// 1. Pin NEVER invents nutrition — store only {fdcId, description, lastCalories?}.
// 2. lastCalories only when already known (server / prior user edit); never default 0.
// 3. Consent STILL required on every scan — picking a favorite does not skip consent.
// 4. Free → paywall; Premium local unlock OK until StoreKit.
// 5. Cap ~20; dedupe by fdcId (re-pin moves to front).
// 6. No DeepSeek / API key; fdcId is a USDA FoodData Central catalog ref only.

import Foundation
import Combine
import SwiftUI

// MARK: - Model

struct PinnedUSDAFavorite: Codable, Equatable, Identifiable {
    /// USDA FoodData Central id — stable pin key.
    var fdcId: Int
    /// Human description from FDC / search result (as returned — do not rewrite into macros).
    var description: String
    /// Optional last-known calories from a prior honest source. nil = unknown (UI blank).
    var lastCalories: Int?

    var id: Int { fdcId }
}

// MARK: - Store

@MainActor
final class USDAFavoritesStore: ObservableObject {
    static let shared = USDAFavoritesStore()

    /// Confirmed no collision with pandaplate.isPremium / pandaplate.scanBaseURL / scanQuota keys.
    static let defaultsKey = "pp.usda.favorites"
    /// Soft cap — ~20; oldest (end of array) dropped on overflow after insert-at-front.
    static let cap = 20

    @Published private(set) var favorites: [PinnedUSDAFavorite] = []
    /// Prefill for Manual meal entry only — never sets consent or starts a scan.
    @Published var pendingPrefill: EditorPrefill?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
    }

    func reload() {
        guard let data = defaults.data(forKey: Self.defaultsKey) else {
            favorites = []
            return
        }
        do {
            let decoded = try JSONDecoder().decode([PinnedUSDAFavorite].self, from: data)
            favorites = Array(decoded.prefix(Self.cap))
        } catch {
            favorites = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(favorites)
            defaults.set(data, forKey: Self.defaultsKey)
        } catch {
            // Soft fail — do not crash logging path.
        }
    }

    /// Pin or refresh. Dedupe by fdcId; move to front. Cap ~20.
    /// - Parameter lastCalories: Pass only a known value; omit / nil if unknown — NEVER invent 0 to “fill”.
    @discardableResult
    func pin(fdcId: Int, description: String, lastCalories: Int? = nil) -> Bool {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard fdcId > 0, !trimmed.isEmpty else { return false }

        // If re-pinning and new lastCalories is nil, keep prior known calories (don’t wipe honesty).
        let prior = favorites.first { $0.fdcId == fdcId }
        let caloriesToStore: Int?
        if let lastCalories {
            caloriesToStore = lastCalories
        } else {
            caloriesToStore = prior?.lastCalories
        }

        let item = PinnedUSDAFavorite(
            fdcId: fdcId,
            description: trimmed,
            lastCalories: caloriesToStore
        )

        var next = favorites.filter { $0.fdcId != fdcId }
        next.insert(item, at: 0)
        if next.count > Self.cap {
            next = Array(next.prefix(Self.cap))
        }
        favorites = next
        persist()
        return true
    }

    func unpin(fdcId: Int) {
        favorites.removeAll { $0.fdcId == fdcId }
        persist()
    }

    func isPinned(fdcId: Int) -> Bool {
        favorites.contains { $0.fdcId == fdcId }
    }

    /// Fill editor fields from a pin — name always; calories only if lastCalories != nil.
    /// Does NOT start a scan and does NOT set consent.
    struct EditorPrefill: Equatable {
        var dishName: String
        /// nil → leave calories editor blank
        var calories: Int?
        var fdcId: Int
    }

    func prefill(for fdcId: Int) -> EditorPrefill? {
        guard let fav = favorites.first(where: { $0.fdcId == fdcId }) else { return nil }
        return EditorPrefill(
            dishName: fav.description,
            calories: fav.lastCalories, // may be nil — UI blank
            fdcId: fav.fdcId
        )
    }

    /// Queue a prefill for Manual entry. Does not touch consent / scan quota.
    func queuePrefill(_ prefill: EditorPrefill) {
        pendingPrefill = prefill
    }

    /// Consume pending prefill once (Manual meal sheet onAppear).
    func consumePendingPrefill() -> EditorPrefill? {
        let value = pendingPrefill
        pendingPrefill = nil
        return value
    }
}

// MARK: - Premium-gated pin control

/// Use on a USDA / FDC match row. Free → paywall; Premium → pin.
struct PinUSDAFavoriteButton: View {
    let fdcId: Int
    let description: String
    /// Only pass when the row already has honest calories from FDC / server — else nil.
    var lastCalories: Int? = nil
    let isPremium: Bool
    var onFreeTap: () -> Void
    @ObservedObject var store: USDAFavoritesStore = .shared

    var body: some View {
        Button {
            guard isPremium else {
                onFreeTap()
                return
            }
            if store.isPinned(fdcId: fdcId) {
                store.unpin(fdcId: fdcId)
            } else {
                _ = store.pin(fdcId: fdcId, description: description, lastCalories: lastCalories)
            }
        } label: {
            Image(systemName: store.isPinned(fdcId: fdcId) ? "pin.fill" : "pin")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PPColor.coralInk)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .accessibilityLabel(store.isPinned(fdcId: fdcId) ? "Unpin favorite" : "Pin USDA favorite")
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Favorites list (Settings / Search tab surface)

struct USDAFavoritesList: View {
    @ObservedObject var store: USDAFavoritesStore = .shared
    /// Called when user picks a favorite to prefill — parent must NOT skip consent on subsequent scan.
    var onSelect: (USDAFavoritesStore.EditorPrefill) -> Void

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                Text("Pinned USDA foods show up here. Pin from a Food Scan match when you’re Premium.")
                    .font(.system(size: 12, weight: .medium, design: .rounded, relativeTo: .caption))
                    .foregroundStyle(PPColor.muted)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.favorites) { fav in
                        HStack(alignment: .top, spacing: 10) {
                            Button {
                                if let pre = store.prefill(for: fav.fdcId) {
                                    onSelect(pre)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fav.description)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded, relativeTo: .caption))
                                        .foregroundStyle(PPColor.ink)
                                        .multilineTextAlignment(.leading)
                                    HStack(spacing: 8) {
                                        Text("FDC \(fav.fdcId)")
                                            .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                                            .foregroundStyle(PPColor.muted)
                                        if let kcal = fav.lastCalories {
                                            Text("\(kcal) kcal")
                                                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                                                .foregroundStyle(PPColor.muted)
                                        } else {
                                            Text("kcal unknown")
                                                .font(.system(size: 10, weight: .medium, design: .rounded, relativeTo: .caption2))
                                                .foregroundStyle(PPColor.muted)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Prefills manual meal name only. Food Scan still needs consent.")

                            Button {
                                store.unpin(fdcId: fav.fdcId)
                            } label: {
                                Image(systemName: "pin.slash")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(PPColor.muted)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Unpin")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
