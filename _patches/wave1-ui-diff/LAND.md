# PandaPlate ≠ BitePal — Waves 1–3 LAND

**Branch:** `wave1-ui-diff`  
**Base (before):** `ccf19dd` — Respect Reduce Motion for main tab switches  
**Wave 1 tip:** `7054731`  
**Waves 2–3 tip:** `fa7842e`  
**Remote:** `origin/wave1-ui-diff`  
**PR draft URL:** https://github.com/Charlie-1111/PandaPlate-iOS/pull/new/wave1-ui-diff  

**Builds:**  
- Wave 1 Debug iPhone 18 Pro / iOS 27.0 `CODE_SIGNING_ALLOWED=NO` → **SUCCEEDED** (`/tmp/PandaPlate-wave1-dd`)  
- Waves 2–3 Debug same destination → **SUCCEEDED** (`/tmp/PandaPlate-wave23-dd`)

## Wave 1 — files ↔ items

| Item | Files |
|---|---|
| Tokens cream/orange/forest; demote mint/powder-blue/condensed | `DesignSystem.swift` |
| Soft Show-Up Home chip | `SoftShowUpStore/Copy/Views.swift`, `MainShellView.swift`, `AppStore.swift`, `WorkoutPickerLogView.swift` |
| Free scans remaining | `ScanQuotaStore.swift`, `FoodScanSheet.swift` |
| Tab cream + orange FAB + Reduce Motion | `MainShellView.swift` |

## Wave 2 — files ↔ items

| Item | Files |
|---|---|
| Soft scan motion (consent→progress→editable USDA; no confetti) | `FoodScanSheet.swift` |
| Home plate stack + Plate Story one-liners | `AppStore.swift` (`MealEntry.plateStory`), `MainShellView.swift` (`PlateStoryCard`), `FoodScanSheet.swift` |
| Pip coach empty/first-run | `PipCoachCopy.swift`, `MainShellView.swift`, `FoodScanSheet.swift` |
| Paywall honesty | `PremiumAccess.swift` (unlimited scans benefit; removed false “scanning unavailable”) |
| Reduce Motion tab/content | `MainShellView.swift` |

## Wave 3 — files ↔ items

| Item | Files |
|---|---|
| Persona-aware Pip coaching library | `PipCoachCopy.swift` (PipStyle switch) |
| Offline/local-first Profile | `MainShellView.swift` (`localFirstCard`) |
| Empty-state polish | Home coach card; `StatsSessionDashboard` empty + Pip |
| History grouping “Today’s plates” | `StatsSessionDashboard.swift`, Progress “Plates logged” tile |
| VoiceOver Pip + streak + scan quota | `DesignSystem` PipMascot; SoftShowUp chip/presence; scan quota chips |
| Screenshot-ready moments | cream/orange chrome, Soft Show-Up chip, plate stack, scan quota, honest paywall — no Team ID / ASC invent |

## Constraints kept

SIWA-only · no Google · no neon · no heart meter / confetti / outfits shop · no new servers · StoreKit IDs unchanged · PipHearts UI not surfaced on Home.

## Incomplete / non-blockers

- Tab labels still Home / Challenges / Stats (plan allowed keeping existing; not renamed to Home/Pip/+/Progress/Profile).
- Manual meal sheet does not yet offer Plate Story field (scan path + model do).
- Some non-shell screens still hardcode `forestDeep` buttons.
- Parked unrelated WIP: branch `wip-field-journal-local` @ `1fef152`.

## Plate Code PR blurb

Wave 1–3 differentiation from BitePal: cream/#C45C3E chrome, Soft Show-Up Home chip, scan quota, soft consent→USDA edit flow, Plate Story stack, persona Pip coach, honest Premium copy, local-first Profile, history plate grouping, VO pass. Simulator Debug green on iPhone 18 Pro / 27.0.
