import Foundation

@MainActor
final class ScanQuotaStore: ObservableObject {
    static let shared = ScanQuotaStore()
    static let freeDailyLimit = 3

    private let defaults: UserDefaults
    private let dayKeyPrefix = "pandaplate.scanQuota.day."
    private let dayStampKey = "pandaplate.scanQuota.dayStamp"

    @Published private(set) var scansUsedToday: Int

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stamp = Self.todayStamp()
        if defaults.string(forKey: dayStampKey) != stamp {
            defaults.set(stamp, forKey: dayStampKey)
            defaults.set(0, forKey: dayKeyPrefix + stamp)
        }
        scansUsedToday = defaults.integer(forKey: dayKeyPrefix + stamp)
    }

    private static func todayStamp(calendar: Calendar = .current, now: Date = Date()) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let y = components.year ?? 0
        let m = components.month ?? 0
        let d = components.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func refreshDayIfNeeded() {
        let stamp = Self.todayStamp()
        if defaults.string(forKey: dayStampKey) != stamp {
            defaults.set(stamp, forKey: dayStampKey)
            defaults.set(0, forKey: dayKeyPrefix + stamp)
            scansUsedToday = 0
        }
    }

    func remainingFreeScans(isPremium: Bool) -> Int? {
        refreshDayIfNeeded()
        if isPremium { return nil }
        return max(0, Self.freeDailyLimit - scansUsedToday)
    }

    func canStartLiveScan(isPremium: Bool) -> Bool {
        refreshDayIfNeeded()
        if isPremium { return true }
        return scansUsedToday < Self.freeDailyLimit
    }

    /// Counts only successful live scans that returned a candidate.
    func recordSuccessfulLiveScan() {
        refreshDayIfNeeded()
        let stamp = Self.todayStamp()
        let next = min(10_000, scansUsedToday + 1)
        scansUsedToday = next
        defaults.set(next, forKey: dayKeyPrefix + stamp)
        defaults.set(stamp, forKey: dayStampKey)
    }

    var quotaSummaryLine: String {
        refreshDayIfNeeded()
        if PremiumAccess.shared.isPremium {
            return "Live scans: no daily limit while the scan server is connected."
        }
        return "Live scans today: \(scansUsedToday) of \(Self.freeDailyLimit) (Free), when the scan server is connected."
    }
}
