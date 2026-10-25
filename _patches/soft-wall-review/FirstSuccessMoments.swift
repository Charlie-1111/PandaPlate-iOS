import Foundation
import StoreKit
import SwiftUI
import UIKit

/// Soft wall + native review after first real success — never before value, never after paywall.
/// Milestones: first honest food log confirmed, and/or first Pip ritual ("Say hi") completed.
@MainActor
final class FirstSuccessMoments: ObservableObject {
    static let shared = FirstSuccessMoments()

    static let firstLogKey = "pandaplate.hasCompletedFirstLog"
    static let pipRitualKey = "pandaplate.hasCompletedPipRitual"
    static let didRequestReviewKey = "pandaplate.didRequestReviewAtFirstSuccess"
    /// Once per install (or until dismissed). Soft wall is optional — Free path stays open.
    static let softWallPresentedKey = "pandaplate.didPresentSoftWall"

    private let defaults: UserDefaults

    @Published private(set) var hasCompletedFirstLog: Bool
    @Published private(set) var hasCompletedPipRitual: Bool
    /// MainShell observes this and presents PremiumPaywallView as a dismissible soft sheet.
    @Published var shouldPresentSoftWall = false
    /// MainShell can also drive RequestReviewAction when this flips true.
    @Published var pendingNativeReview = false

    private var successFlowTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasCompletedFirstLog = defaults.bool(forKey: Self.firstLogKey)
        self.hasCompletedPipRitual = defaults.bool(forKey: Self.pipRitualKey)
    }

    /// Call after an honest meal log is confirmed saved (AppStore.addMeal success).
    func noteFirstFoodLogConfirmed() {
        let alreadyHadMilestone = hasCompletedFirstLog || hasCompletedPipRitual
        guard !hasCompletedFirstLog else { return }
        hasCompletedFirstLog = true
        defaults.set(true, forKey: Self.firstLogKey)
        if !alreadyHadMilestone {
            scheduleFirstSuccessFlow()
        }
    }

    /// Call when Pip ritual reaches its first success beat (Say hi → celebration).
    func notePipRitualCompleted() {
        let alreadyHadMilestone = hasCompletedFirstLog || hasCompletedPipRitual
        guard !hasCompletedPipRitual else { return }
        hasCompletedPipRitual = true
        defaults.set(true, forKey: Self.pipRitualKey)
        if !alreadyHadMilestone {
            scheduleFirstSuccessFlow()
        }
    }

    func markSoftWallDismissed() {
        defaults.set(true, forKey: Self.softWallPresentedKey)
        shouldPresentSoftWall = false
    }

    /// MainShell calls after RequestReviewAction / SKStoreReviewController attempt.
    func markReviewRequested() {
        defaults.set(true, forKey: Self.didRequestReviewKey)
        pendingNativeReview = false
    }

    var didRequestReviewAtFirstSuccess: Bool {
        defaults.bool(forKey: Self.didRequestReviewKey)
    }

    var didPresentSoftWall: Bool {
        defaults.bool(forKey: Self.softWallPresentedKey)
    }

    // MARK: - Flow

    /// Order: settle → native review once → soft wall later/separate (never review-bait after wall).
    private func scheduleFirstSuccessFlow() {
        successFlowTask?.cancel()
        successFlowTask = Task { @MainActor in
            // Let save celebration / ritual beat settle.
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }
            queueNativeReviewIfNeeded()

            // Soft wall later in the same session — not stacked on the review prompt.
            try? await Task.sleep(for: .milliseconds(2200))
            guard !Task.isCancelled else { return }
            queueSoftWallIfNeeded()
        }
    }

    private func queueNativeReviewIfNeeded() {
        guard !defaults.bool(forKey: Self.didRequestReviewKey) else { return }
        pendingNativeReview = true
    }

    private func queueSoftWallIfNeeded() {
        guard !defaults.bool(forKey: Self.softWallPresentedKey) else { return }
        guard !PremiumAccess.shared.isPremium else { return }
        shouldPresentSoftWall = true
    }

    /// Fallback when RequestReviewAction isn't available on the presenting view.
    func requestReviewViaStoreKitIfPossible() {
        guard !defaults.bool(forKey: Self.didRequestReviewKey) else {
            pendingNativeReview = false
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        guard let scene else {
            // No scene yet — leave pending so MainShell can retry via RequestReviewAction.
            return
        }
        SKStoreReviewController.requestReview(in: scene)
        markReviewRequested()
    }
}
