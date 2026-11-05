// PipCoachCopy.swift — calm Pip coach lines (Wave 2–3). Never hungry/sad / heart meter / confetti.
import Foundation

@MainActor
enum PipCoachCopy {
    static func companion(_ store: AppStore) -> String {
        let name = store.companionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Pip" : name
    }

    /// Empty Home / first-run coach strip.
    static func emptyHome(store: AppStore) -> String {
        let pip = companion(store)
        switch store.pipStyle {
        case .cheerleader:
            return "\(pip)’s ready whenever you are — one honest plate starts the day."
        case .gentle:
            return "\(pip) can sit with you. Log a plate when it feels right — no rush."
        case .straightTalker:
            return "Nothing logged yet. Snap or note one plate when you’re ready."
        case .mindful:
            return "A quiet start. Notice what’s on your plate — \(pip) will keep you company."
        }
    }

    static func firstScanConsent(store: AppStore) -> String {
        let pip = companion(store)
        switch store.pipStyle {
        case .cheerleader:
            return "\(pip): you’ve got this — review the consent, then we’ll look together."
        case .gentle:
            return "\(pip) waits while you read the consent. Estimates stay editable."
        case .straightTalker:
            return "Consent every scan. Photo leaves the device only after you agree."
        case .mindful:
            return "Pause for consent. \(pip) prefers honesty over speed."
        }
    }

    static func freeTierEdge(remaining: Int, store: AppStore) -> String {
        let pip = companion(store)
        if remaining <= 0 {
            switch store.pipStyle {
            case .cheerleader:
                return "Free scans are used up for today. Manual notes still work — \(pip)’s proud you showed up."
            case .gentle:
                return "That’s today’s Free scans. You can still log by hand; Premium lifts the daily cap."
            case .straightTalker:
                return "Free Food Scan limit reached (3/day). Manual logging stays open."
            case .mindful:
                return "Quota rests until tomorrow. A written plate note is enough for \(pip)."
            }
        }
        switch store.pipStyle {
        case .cheerleader:
            return "\(remaining) Free scan\(remaining == 1 ? "" : "s") left today — \(pip)’s cheering quietly."
        case .gentle:
            return "\(remaining) of 3 Free scans left today."
        case .straightTalker:
            return "\(remaining) Free live scan\(remaining == 1 ? "" : "s") remaining today."
        case .mindful:
            return "\(remaining) scan\(remaining == 1 ? "" : "s") left on Free today — use them when the plate matters."
        }
    }

    static func afterSoftSave(store: AppStore) -> String {
        let pip = companion(store)
        switch store.pipStyle {
        case .cheerleader:
            return "Nice save — \(pip) nodded."
        case .gentle:
            return "Logged. \(pip) saw that."
        case .straightTalker:
            return "Saved to this session."
        case .mindful:
            return "Noted with care. \(pip) keeps the quiet."
        }
    }

    static func reduceMotionCaption(store: AppStore) -> String {
        "\(companion(store)) stays still while Reduce Motion is on."
    }

    static func offlineProfileBlurb(store: AppStore) -> String {
        "Meal, water, and movement logs stay on this device for the session. Food Scan needs network + consent; \(companion(store)) coaching never requires a game server."
    }

    static func historyPlatesHeader(count: Int) -> String {
        count == 0 ? "Today’s plates" : "Today’s plates · \(count)"
    }

    static func plateStoryPlaceholder(store: AppStore) -> String {
        switch store.pipStyle {
        case .cheerleader: return "Optional note — e.g. Tuesday noodles at home"
        case .gentle: return "Optional one-line plate story"
        case .straightTalker: return "Optional note (one line)"
        case .mindful: return "Optional: where / how this plate felt"
        }
    }
}
