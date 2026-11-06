# Wave 4 — Visual polish (files → checklist)

Baseline: PR #3 tip `9c4dc48` (Waves 1–3 + cleanup). Wave 4 only — no Wave 5 features, no ASC invent, StoreKit IDs unchanged.

| # | Item | Files |
|---|------|-------|
| 1 | Typography rhythm + Dynamic Type (chips) | `Sources/DesignSystem.swift` (`PPType` scale + `chip`), `Sources/SoftShowUpViews.swift`, `Sources/MainShellView.swift` (`PlateStoryCard`, tab labels), `Sources/OnboardingFlowView.swift` |
| 2 | 4/8/12/16/24 spacing density | `Sources/DesignSystem.swift` (`PPSpacing` + `xLarge`/`tabContentTop`), Home/Pip/Progress/Profile stacks in `Sources/MainShellView.swift`, `Sources/StatsSessionDashboard.swift` |
| 3 | Shared warm soft card elevation on cream | `Sources/DesignSystem.swift` (`PPElevation`, `ppWarmCardChrome`, `PPCard`), `PlateStoryCard`, Soft Show-Up chip, paywall cards, scan result meal header |
| 4 | SF Symbol weight/size + orange selected tab / white-on-orange FAB | `Sources/MainShellView.swift` (`PPIcon.tabPointSize` 22 regular→medium; FAB white plus on orange) |
| 5 | Tab switch + FAB press + Reduce Motion | `Sources/DesignSystem.swift` (`PPMotion.tabContentTransition`, `PPFABPressStyle`), `Sources/MainShellView.swift` shell transitions + FAB style |
| 6 | Empty-state polish (Pip + Soft show-up CTA) | `Sources/DesignSystem.swift` (`PPSoftEmptyCoach`), Home empty in `MainShellView`, Progress empty in `StatsSessionDashboard` |
| 7 | Scan result sheet + Plate Story parity | `Sources/FoodScanSheet.swift` (`ScanResultCardView`: honesty first, warm card, Plate Story helper + focus stroke, orange Save) |
| 8 | Light paywall + onboarding visual pass | `Sources/PremiumAccess.swift` (`PremiumPaywallView`: shorter hero, cream stage, Restore coral, honest list, no strikethrough), `OnboardingFlowView.swift`, `PandaPlateCategorizedOnboardingFlow.swift` (leaf/paw icons; no heart chrome) |

**Out of scope (held):** Wave 5 Plate Story share / weekly Soft Show-Up recap; ASC; new IAP; DEVELOPMENT_TEAM invent.
