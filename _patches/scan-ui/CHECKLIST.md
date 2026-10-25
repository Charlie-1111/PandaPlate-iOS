# Post-LAND verify — FoodScanSheet §03 polish

**For:** Pip (motion) + Clear (honesty) after Patrick lands on Mac  
**Repo:** `/Users/charlie/Projects/PandaPlate-iOS`  
**Out of scope:** Cosmetics / Little World 1+6 (Charlie Manus — PAUSED)

---

## A. Pip motion bar (camera → progress → result → cheer)

Run on Simulator with Reduce Motion **OFF**, then again **ON**.

| # | Beat | Expect | Pass? |
|---|------|--------|-------|
| M1 | Entry | + / Food opens camera-first “Snap your meal” cream/coral chrome — not a plain form | ☐ |
| M2 | Viewfinder | Soft guide: “Keep the whole plate in view.” Circular/rounded frame with coral guide | ☐ |
| M3 | Shutter | Large coral shutter centered; Photos (gallery) left; flash layout right (stub OK) | ☐ |
| M4 | Mode tabs | Photo / Search / Barcode layout; Photo primary (coral). Search/Barcode stub copy OK | ☐ |
| M5 | Consent | Pre-shutter / overlay — camera chrome still feels present; toggle required; Continue disabled until on | ☐ |
| M6 | Analyzing | Pip **Thinking** (`PP_PipThinking`) + soft ProgressView; **zero** kcal/macros/ingredients on screen | ☐ |
| M7 | Result | “Looks delicious.” card; dish editable; portion/meal editable; ingredients list | ☐ |
| M8 | AI badge | Shows **only** when server returned nutrition; hidden when all nil / error path | ☐ |
| M9 | Blank kcal | Unknown calories render blank (“—” / empty), never `0` | ☐ |
| M10 | Save → cheer | Existing Pip Celebrate/Love beat fires; Done dismisses | ☐ |
| M11 | Reduce Motion | Analyzing + cheer use **static** Pip images — no bounce/pulse | ☐ |
| M12 | Footer copy | Camera: “You can review everything before saving.” Result: “Photo estimates can vary” | ☐ |

**Motion notes (Pip):** soft, not scaffold-y; shutter should feel primary; analyzing must not look like a fake macro reveal.

---

## B. Clear honesty gates (must stay PASS)

Cross-check against prior audit (`pandaplate-honesty-audit.md` 2026-10-24). Polish is chrome-only.

| # | Gate | How to verify | Pass? |
|---|------|---------------|-------|
| H1 | Consent every scan | Scan → save → Scan again: consent resets / overlay returns; payload still `"consent": true` | ☐ |
| H2 | No key in app | `rg -n 'DEEPSEEK_API_KEY|sk-' Sources Info.plist project.yml` → none (error strings OK) | ☐ |
| H3 | Server proxy only | Scan hits `…/v1/scan` via FoodScanClient; no direct DeepSeek from app | ☐ |
| H4 | unknown ≠ 0 | Force nil calories response (or mock): editor blank; save stores nil not 0 | ☐ |
| H5 | Failures clear candidate | Kill Server mid-scan: returns to camera, no stale macros on analyzing/result | ☐ |
| H6 | Free 3/day | Exhaust 3 free → paywall; Premium path unlimited unchanged | ☐ |
| H7 | Editable before save | Can change name/portion/kcal/ingredients; Save separate control | ☐ |
| H8 | No invent mid-spin | Screenshot analyzing frame: no numbers that look like nutrition | ☐ |
| H9 | AI badge honesty | Nil nutrition → no “AI estimate” badge | ☐ |

---

## C. Build smoke (Patrick)

```bash
cd /Users/charlie/Projects/PandaPlate-iOS
# scheme/destination: use repo standard
xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 16' build
```

- [ ] Build succeeds with merged sheet (+ optional helpers registered in project.yml / target)
- [ ] Simulator: consent → photo → analyzing → result → save → cheer
- [ ] Device caveat unchanged: Server `127.0.0.1` needs Simulator or LAN bind

---

## Sign-off

| Role | Name | Date (Asia/Hong_Kong) | Result |
|------|------|------------------------|--------|
| Land | Patrick | | ☐ LAND complete |
| Motion | Pip | | ☐ PASS / ☐ FAIL notes: |
| Honesty | Clear | | ☐ PASS / ☐ FAIL notes: |

Cosmetics: **do not** start — wait Charlie Manus assets.
