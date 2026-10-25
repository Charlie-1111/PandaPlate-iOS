import Foundation
import SwiftUI

/// Informational BMI from user-entered height + weight only.
/// WHO adult categories; calm non-shaming copy. Never locks Premium.
enum BMICategory: String {
    case underweight
    case healthy
    case overweight
    case obese

    /// Calm labels — no guilt / health-grade copy.
    var badgeTitle: String {
        switch self {
        case .underweight: return "Lower range"
        case .healthy: return "Common range"
        case .overweight: return "Nearer edge"
        case .obese: return "Higher range"
        }
    }

    var calmCopy: String {
        switch self {
        case .underweight:
            return "This sits in a lower adult BMI range from the height and weight you entered. Informational only — not a diagnosis."
        case .healthy:
            return "You’re in a commonly cited adult BMI range. It’s one reference point, not a verdict."
        case .overweight:
            return "This sits near the edge of the commonly cited adult range. Informational only — not medical advice."
        case .obese:
            return "This sits in a higher adult BMI range. PandaPlate won’t use it to sell Premium or judge you."
        }
    }

    /// Soft severity chrome: yellow = near-edge; soft coral = far. Never system/alarm red.
    var badgeFill: Color {
        switch self {
        case .healthy:
            return BitePalColor.selectGreen
        case .overweight:
            // Soft amber / yellow — medium / near-edge band
            return Color(red: 0.93, green: 0.78, blue: 0.28)
        case .underweight, .obese:
            // Soft coral — far band (not UIColor.systemRed)
            return Color(red: 0.94, green: 0.58, blue: 0.52)
        }
    }

    var badgeText: Color {
        switch self {
        case .healthy: return .white
        case .overweight: return Color(red: 0.28, green: 0.20, blue: 0.08)
        case .underweight, .obese: return .white
        }
    }

    /// Soft card wash — preference soft tint over alarm red (spark non-block).
    var softCardTint: Color {
        switch self {
        case .healthy:
            return BitePalColor.selectFill.opacity(0.35)
        case .overweight:
            return Color(red: 0.98, green: 0.94, blue: 0.78).opacity(0.85)
        case .underweight, .obese:
            return Color(red: 0.98, green: 0.90, blue: 0.88).opacity(0.90)
        }
    }

    static func compute(heightCm: Int, weightKg: Double) -> (value: Double, category: BMICategory)? {
        guard (100...230).contains(heightCm), weightKg >= 25, weightKg <= 300 else { return nil }
        let meters = Double(heightCm) / 100.0
        guard meters > 0 else { return nil }
        let bmi = weightKg / (meters * meters)
        let category: BMICategory
        switch bmi {
        case ..<18.5: category = .underweight
        case 18.5..<25.0: category = .healthy
        case 25.0..<30.0: category = .overweight
        default: category = .obese
        }
        return (bmi, category)
    }
}

enum ActivityCalorieMode: String, CaseIterable, Identifiable {
    case smart
    case addAll

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smart: return "Smart mode"
        case .addAll: return "Add all calories"
        }
    }

    var detail: String {
        switch self {
        case .smart: return "Preference stored: only count activity above your usual level when we personalize later"
        case .addAll: return "Preference stored: count all logged activity when we personalize later — not a live calorie budget"
        }
    }

    var isRecommended: Bool { self == .smart }
}
