import Foundation
import Combine

/// Pip's Little World meter (0–4). A prior day without a show-up mark can remove one heart.
/// Food classification, calories, and saving a meal never add or remove hearts.
@MainActor
final class PipHeartsStore: ObservableObject {
    static let shared = PipHeartsStore()
    static let maxHearts = 4
    static let heartsKey = "pandaplate.pipHearts.count"
    static let lastEvaluatedDayKey = "pandaplate.pipHearts.lastNoShowEvaluatedDay"
    static let lastFoodLogDayKey = "pandaplate.pipHearts.lastFoodLogDay" // Legacy storage key; no longer affects hearts.
    static let lastDecayDayKey = "pandaplate.pipHearts.lastDecayDay" // Legacy storage key; no longer read.
    static let maximumDaysToEvaluate = SoftShowUpStore.historyCapDays

    private let defaults: UserDefaults
    private let calendar: Calendar

    @Published private(set) var hearts: Int

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if defaults.object(forKey: Self.heartsKey) == nil {
            defaults.set(Self.maxHearts, forKey: Self.heartsKey)
        }
        hearts = min(Self.maxHearts, max(0, defaults.integer(forKey: Self.heartsKey)))
    }

    /// Status line is descriptive; it never moralizes food or implies a medical score.
    var softStatusLine: String {
        switch hearts {
        case 4: return "Pip has all four hearts"
        case 3: return "Pip has 3 hearts"
        case 2: return "Pip has 2 hearts"
        case 1: return "Pip has 1 heart"
        default: return "Pip is resting quietly"
        }
    }

    /// Evaluate completed days only. A seen or explicitly frozen day is not a no-show.
    /// The first run seeds yesterday, so installing/updating the app never creates a retroactive loss.
    func refreshDecayIfNeeded(now: Date = Date(), showUpDays: [SoftShowUpDay] = []) {
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        let yesterdayKey = Self.dayStamp(yesterday, calendar: calendar)

        guard let lastKey = defaults.string(forKey: Self.lastEvaluatedDayKey),
              let lastEvaluated = Self.date(fromDayStamp: lastKey, calendar: calendar) else {
            defaults.set(yesterdayKey, forKey: Self.lastEvaluatedDayKey)
            return
        }

        let lastDay = calendar.startOfDay(for: lastEvaluated)
        guard lastDay < yesterday else { return }

        var seenKinds: [String: SoftShowUpDayKind] = [:]
        for day in showUpDays { seenKinds[day.dateKey] = day.kind }
        var cursor = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? yesterday
        var quietDays = 0
        var evaluated = 0
        while cursor <= yesterday && evaluated < Self.maximumDaysToEvaluate {
            let key = Self.dayStamp(cursor, calendar: calendar)
            let kind = seenKinds[key]
            if kind != .seen && kind != .frozen {
                quietDays += 1
            }
            evaluated += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        if quietDays > 0 {
            hearts = max(0, hearts - quietDays)
            defaults.set(hearts, forKey: Self.heartsKey)
        }
        defaults.set(yesterdayKey, forKey: Self.lastEvaluatedDayKey)
    }

    /// Legacy call retained for source compatibility. Meal saves never change hearts.
    func noteFoodLogSaved(now: Date = Date()) { }

    static func dayStamp(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func date(fromDayStamp value: String, calendar: Calendar) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
