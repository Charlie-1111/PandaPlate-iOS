import XCTest
@testable import PandaPlate

final class FastingLogDurationTests: XCTestCase {
    func testDurationAcceptsPositiveIntervalsUpToTwoDays() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertEqual(FastingLogDuration.seconds(startedAt: start, endedAt: start.addingTimeInterval(1)), 1)
        XCTAssertEqual(FastingLogDuration.seconds(startedAt: start, endedAt: start.addingTimeInterval(172_800)), 172_800)
    }

    func testDurationRejectsZeroNegativeAndOverLimitIntervals() {
        let start = Date(timeIntervalSince1970: 1_000_000)

        XCTAssertNil(FastingLogDuration.seconds(startedAt: start, endedAt: start))
        XCTAssertNil(FastingLogDuration.seconds(startedAt: start, endedAt: start.addingTimeInterval(-1)))
        XCTAssertNil(FastingLogDuration.seconds(startedAt: start, endedAt: start.addingTimeInterval(172_801)))
    }

    func testElapsedClockAndRecordSummaryFormatting() {
        XCTAssertEqual(FastingLogDuration.clockText(seconds: 3_661), "01:01:01")
        XCTAssertEqual(FastingLogDuration.clockText(seconds: 93_600), "26:00:00")
        XCTAssertEqual(FastingLogDuration.summaryText(seconds: 38), "38s")
        XCTAssertEqual(FastingLogDuration.summaryText(seconds: 3_661), "1h 1m")
        XCTAssertEqual(FastingLogDuration.summaryText(seconds: -1), "0s")
    }
}
