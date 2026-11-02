import XCTest
@testable import PandaPlate

final class SessionMealRecentsTests: XCTestCase {
    func testRecentsAreNewestFirstDeduplicatedAndSessionBounded() {
        let entries = [
            meal("Oatmeal", calories: 280, seconds: 100),
            meal("Tea", calories: nil, seconds: 200),
            meal(" oatmeal ", calories: nil, seconds: 300),
            meal("Toast", calories: 0, seconds: 250),
            meal("   ", calories: 100, seconds: 400)
        ]

        let recent = SessionMealRecents.latestUniqueMeals(from: entries)
        XCTAssertEqual(recent.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }, ["oatmeal", "Toast", "Tea"])
        XCTAssertNil(recent[0].calories, "The latest copy of a meal name owns its value; unknown must not borrow an older estimate.")
        XCTAssertEqual(recent[1].calories, 0, "An explicit zero remains distinct from unknown.")
        XCTAssertTrue(recent.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    func testRecentsClampCallerLimitToVisibleCapAndHandleZero() {
        let entries = (0..<12).map { meal("Meal \($0)", calories: nil, seconds: TimeInterval($0)) }
        XCTAssertEqual(SessionMealRecents.latestUniqueMeals(from: entries, limit: 99).count, SessionMealRecents.maximumVisibleItems)
        XCTAssertTrue(SessionMealRecents.latestUniqueMeals(from: entries, limit: 0).isEmpty)
        XCTAssertTrue(SessionMealRecents.latestUniqueMeals(from: entries, limit: -1).isEmpty)
    }

    func testCopyDraftPreservesKnownOrUnknownCaloriesButDoesNotCarryPhoto() {
        let unknownWithPhoto = meal("Soup", calories: nil, seconds: 1, imageData: Data([1, 2, 3]))
        let knownZero = meal("Water", calories: 0, seconds: 2)

        let unknownDraft = SessionMealRecents.reviewDraft(copying: unknownWithPhoto)
        let zeroDraft = SessionMealRecents.reviewDraft(copying: knownZero)

        XCTAssertEqual(unknownDraft, SessionMealReviewDraft(name: "Soup", calories: nil))
        XCTAssertEqual(zeroDraft, SessionMealReviewDraft(name: "Water", calories: 0))
    }

    func testCaloriesInputKeepsBlankUnknownAndAcceptsExplicitZero() {
        XCTAssertTrue(SessionMealRecents.isValidCaloriesInput(""))
        XCTAssertTrue(SessionMealRecents.isValidCaloriesInput("  "))
        XCTAssertNil(SessionMealRecents.parsedCalories(from: ""))
        XCTAssertEqual(SessionMealRecents.parsedCalories(from: "0"), 0)
        XCTAssertEqual(SessionMealRecents.parsedCalories(from: "10000"), 10_000)
        XCTAssertFalse(SessionMealRecents.isValidCaloriesInput("10001"))
        XCTAssertFalse(SessionMealRecents.isValidCaloriesInput("-1"))
        XCTAssertFalse(SessionMealRecents.isValidCaloriesInput("1.5"))
        XCTAssertFalse(SessionMealRecents.isValidCaloriesInput("abc"))
    }

    func testMealNameValidationTrimsAndEnforcesLength() {
        XCTAssertTrue(SessionMealRecents.isValidMealName("  Soup  "))
        XCTAssertFalse(SessionMealRecents.isValidMealName("   "))
        XCTAssertFalse(SessionMealRecents.isValidMealName(String(repeating: "a", count: 121)))
    }

    private func meal(_ name: String, calories: Int?, seconds: TimeInterval, imageData: Data? = nil) -> MealEntry {
        MealEntry(
            name: name,
            calories: calories,
            time: Date(timeIntervalSince1970: seconds),
            imageData: imageData
        )
    }
}
