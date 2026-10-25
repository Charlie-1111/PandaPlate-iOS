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

    func testQuietDayLosesOneHeartButSeenAndFrozenDaysDoNot() {
        let calendar = utcCalendar()
        let yesterday = date(2026, 10, 24, calendar: calendar)
        let twoDaysAgo = date(2026, 10, 23, calendar: calendar)
        let today = date(2026, 10, 25, calendar: calendar)
        let priorDayKey = PipHeartsStore.dayStamp(twoDaysAgo, calendar: calendar)
        let yesterdayKey = PipHeartsStore.dayStamp(yesterday, calendar: calendar)

        let quietDefaults = isolatedDefaults()
        quietDefaults.set(PipHeartsStore.maxHearts, forKey: PipHeartsStore.heartsKey)
        quietDefaults.set(priorDayKey, forKey: PipHeartsStore.lastEvaluatedDayKey)
        let quietStore = PipHeartsStore(defaults: quietDefaults, calendar: calendar)
        quietStore.refreshDecayIfNeeded(now: today, showUpDays: [])
        XCTAssertEqual(quietStore.hearts, PipHeartsStore.maxHearts - 1)

        let seenDefaults = isolatedDefaults()
        seenDefaults.set(PipHeartsStore.maxHearts, forKey: PipHeartsStore.heartsKey)
        seenDefaults.set(priorDayKey, forKey: PipHeartsStore.lastEvaluatedDayKey)
        let seenStore = PipHeartsStore(defaults: seenDefaults, calendar: calendar)
        seenStore.refreshDecayIfNeeded(
            now: today,
            showUpDays: [SoftShowUpDay(dateKey: yesterdayKey, kind: .seen)]
        )
        XCTAssertEqual(seenStore.hearts, PipHeartsStore.maxHearts)

        let frozenDefaults = isolatedDefaults()
        frozenDefaults.set(PipHeartsStore.maxHearts, forKey: PipHeartsStore.heartsKey)
        frozenDefaults.set(priorDayKey, forKey: PipHeartsStore.lastEvaluatedDayKey)
        let frozenStore = PipHeartsStore(defaults: frozenDefaults, calendar: calendar)
        frozenStore.refreshDecayIfNeeded(
            now: today,
            showUpDays: [SoftShowUpDay(dateKey: yesterdayKey, kind: .frozen)]
        )
        XCTAssertEqual(frozenStore.hearts, PipHeartsStore.maxHearts)
    }

    func testRepeatedForegroundRefreshCannotChargeTheSameDayTwice() {
        let defaults = isolatedDefaults()
        let calendar = utcCalendar()
        defaults.set(PipHeartsStore.maxHearts, forKey: PipHeartsStore.heartsKey)
        defaults.set(PipHeartsStore.dayStamp(date(2026, 10, 23, calendar: calendar), calendar: calendar), forKey: PipHeartsStore.lastEvaluatedDayKey)
        let store = PipHeartsStore(defaults: defaults, calendar: calendar)
        let today = date(2026, 10, 25, calendar: calendar)

        store.refreshDecayIfNeeded(now: today, showUpDays: [])
        store.refreshDecayIfNeeded(now: today, showUpDays: [])
        XCTAssertEqual(store.hearts, PipHeartsStore.maxHearts - 1)
    }
}
