# Premium Harvest — week/session export + pin USDA favorites

**Owner:** Patrick (Mac land) · **Clear honesty locks hold** · **Pip smoke after LAND**  
**Prepared:** 2026-10-24 ~17:58 Asia/Hong_Kong (box; Mac offline)  
**Ship order:** **AFTER** scan UI §03 polish lands (`/workspace/pandaplate-patches/scan-ui/`). Cosmetics / Little World 1+6: **PAUSED** (Charlie Manus) — do not wire.

Clear-gated brief: **PASS** — implement honesty constraints below verbatim. Do **not** invent nutrition, BMI/deficit/goal columns, or StoreKit until that slice is scheduled.

---

## Goal

Draft ready-to-merge Harvest slices:

1. **Week / session CSV export + share sheet** — session-only label; blank kcal stays blank; share via `UIActivityViewController`.
2. **Pin USDA favorites** — local UserDefaults store (`fdcId` + description + optional `lastCalories`); Free → paywall; Premium local unlock OK until StoreKit; pin never invents nutrition; consent still required on every scan.

---

## File touch list (Mac: `/Users/charlie/Projects/PandaPlate-iOS`)

| Action | Path | Notes |
|--------|------|--------|
| **ADD** | `Sources/.../WeekLogExport.swift` | CSV builder + share presenter from sketch |
| **ADD** | `Sources/.../USDAFavoritesStore.swift` | Pin store (cap ~20, dedupe `fdcId`) |
| **WIRE** | Settings / Soft Show-Up / log chrome (find host with `rg -n 'Premium\|export\|week'`) | Export entry: Premium-gated; session-only copy |
| **WIRE (light)** | `FoodScanSheet.swift` (post–§03 polish) | Pin affordance on USDA / search result rows — see pin UI notes in sketch |
| **KEEP** | `FoodScanClient.swift` / Server | No invent; consent payload unchanged |
| **KEEP** | `ScanQuotaStore.swift` / `PremiumAccess.swift` | Free → paywall; local unlock disclosed until StoreKit |
| **DO NOT TOUCH** | Cosmetics / Little World 1+6 | PAUSED |
| **DO NOT ADD** | BMI / deficit / goal / “calories remaining” columns in CSV | Honesty residual (audit gate 8) — export must not reintroduce theater |

### CSV contract (locked)

| Column | Meaning |
|--------|---------|
| `type` | `meal` / `workout` / other live log kinds — map from AppStore entries |
| `time` | ISO8601 or local `yyyy-MM-dd'T'HH:mm` — match live log timestamps |
| `name_or_activity` | Dish name or workout activity |
| `portion_or_duration` | Portion label or duration string |
| `calories_or_blank` | Numeric string **or empty** — never invent `0` for unknown |
| `notes` | Optional free text; empty OK |

- **Filename:** `PandaPlate-session-YYYYMMDD.csv` (session date, not “week archive” fiction).
- **UI label:** session-only — e.g. “Export this session” / “Session CSV” — never imply full historical cloud sync.
- **Share:** `UIActivityViewController` with temp file URL (delete after present if repo pattern allows).

### Pin contract (locked)

```
PinnedUSDAFavorite { fdcId: Int, description: String, lastCalories: Int? }
```

- UserDefaults key: e.g. `pp.usda.favorites` (confirm no collision on Mac).
- Cap **~20**; **dedupe by `fdcId`** (move-to-front on re-pin).
- `lastCalories` only when user/server already had a value — **never invent**.
- Pin is Premium; Free tap → existing paywall. Local Premium unlock OK until StoreKit lands.

---

## Land steps (when Mac reconnects — after scan-ui §03)

1. **Confirm scan UI §03 landed** — FoodScanSheet polish merged; Clear re-check still PASS on consent / nil≠0 / quota.
2. **Pull live types** — open `AppStore` meal/workout entry shapes, `PremiumAccess.isPremium` (or equivalent), any existing Settings / history chrome.
3. **Copy package onto Mac** — `/workspace/pandaplate-patches/harvest-export-pin/` → e.g. `~/Downloads/pandaplate-harvest-export-pin/`.
4. **Add `WeekLogExport.swift` + `USDAFavoritesStore.swift`** — register in `project.yml` / Xcode target (or paste into an existing Premium helpers file if one-file land preferred).
5. **Wire export entry** — Premium gate → build CSV from **current session** logs → write temp file → present `UIActivityViewController`. Session-only banner/copy on the button or sheet.
6. **Wire pin** — on USDA result row (Search stub or future FDC path): pin button → `USDAFavoritesStore.pin(...)`. Favorites list surface (Settings or Search tab) reads store; tapping a pin **fills name only** (and calories **only if** `lastCalories != nil`) — never fabricates macros. **Starting a scan from a pin still requires consent.**
7. **Build**
   ```bash
   cd /Users/charlie/Projects/PandaPlate-iOS
   xcodegen generate   # if using XcodeGen
   xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 16' build
   ```
8. Hand **CHECKLIST.md** to Clear (honesty) + Pip (smoke).

---

## Honesty checklist (must remain true)

- [ ] Export labeled **session-only** — no “full history / cloud backup” implication.
- [ ] CSV columns exactly the six listed — **no** BMI / deficit / goal / remaining columns.
- [ ] Blank / nil calories → empty CSV field — **never** `0`.
- [ ] Pin stores only `{fdcId, description, lastCalories?}` — no invented nutrition.
- [ ] Consent still required every scan (including after picking a favorite).
- [ ] Free → paywall on export + pin; Premium local unlock OK; StoreKit later.
- [ ] No DeepSeek / API key in app; USDA IDs are catalog refs only.
- [ ] Cosmetics untouched.

---

## Success for this package

Patrick can land Harvest export + pin with **minimal rewrite**: two new files + light wiring into Settings / FoodScanSheet post–§03. Live AppStore entry field names still need Mac align. Cosmetics out of scope.
