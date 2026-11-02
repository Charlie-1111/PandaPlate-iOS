import XCTest
@testable import PandaPlate

@MainActor
final class PandaPlateChallengeAndHeartsTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let suite = "PandaPlateChallengeAndHeartsTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testAppIssuedChallengeProgressTracksActualSessionEntries() {
        let store = AppStore()
        XCTAssertEqual(PandaPlateChallengeProgress.mealNotes(in: store), 0)
        XCTAssertEqual(PandaPlateChallengeProgress.waterCups(in: store), 0)
        XCTAssertEqual(PandaPlateChallengeProgress.activities(in: store), 0)

        store.addMeal(name: "Lunch", calories: nil, imageData: nil)
        store.addWater(250)
        XCTAssertTrue(store.addWorkout(activity: "Casual walk", durationMinutes: 20))

        XCTAssertEqual(PandaPlateChallengeProgress.mealNotes(in: store), 1)
        XCTAssertEqual(PandaPlateChallengeProgress.waterCups(in: store), 1)
        XCTAssertEqual(PandaPlateChallengeProgress.activities(in: store), 1)
    }

    func testFirstEvaluationDoesNotChargeRetroactively() {
        let defaults = isolatedDefaults()
        let calendar = utcCalendar()
        let store = PipHeartsStore(defaults: defaults, calendar: calendar)
        store.refreshDecayIfNeeded(now: date(2026, 10, 25, calendar: calendar), showUpDays: [])
        XCTAssertEqual(store.hearts, PipHeartsStore.maxHearts)
    }

    func testMealSaveNeverChangesHearts() {
        let defaults = isolatedDefaults()
        let store = PipHeartsStore(defaults: defaults)
        store.noteFoodLogSaved()
        XCTAssertEqual(store.hearts, PipHeartsStore.maxHearts)
    }
}
