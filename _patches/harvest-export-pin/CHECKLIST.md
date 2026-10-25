# Post-LAND verify — Premium Harvest (export + pin)

**For:** Clear (honesty) + Pip (smoke) after Patrick lands on Mac  
**Repo:** `/Users/charlie/Projects/PandaPlate-iOS`  
**Prerequisite:** scan UI §03 polish already LAND + prior Clear PASS  
**Out of scope:** Cosmetics / Little World 1+6 (Charlie Manus — PAUSED) · StoreKit

---

## A. Clear honesty gates (must PASS)

| # | Gate | How to verify | Pass? |
|---|------|---------------|-------|
| H1 | Session-only label | Export control copy says session (e.g. “Export this session”); footnote does **not** claim full history / cloud backup | ☐ |
| H2 | CSV columns locked | Open shared file: header exactly `type,time,name_or_activity,portion_or_duration,calories_or_blank,notes` — **no** BMI / deficit / goal / remaining | ☐ |
| H3 | unknown ≠ 0 | Log a meal with nil/blank kcal → CSV `calories_or_blank` cell empty (not `0`) | ☐ |
| H4 | Filename | Shared file named `PandaPlate-session-YYYYMMDD.csv` (local session day) | ☐ |
| H5 | Share path | Uses `UIActivityViewController` (Files / Messages / Mail appear) | ☐ |
| H6 | Pin shape | UserDefaults `pp.usda.favorites` (or landed key) stores only `fdcId`, `description`, optional `lastCalories` — no invented macros | ☐ |
| H7 | Pin no invent | Pin a row **without** energy → `lastCalories` absent/nil; favorites UI shows “kcal unknown” / blank — not `0` | ☐ |
| H8 | Consent intact | Pick a favorite → start photo scan: consent overlay / toggle still required; payload `"consent": true` | ☐ |
| H9 | Free → paywall | Free account: Export + Pin → existing Premium paywall; no silent unlock | ☐ |
| H10 | Premium local OK | Local Premium unlock can export + pin until StoreKit; disclosed as today | ☐ |
| H11 | Cap + dedupe | Pin 21st unique `fdcId` → list length ≤ 20; re-pin same id → single entry moved to front | ☐ |
| H12 | No key / no invent mid-flow | `rg -n 'DEEPSEEK_API_KEY\|sk-' Sources Info.plist project.yml` → none; pin/export paths don’t call DeepSeek | ☐ |
| H13 | Scan honesty unchanged | Consent / nil≠0 / Free 3/day / AI badge rules from §03 still PASS | ☐ |
| H14 | Cosmetics untouched | No Little World 1+6 wiring in this land | ☐ |

---

## B. Pip smoke (export + pin UX)

Run Simulator, Reduce Motion OFF then ON (export/pin are mostly static — confirm no janky chrome).

| # | Beat | Expect | Pass? |
|---|------|--------|-------|
| M1 | Export entry | Finds Export in Settings / Soft Show-Up / log chrome; cream/coral consistent with app | ☐ |
| M2 | Free tap | Paywall presents (existing PremiumAccess UI) | ☐ |
| M3 | Premium share | Activity sheet opens with CSV; cancel dismisses cleanly | ☐ |
| M4 | Pin control | Pin icon on USDA/search row; fill ↔ outline toggle | ☐ |
| M5 | Favorites list | Pinned items list; swipe unpin; select prefills name (kcal only if known) | ☐ |
| M6 | Prefill → scan | After prefill, scanning still hits consent → analyzing → result path (no skip) | ☐ |
| M7 | Empty session | Export with zero rows → CSV header-only file still shares OK | ☐ |

**Motion notes (Pip):** soft, not scaffold-y; pin should feel secondary to Scan/Save; export footnote readable.

---

## C. Build smoke (Patrick)

```bash
cd /Users/charlie/Projects/PandaPlate-iOS
# scheme/destination: use repo standard
xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] `WeekLogExport.swift` + `USDAFavoritesStore.swift` in target / project.yml
- [ ] Build succeeds
- [ ] Simulator: Free paywall + Premium export share + pin/unpin + consent still on scan
- [ ] Spot-check CSV in Files / Quick Look

---

## Sign-off

| Role | Name | Date (Asia/Hong_Kong) | Result |
|------|------|------------------------|--------|
| Land | Patrick | | ☐ LAND complete (after §03) |
| Honesty | Clear | | ☐ PASS / ☐ FAIL notes: |
| Smoke | Pip | | ☐ PASS / ☐ FAIL notes: |

Cosmetics: **do not** start — wait Charlie Manus assets.  
StoreKit: later slice — local Premium unlock remains disclosed.
