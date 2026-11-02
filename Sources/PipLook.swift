import Foundation
import Combine
import SwiftUI

/// Little World costume looks — Base free; six Premium looks.
enum PipLook: String, CaseIterable, Identifiable, Codable {
    case base
    case scarf
    case gardener
    case chefHat
    case nap
    case cheerLove
    case explorer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .base: return "Base"
        case .scarf: return "Scarf"
        case .gardener: return "Gardener"
        case .chefHat: return "Chef"
        case .nap: return "Nap"
        case .cheerLove: return "Cheer"
        case .explorer: return "Explorer"
        }
    }

    /// Catalog imageset name for the look still.
    var stillAssetName: String {
        switch self {
        case .base: return "PP_PipBase"
        case .scarf: return "PP_PipScarf"
        case .gardener: return "PP_PipGardener"
        case .chefHat: return "PP_PipChefHat"
        case .nap: return "PP_PipNap"
        case .cheerLove: return "PP_PipCheerLove"
        case .explorer: return "PP_PipExplorer"
        }
    }

    /// Free can always use base; other looks need Premium.
    var requiresPremium: Bool { self != .base }

    /// Frame-sequence folder name used for a ritual phase (also matches the legacy APNG basename).
    static func lifeLoopResource(for phase: PipRitualPhase, celebrateLove: Bool) -> String {
        switch phase {
        case .welcome:
            return "PP_PipLife_Wave"
        case .saidHi:
            return celebrateLove ? "PP_PipLife_Love" : "PP_PipLife_Celebrate"
        case .napping:
            return "PP_PipLife_Nap"
        }
    }

    /// Reduce Motion / missing-loop still for a ritual phase (look costume when no life still).
    func stillForPhase(_ phase: PipRitualPhase, celebrateLove: Bool) -> String {
        switch phase {
        case .welcome:
            return stillAssetName
        case .saidHi:
            // Cheer look already is love-pose; otherwise keep selected costume still.
            return stillAssetName
        case .napping:
            // Prefer nap look still if wearing nap; else costume still (not legacy PP_PipRest).
            return stillAssetName
        }
    }
}

enum PipRitualPhase: Equatable {
    case welcome
    case saidHi
    case napping
}

/// Home hero moments — idle loop, one-shot wave on tap, one-shot cheer after a confirmed meal save.
enum PipHomeMoment: Equatable {
    case idle
    case waving
    case cheering
}

extension PipLook {
    /// Frame-sequence folder name under `PipLife/Frames` for this Home moment.
    static func homeLoopResource(for moment: PipHomeMoment) -> String {
        switch moment {
        case .idle: return "PP_PipLife_Idle"
        case .waving: return "PP_PipLife_Wave"
        case .cheering: return "PP_PipLife_Celebrate"
        }
    }

    func homeStillAsset(for moment: PipHomeMoment) -> String {
        guard self == .base else { return stillAssetName }
        switch moment {
        case .idle: return stillAssetName
        case .waving: return "PP_PipGentle"
        case .cheering: return "PP_PipCelebrate"
        }
    }

    static func homeAccessibilityLabel(for moment: PipHomeMoment, companionName: String) -> String {
        switch moment {
        case .idle:
            return "\(companionName) in the forest garden"
        case .waving:
            return "\(companionName) waves hello in the forest garden"
        case .cheering:
            return "\(companionName) cheers your saved meal"
        }
    }
}

@MainActor
final class PipLookStore: ObservableObject {
    static let shared = PipLookStore()
    static let defaultsKey = "pandaplate.selectedPipLookId"

    private let defaults: UserDefaults

    @Published var selectedLook: PipLook {
        didSet { defaults.set(selectedLook.rawValue, forKey: Self.defaultsKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.defaultsKey),
           let look = PipLook(rawValue: raw) {
            self.selectedLook = look
        } else {
            self.selectedLook = .base
        }
        // If a premium look was saved but Premium lapsed, fall back to base.
        reconcileWithPremium()
    }

    func reconcileWithPremium() {
        if selectedLook.requiresPremium && !PremiumAccess.shared.isPremium {
            selectedLook = .base
        }
    }

    /// Returns true if selection applied; false if Premium required (caller should soft paywall).
    @discardableResult
    func select(_ look: PipLook) -> Bool {
        if look.requiresPremium && !PremiumAccess.shared.isPremium {
            return false
        }
        selectedLook = look
        return true
    }
}
