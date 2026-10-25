import Foundation

/// App-issued challenge progress is derived from actual entries in the current session.
@MainActor
enum PandaPlateChallengeProgress {
    static func mealNotes(in store: AppStore) -> Int { store.meals.count }
    static func waterCups(in store: AppStore) -> Int { WaterQuickLogModel.filledCount(for: store.waterServingsML) }
    static func activities(in store: AppStore) -> Int { store.workouts.count }
}
