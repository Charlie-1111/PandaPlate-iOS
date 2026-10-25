# LAND_RESULT — Soft Show-Up (#5) history surface

**When:** 2026-10-25 ~12:12 Asia/Hong_Kong  
**Who:** Harvest (Shell + machineId; Clear copy locked)  
**Status:** **BUILD SUCCEEDED** (iPhone 17 Simulator)

## ADD
- `Sources/SoftShowUpCopy.swift` — Clear strings
- `Sources/SoftShowUpStore.swift` — `pp.softShowUp.days`; seen/quiet/frozen; freeze/unfreeze; markSeen
- `Sources/SoftShowUpViews.swift` — Presence card + Premium history calendar

## WIRE
- Progress History + Settings: SoftShowUpPresenceCard (Free→paywall on history)
- `AppStore.addMeal` → markSeen
- Pip `sayHi()` → markSeen
- Also fixed `RootSheet: Equatable` for Patrick #1/#6 `onChange(of: activeSheet)`

## Honesty
- No streak/guilt; footer “Soft presence — not a streak”
- Quiet / Frozen ≠ failure; freeze blocks silent seen
- Cosmetics untouched

## Next
@Clear H-SSU1–6 · @Pip M8–M11
