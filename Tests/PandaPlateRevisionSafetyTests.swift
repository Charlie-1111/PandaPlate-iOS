import XCTest
@testable import PandaPlate

@MainActor
final class PandaPlateRevisionSafetyTests: XCTestCase {
    func testWorkoutAndFastingRecordsDoNotChangeNutritionTotals() {
        let store = AppStore()
        store.addMeal(name: "Lunch", calories: 500, imageData: nil)
        let originalCalories = store.caloriesEaten
        let start = Date(timeIntervalSince1970: 2_000_000)

        XCTAssertTrue(store.addWorkout(activity: "Brisk walk", durationMinutes: 30, time: start))
        store.startFasting(at: start)
        XCTAssertTrue(store.endFasting(at: start.addingTimeInterval(3_600)))

        XCTAssertEqual(store.caloriesEaten, originalCalories)
        XCTAssertEqual(store.meals.count, 1)
        XCTAssertEqual(store.workouts.count, 1)
        XCTAssertEqual(store.fastingEntries.count, 1)
        // No caloriesRemaining / dailyGoal deficit theater — workouts and fasting never invent nutrition math.
    }

    func testFastingRequiresPositiveElapsedTimeAndRejectsMoreThan48Hours() {
        let store = AppStore()
        let start = Date(timeIntervalSince1970: 2_000_000)
        store.startFasting(at: start)

        XCTAssertFalse(store.endFasting(at: start), "A zero-length log must not be saved.")
        XCTAssertFalse(store.endFasting(at: start.addingTimeInterval(-1)), "An end time before the start must be rejected.")
        XCTAssertFalse(store.endFasting(at: start.addingTimeInterval(172_801)), "Logs longer than 48 hours must be rejected.")
        XCTAssertTrue(store.fastingEntries.isEmpty)
        XCTAssertEqual(store.fastingStartedAt, start, "Rejected end attempts must leave the active session available to cancel or correct.")

        XCTAssertTrue(store.endFasting(at: start.addingTimeInterval(172_800)), "Exactly 48 hours is the inclusive upper bound.")
        XCTAssertEqual(store.fastingEntries.last?.durationSeconds, 172_800)
        XCTAssertNil(store.fastingStartedAt)
    }

    func testCancellingAnActiveFastingLogDoesNotCreateHistory() {
        let store = AppStore()
        let start = Date(timeIntervalSince1970: 2_000_000)
        store.startFasting(at: start)
        store.cancelFasting()

        XCTAssertNil(store.fastingStartedAt)
        XCTAssertTrue(store.fastingEntries.isEmpty)
        XCTAssertFalse(store.endFasting(at: start.addingTimeInterval(3_600)))
    }
}
