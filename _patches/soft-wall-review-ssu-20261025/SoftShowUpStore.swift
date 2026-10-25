// SoftShowUpStore.swift — Soft Show-Up presence (#5)
// HONESTY: days Pip saw you — never a streak. Quiet/Frozen ≠ failure.

import Foundation
import Combine
import SwiftUI

enum SoftShowUpDayKind: String, Codable, Equatable {
    case seen
    case quiet
    case frozen
}

struct SoftShowUpDay: Codable, Equatable, Identifiable {
    /// Local calendar day key yyyy-MM-dd
    var dateKey: String
    var kind: SoftShowUpDayKind
    var id: String { dateKey }
}

@MainActor
final class SoftShowUpStore: ObservableObject {
    static let shared = SoftShowUpStore()
    static let defaultsKey = "pp.softShowUp.days"
    static let historyCapDays = 90

    @Published private(set) var days: [SoftShowUpDay] = []

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        load()
        ensureTodayQuietIfNeeded()
    }

    // MARK: Derived

    var seenCount: Int { days.filter { $0.kind == .seen }.count }

    var countHeadline: String {
        if seenCount == 0 { return SoftShowUpCopy.emptyDay0 }
        if isSeenToday { return SoftShowUpCopy.countOne }
        return SoftShowUpCopy.countMany(seenCount)
    }

    var todayKey: String { Self.dateKey(for: Date(), calendar: calendar) }

    var todayKind: SoftShowUpDayKind? { days.first(where: { $0.dateKey == todayKey })?.kind }

    var isSeenToday: Bool { todayKind == .seen }
    var isFrozenToday: Bool { todayKind == .frozen }

    /// Last 28 days newest-last for calm calendar (oldest → newest).
    var recentHistory: [SoftShowUpDay] {
        let keys = (0..<28).compactMap { offset -> String? in
            guard let d = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return Self.dateKey(for: d, calendar: calendar)
        }.reversed()
        return keys.map { key in
            if let existing = days.first(where: { $0.dateKey == key }) {
                return existing
            }
            // Past day with no record = Quiet day (not failure)
            if key == todayKey { return SoftShowUpDay(dateKey: key, kind: .quiet) }
            return SoftShowUpDay(dateKey: key, kind: .quiet)
        }
    }

    // MARK: Mutations

    /// Call after first honest meal save or Pip ritual. Frozen day stays frozen (no silent unfreeze).
    @discardableResult
    func markSeen(at date: Date = Date()) -> SoftShowUpDayKind {
        let key = Self.dateKey(for: date, calendar: calendar)
        if let existing = days.first(where: { $0.dateKey == key }), existing.kind == .frozen {
            return .frozen
        }
        upsert(SoftShowUpDay(dateKey: key, kind: .seen))
        return .seen
    }

    func freezeToday() {
        upsert(SoftShowUpDay(dateKey: todayKey, kind: .frozen))
    }

    func unfreezeToday() {
        // Unfreeze → quiet until they show up again (no invent seen)
        upsert(SoftShowUpDay(dateKey: todayKey, kind: .quiet))
    }

    // MARK: Persist

    private func upsert(_ day: SoftShowUpDay) {
        var next = days.filter { $0.dateKey != day.dateKey }
        next.append(day)
        next.sort { $0.dateKey < $1.dateKey }
        if next.count > Self.historyCapDays {
            next = Array(next.suffix(Self.historyCapDays))
        }
        days = next
        persist()
    }

    private func ensureTodayQuietIfNeeded() {
        guard todayKind == nil else { return }
        // Do not invent "seen"; leave absent until markSeen / freeze — history maps absent→quiet
    }

    private func load() {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return }
        if let decoded = try? JSONDecoder().decode([SoftShowUpDay].self, from: data) {
            days = decoded.sorted { $0.dateKey < $1.dateKey }
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(days) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    static func dateKey(for date: Date, calendar: Calendar) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }
}
