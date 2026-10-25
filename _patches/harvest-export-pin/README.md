# harvest-export-pin package (box prep — Mac offline)

Ready-to-merge **Premium Harvest** sketches: session CSV export + share, and pin USDA favorites.

**Ship order:** AFTER scan UI §03 polish (`../scan-ui/`). Cosmetics PAUSED.

| File | Role |
|------|------|
| `BRIEF.md` | Land steps, file touch list, CSV/pin contracts, honesty checklist |
| `WeekLogExport.swift.sketch` | Session CSV builder + `UIActivityViewController` share + SwiftUI button |
| `USDAFavoritesStore.swift.sketch` | UserDefaults pin store (cap ~20, dedupe `fdcId`) + pin UI notes for FoodScanSheet |
| `CHECKLIST.md` | Clear honesty + Pip smoke verify after LAND |

**Constraints (Clear PASS):** session-only label; blank kcal stays blank; no BMI/deficit/goal columns; pin never invents nutrition; consent still required on scan; Free → paywall; Premium local unlock OK until StoreKit.

**Still needs on Mac:** live `AppStore` meal/workout field names, `PremiumAccess` wiring, host chrome for Export + Favorites list, Search/FDC row payloads for pin.

**Do not:** invent nutrition, add API keys, wire cosmetics, land before §03 scan polish.
