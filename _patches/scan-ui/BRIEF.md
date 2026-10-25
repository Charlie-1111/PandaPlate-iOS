# FoodScanSheet — §03 Snap.Check.Log land brief

**Owner:** Patrick (Mac land) · **Pip motion-check after LAND** · **Clear honesty locks hold**  
**Prepared:** 2026-10-24 ~17:56 Asia/Hong_Kong (box; Mac offline)  
**Do not:** invent nutrition, ship fake mid-spin macros, wire cosmetics (Charlie Manus tomorrow — PAUSED)

Source brief: `/workspace/pandaplate-orient/docs/scan-ui-video-match.md`  
Design: `DESIGN_BOARD.png` §03 · cream/coral chrome · BitePal-style camera → result

---

## Goal

Replace scaffold FoodScanSheet chrome with camera-first “Snap your meal” → analyzing (Pip thinking) → “Looks delicious.” editable result → save → Pip cheer — **without** touching FoodScanClient / ScanQuotaStore / PremiumAccess honesty paths.

## File touch list (Mac: `/Users/charlie/Projects/PandaPlate-iOS`)

| Action | Path | Notes |
|--------|------|--------|
| **REPLACE / merge** | `Sources/.../FoodScanSheet.swift` (exact folder: find with `rg -l FoodScanSheet`) | Use sketch as structure; keep existing bindings to client/quota/premium/consent/cheer |
| **ADD** (optional, cleaner) | same module: `ScanCameraChrome.swift` | Viewfinder + shutter + mode tabs from sketch |
| **ADD** (optional) | same module: `ScanAnalyzingBeat.swift` | Pip Thinking / soft progress — **no macros** |
| **ADD** (optional) | same module: `ScanResultCard.swift` | “Looks delicious.” card chrome |
| **DO NOT TOUCH** | `FoodScanClient.swift` | Server proxy only; consent payload; no invent |
| **DO NOT TOUCH** | `ScanQuotaStore.swift` | Free 3/day |
| **DO NOT TOUCH** | `PremiumAccess.swift` | Paywall on exhaust |
| **DO NOT TOUCH** | Server / keys / `~/.pandaplate/DEEPSEEK_API_KEY` | Never in app |
| **DO NOT TOUCH** | Cosmetics / Little World 1+6 | PAUSED — Charlie Manus |

### Asset names (already in catalog — reuse)

`PP_PipThinking` (analyzing), `PP_PipCelebrate` / `PP_PipLove` (cheer — existing PASS), optionally `PP_PipScanner` on camera chrome.  
Backgrounds: cream via `PPColor.cream` — not garden for scan sheet.

### PPColor tokens (match existing PandaPlate; do not invent new palette)

From landed Pip ritual chrome: `cream`, `ink`, `muted`, `card`, `line`, `coralInk`, `peach`.  
If Mac has more (e.g. `softGreen` for AI badge), use those; otherwise soft green `#5B8F6B`-class only for **real** AI badge.

---

## Land steps (when Mac reconnects)

1. **Pull live file** — open current `FoodScanSheet.swift`; note Step enum, consent toggle, `runScan`, save, cheer hooks, quota gate line numbers (honesty audit 2026-10-24).
2. **Copy package onto Mac** — from box: `/workspace/pandaplate-patches/scan-ui/` → e.g. `~/Downloads/pandaplate-scan-ui/` via CopyFromBox / AirDrop / shared folder.
3. **Diff, don’t blind overwrite** — merge sketch phases into existing sheet:
   - Keep: `FoodScanClient.scan(...)`, consent `@State`, quota check before call, paywall present, nil→blank kcal, scan-again resets consent, save → Pip cheer.
   - Swap: UI chrome for `.camera` / `.analyzing` / `.result` (and consent overlay that doesn’t kill camera feel).
4. **Add helper files** if preferred (sketches are self-contained views; wire as private structs in same file if XcodeGen/project.yml needs a one-file land).
5. **project.yml / Xcode** — if new `.swift` files: add under Sources target (or paste helpers into `FoodScanSheet.swift` to skip project edit).
6. **Build**
   ```bash
   cd /Users/charlie/Projects/PandaPlate-iOS
   # Prefer project’s usual path — examples:
   xcodegen generate   # if using XcodeGen
   xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 16' build
   ```
   Adjust scheme/destination to whatever the repo already uses.
7. **Simulator smoke** — consent → shutter (or PhotosPicker) → analyzing (Pip Thinking, **no** kcal flash) → result (AI badge only if server values) → blank kcal stays blank → Save → cheer. Exhaust free quota → paywall.
8. Hand **CHECKLIST.md** to Pip for motion + Clear honesty verify.

---

## Honesty checklist (must remain true after polish)

- [ ] Consent required **every** scan (UI + `"consent": true` payload); scan-again resets.
- [ ] No DeepSeek / API key in app / Info.plist / project.yml.
- [ ] App → Server `POST …/v1/scan` only; continuous live via Server env.
- [ ] Unknown calories stay **nil** / blank editor — never `0` invent; errors clear candidate.
- [ ] Free 3/day + Premium unlimited unchanged.
- [ ] Editable before save; Save separate from Scan.
- [ ] Analyzing beat shows **Pip Thinking / soft progress only** — never fake macros mid-spin.
- [ ] “✨ AI estimate” badge **only** when server returned real nutrition values.
- [ ] Reduce Motion → static Pip images (no bounce), same as PipWorldDashboard.

---

## Success for this package

Patrick can land board §03 chrome with **minimal rewrite**: helpers optional, main sketch maps 1:1 to existing client/quota/consent/cheer. Cosmetics out of scope. Live line-level diff still needs Mac `FoodScanSheet.swift` open (see report).
