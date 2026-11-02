import Foundation
import Combine

/// Pip's Little World meter (0–4). Opt-in only; missed/quiet days never change hearts.
/// Food classification, calories, and saving a meal never add or remove hearts.
@MainActor
final class PipHeartsStore: ObservableObject {
    static let shared = PipHeartsStore()
    static let maxHearts = 4
    static let heartsKey = "pandaplate.pipHearts.count"
    static let optInKey = "pandaplate.pipHearts.optInEnabled"
    static let lastEvaluatedDayKey = "pandaplate.pipHearts.lastNoShowEvaluatedDay"
    static let lastFoodLogDayKey = "pandaplate.pipHearts.lastFoodLogDay" // Legacy storage key; no longer affects hearts.
    static let lastDecayDayKey = "pandaplate.pipHearts.lastDecayDay" // Legacy storage key; no longer read.
    static let maximumDaysToEvaluate = SoftShowUpStore.historyCapDays

    private let defaults: UserDefaults
    private let calendar: Calendar

    @Published private(set) var hearts: Int
    @Published private(set) var isOptInEnabled: Bool

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        if defaults.object(forKey: Self.heartsKey) == nil {
            defaults.set(Self.maxHearts, forKey: Self.heartsKey)
        }
        hearts = min(Self.maxHearts, max(0, defaults.integer(forKey: Self.heartsKey)))
        isOptInEnabled = defaults.bool(forKey: Self.optInKey)
    }

    func setOptInEnabled(_ enabled: Bool) {
        isOptInEnabled = enabled
        defaults.set(enabled, forKey: Self.optInKey)
        if enabled && defaults.object(forKey: Self.heartsKey) == nil {
            hearts = Self.maxHearts
            defaults.set(hearts, forKey: Self.heartsKey)
        }
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

    /// Legacy hook retained for call-site compatibility. Hearts never decay for missed or quiet days.
    func refreshDecayIfNeeded(now: Date = Date(), showUpDays: [SoftShowUpDay] = []) {
        _ = now
        _ = showUpDays
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
