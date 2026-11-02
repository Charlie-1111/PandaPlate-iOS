import XCTest
@testable import PandaPlate

@MainActor
final class PipHomeAndHeartsSafetyTests: XCTestCase {
    private func isolatedDefaults() -> UserDefaults {
        let suite = "PipHomeAndHeartsSafetyTests.\(UUID().uuidString)"
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

    func testHomeLoopResourcesMapToBundledMoments() {
        XCTAssertEqual(PipLook.homeLoopResource(for: .idle), "PP_PipLife_Idle")
        XCTAssertEqual(PipLook.homeLoopResource(for: .waving), "PP_PipLife_Wave")
        XCTAssertEqual(PipLook.homeLoopResource(for: .cheering), "PP_PipLife_Celebrate")
    }

    func testCostumeLookKeepsStillWithMotionNotBaseLoopFrames() {
        XCTAssertEqual(PipLook.scarf.homeStillAsset(for: .idle), "PP_PipScarf")
        XCTAssertEqual(PipLook.scarf.homeStillAsset(for: .waving), "PP_PipScarf")
    }

    func testQuietDaysNeverReduceHearts() {
        let calendar = utcCalendar()
        let yesterday = date(2026, 10, 24, calendar: calendar)
        let twoDaysAgo = date(2026, 10, 23, calendar: calendar)
        let today = date(2026, 10, 25, calendar: calendar)
        let priorDayKey = PipHeartsStore.dayStamp(twoDaysAgo, calendar: calendar)

        let defaults = isolatedDefaults()
        defaults.set(PipHeartsStore.maxHearts, forKey: PipHeartsStore.heartsKey)
        defaults.set(priorDayKey, forKey: PipHeartsStore.lastEvaluatedDayKey)
        let store = PipHeartsStore(defaults: defaults, calendar: calendar)
        store.refreshDecayIfNeeded(now: today, showUpDays: [])
        store.refreshDecayIfNeeded(now: today, showUpDays: [])
        XCTAssertEqual(store.hearts, PipHeartsStore.maxHearts)
    }

    func testHeartsOptInDefaultsOff() {
        let store = PipHeartsStore(defaults: isolatedDefaults())
        XCTAssertFalse(store.isOptInEnabled)
    }
}
