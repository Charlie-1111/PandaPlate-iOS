// SoftShowUpCopy.swift — Clear repair copy (#5) locked 2026-10-25
// NEVER: streak / streak broken / don't lose / guilt / BMI-deficit framing

import Foundation

enum SoftShowUpCopy {
    static let title = "Soft Show-Up"
    static let countLabel = "Days Pip saw you"
    static let countOne = "Pip saw you today"
    static func countMany(_ n: Int) -> String { "Pip saw you \(n) days" }
    static let emptyDay0 = "Say hi to Pip — tomorrow you'll have a day to protect"
    static let footer = "Soft presence — not a streak"

    static let napTitle = "Pip's napping"
    static let napBody = "No rush. Come back when you're ready — Pip will be here."
    static let repairTitle = "Soft repair"
    static let repairBody = "You showed up again. That's enough — Pip's glad you're here."
    static let freezeTitle = "Freeze day"
    static let freezeBody = "Pause Soft Show-Up for today. Pip holds your place — no guilt."
    static let freezeCTA = "Freeze today"
    static let unfreezeCTA = "Unfreeze"

    static let historyTitle = "Soft Show-Up history"
    static let historySubtitle = "Days Pip saw you — calm calendar, no red X's"
    static let historySeen = "Pip saw you"
    static let historyMissed = "Quiet day"
    static let historyFrozen = "Frozen"
    static let historyEmpty = "No days yet — first honest log or Pip ritual starts the count"
}
