import Foundation

/// Common activity choices displayed by the expanded workout logger (BitePal-like breadth).
enum WorkoutActivityType: String, CaseIterable, Identifiable {
    case casualWalk = "Casual walk"
    case briskWalk = "Brisk walk"
    case powerWalk = "Power walk"
    case walkingUphill = "Walking uphill"
    case running = "Running"
    case jogging = "Jogging"
    case cycling = "Cycling"
    case indoorCycling = "Indoor cycling"
    case elliptical = "Elliptical"
    case rowing = "Rowing"
    case stairClimber = "Stair climber"
    case strength = "Strength"
    case hiit = "HIIT"
    case yoga = "Yoga"
    case pilates = "Pilates"
    case stretching = "Stretching"
    case swimming = "Swimming"
    case hiking = "Hiking"
    case dancing = "Dance"
    case jumpRope = "Jump rope"
    case martialArts = "Martial arts"
    case sports = "Sports"
    case basketball = "Basketball"
    case soccer = "Soccer"
    case tennis = "Tennis"
    case skating = "Skating"
    case other = "Other"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .casualWalk, .briskWalk, .walkingUphill: "figure.walk"
        case .powerWalk, .running, .jogging: "figure.run"
        case .cycling, .indoorCycling: "bicycle"
        case .elliptical: "figure.elliptical"
        case .rowing: "figure.rower"
        case .stairClimber: "figure.stair.stepper"
        case .strength: "dumbbell.fill"
        case .hiit: "flame.fill"
        case .yoga, .pilates, .stretching: "figure.mind.and.body"
        case .swimming: "figure.pool.swim"
        case .hiking: "mountain.2.fill"
        case .dancing: "music.note"
        case .jumpRope: "figure.jumprope"
        case .martialArts: "figure.boxing"
        case .sports, .basketball, .soccer, .tennis: "sportscourt.fill"
        case .skating: "figure.skating"
        case .other: "ellipsis.circle.fill"
        }
    }
}

enum WorkoutDurationChoice: Hashable {
    case preset(Int)
    case custom
}

enum WorkoutFeatureRules {
    /// Quick chips; full minute chooser covers 1…maximumCustomDuration.
    static let presetDurations = [10, 15, 20, 30, 45, 60, 90]
    static let maximumCustomDuration = 1_440
    static let maximumActivityNameLength = 60
    static let maximumSessionEntries = 100

    static func activityType(forLoggedName name: String) -> WorkoutActivityType {
        let trimmed = name.replacingOccurrences(of: "Health · ", with: "")
        return WorkoutActivityType.allCases.first {
            $0 != .other && $0.rawValue.caseInsensitiveCompare(trimmed) == .orderedSame
        } ?? .other
    }

    static func resolvedActivityName(
        for type: WorkoutActivityType,
        customName: String
    ) -> String? {
        let candidate = type == .other
            ? customName.trimmingCharacters(in: .whitespacesAndNewlines)
            : type.rawValue

        guard !candidate.isEmpty,
              candidate.count <= maximumActivityNameLength,
              candidate.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }
        return candidate
    }

    static func resolvedDuration(
        for choice: WorkoutDurationChoice,
        customMinutes: String
    ) -> Int? {
        switch choice {
        case .preset(let minutes):
            return presetDurations.contains(minutes) ? minutes : nil
        case .custom:
            let digits = customMinutes.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !digits.isEmpty,
                  digits.unicodeScalars.allSatisfy({ (48...57).contains(Int($0.value)) }),
                  let minutes = Int(digits),
                  (1...maximumCustomDuration).contains(minutes) else {
                return nil
            }
            return minutes
        }
    }
    static func makeEntry(
        activity: String,
        durationMinutes: Int,
        time: Date = Date(),
        activeEnergyKcal: Int? = nil
    ) -> WorkoutEntry? {
        let safeActivity = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        // Honesty: only keep kcal from a real source (caller). Never invent. nil = Unknown (≠ 0).
        let safeKcal = activeEnergyKcal.flatMap { (1...20_000).contains($0) ? $0 : nil }
        guard !safeActivity.isEmpty,
              safeActivity.count <= maximumActivityNameLength,
              safeActivity.rangeOfCharacter(from: .controlCharacters) == nil,
              (1...maximumCustomDuration).contains(durationMinutes) else {
            return nil
        }
        return WorkoutEntry(
            activity: safeActivity,
            durationMinutes: durationMinutes,
            time: time,
            activeEnergyKcal: safeKcal
        )
    }
}
