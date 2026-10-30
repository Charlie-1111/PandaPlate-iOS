# PandaPlate App Store Ship Checklist

**Audited:** 2026-10-31 ~00:27 Asia/Hong_Kong  
**Machine:** Mac `5af73cd8-a9b8-4d2d-adcc-f997e8cfc839`  
**Path:** `/Users/charlie/Projects/PandaPlate-iOS`  
**Bundle:** `com.charlie.pandaplate`  
**GitHub:** https://github.com/Charlie-1111/PandaPlate-iOS  
**Git HEAD:** `8b31ca0` (same as `origin/main`) + **33 uncommitted local changes** (23 modified, 10 untracked)

---

## Project snapshot

| Area | Finding |
|------|---------|
| Sources | **43** Swift files under `Sources/` |
| Tests | **7** unit (`Tests/`) + **2** UI (`UITests/`) = 9 |
| Server/ | Local Node proxy (`src/server.mjs`, `auth.mjs`, tests). Dev-only; binds loopback. No real `.env` (only `.env.example`). |
| Assets | `Assets.xcassets` (~44 entries) + `Resources/` (welcome mp4, pip gif, PipLife/) |
| AppIcon | Single 1024×1024 `AppIcon.png`, no alpha — **complete** for modern iOS single-size set |
| Screenshots | `outputs/AppStoreScreenshots/`: 1 launch + 3 dated (Home / Workout / Fasting). **Thin for ASC.** |
| Marketing posts | Mac Desktop `Pandaplate marketing/phone-ready/` already has **01–11** (incl. 08–11). Box `/workspace/pandaplate-ads/phone-ready/` matches. No copy needed. |
| Entitlements (as on disk) | `com.apple.developer.healthkit` = true; `com.apple.developer.healthkit.access` = `[]`. **No other entitlements claimed.** |
| Scheme | `PandaPlate` (targets app + tests + UITests) |

### Privacy usage keys (Info.plist / project.yml)

| Key / capability | Status |
|------------------|--------|
| `NSCameraUsageDescription` | **Present** |
| `NSHealthShareUsageDescription` | **Present** |
| `NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription` | **Missing** — code uses `PhotosPicker` + `UIImagePickerController` `.photoLibrary` fallback |
| Health write (`NSHealthUpdateUsageDescription`) | Not present (matches “read only” copy) |
| Notifications usage string | N/A for local alerts (code: `ReminderNotifications` / `UNUserNotificationCenter`) — no push entitlement |
| `NSUserTrackingUsageDescription` / ATT | **Absent** (good if no tracking SDKs; confirm ASC nutrition labels) |
| App Privacy Manifest (`PrivacyInfo.xcprivacy`) | **On disk** at repo root + `project.yml` resources — @Plate Code must `xcodegen generate` before archive (Patrick audit predated this) |

### StoreKit / Premium / DEBUG

- `PremiumAccess.swift` + StoreKit 2: product IDs `com.charlie.pandaplate.premium.monthly` / `.yearly`
- Prices from StoreKit only; empty products → honest “not configured” message
- `#if DEBUG` unlock (`unlockForTesting` / `lockForTesting` / Settings toggle via `hasDebugUnlock`) — **stripped / ignored in Release** (Release clears leftover `debugPremiumUnlock`)
- No `#if DEBUG` purchase shortcut that ships in Release build paths reviewed

### Legal URLs

- `LegalDocuments.swift`: **in-app** Terms of Use + Privacy Notice bodies only (`privacyPolicyURL` still `nil` until Pages 200)
- Support: `rigsby-dayf8v@bot.cue.im` (mailto) — also wired into hosted `docs/privacy.html`
- `docs/privacy.html`: **replaced 2026-10-31** with Charlie’s finished Manus Privacy Policy HTML (UTF-8). Awaiting GitHub Pages host → `https://charlie-1111.github.io/PandaPlate-iOS/privacy.html` (do not paste into ASC until HTTP 200).
- **No `docs/terms.html`** — Terms remain in-app only; ASC Terms URL still Charlie if required.

### Secrets in Sources

- **No provider API keys / secrets hardcoded in `Sources/`**
- Session Bearer tokens set at runtime from proxy auth (expected)
- `Info.plist`: Google iOS client ID present; **`GIDServerClientID` = `REPLACE_WITH_GOOGLE_SERVER_CLIENT_ID`** (placeholder)
- `PandaPlateProxyBaseURL` = `http://127.0.0.1:8787` (dev loopback)

### Build attempt

1. `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Release` → **FAIL** (no iPhone 16 simulator on this Mac; destinations are iPhone 17 / 18 / Air, etc.)
2. Fallback: `-destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -configuration Release` → **SUCCESS** (`** BUILD SUCCEEDED **`). Simulator signing “Sign to Run Locally” only — **not** a device/ASC archive proof.

---

## Ready

- [x] Release **simulator** build succeeds (iPhone 17, OS 27.0)
- [x] AppIcon 1024×1024, no alpha
- [x] Bundle ID set: `com.charlie.pandaplate`
- [x] Deployment target iOS 17.0; phone-only (`TARGETED_DEVICE_FAMILY: 1`)
- [x] Camera + Health **share** usage strings present; HealthKit entitlement matches read-only story
- [x] StoreKit 2 wiring + DEBUG premium bypass gated out of Release
- [x] No DeepSeek/USDA/OpenAI keys in app Sources
- [x] In-app Terms + Privacy Notice copy present (local)
- [x] `ITSAppUsesNonExemptEncryption` = false
- [x] Unit + UI test targets exist (9 Swift test files)
- [x] Marketing phone-ready 01–11 already on Desktop

---

## Needs code fix (before submit)

1. **Photo library privacy string** — add `NSPhotoLibraryUsageDescription` (and AddUsage if saving) to `Info.plist` / `project.yml`; otherwise library path can crash/reject on device.
2. **Production proxy URL** — replace `http://127.0.0.1:8787` with hosted **HTTPS** Worker/base URL (or disable scan networking entirely for v1 and hide live scan).
3. **`GIDServerClientID` / Google Sign-In — **DELETE per Charlie** (Code)** — set real Google **server/web** client ID or remove Google server-side session path for first ship.
4. **Hosted Privacy + Terms URLs** — publish pages and link them in-app + ASC App Privacy / Review notes (in-app-only may fail review expectations).
5. **App Privacy Manifest** — file present; run `xcodegen generate` so pbx includes it (do not re-add from scratch).
6. **Commit / tag ship snapshot** — 33 dirty files vs `origin/main`; archive from a clean committed tree so ASC binary matches GitHub.
7. **Remove or quarantine debug scan-base-URL UI** in Settings (`MainShellView` LAN / 127.0.0.1 hints) for Release if still user-visible.
8. **Session-only persistence** — README/legal admit data clears on quit; either ship as intentional MVP copy **or** add persistence before promising accounts/history.
9. **Food Scan honesty** — live recognition unavailable as production; ensure UI never implies working cloud scan without consent + working HTTPS backend.
10. **Sign in with Apple** — if account/gate requires sign-in, confirm SIWA capability + entitlement (currently entitlements file is HealthKit-only; do **not** invent — Charlie must add in Xcode/ASC if required).
11. **Device Release archive** — run Archive with real `DEVELOPMENT_TEAM` + distribution cert (project has no team id in `project.yml`); simulator success ≠ App Store binary.

---

## Charlie ASC only

- [ ] Apple Developer Program membership + App Store Connect app record for `com.charlie.pandaplate`
- [ ] Certificates / Profiles / `DEVELOPMENT_TEAM` in Xcode
- [ ] **In-App Purchase** products: `com.charlie.pandaplate.premium.monthly` + `.yearly` (auto-renewable), pricing, localizations, review screenshot
- [ ] Paid Apps / contracts, banking, tax
- [ ] App Privacy nutrition labels (Health, Photos, Camera, Purchases, Contact Info if email/sign-in)
- [ ] Age rating, content rights, export compliance (matches `ITSAppUsesNonExemptEncryption` false)
- [ ] **Privacy Policy URL** + **Terms URL** (hosted)
- [ ] Support URL / marketing URL
- [ ] App Store screenshots for required sizes (6.7" / 6.5" / etc.) — current `outputs/AppStoreScreenshots` is only 4 images, not a full set
- [ ] App Review notes: Health read-only, scan experimental/off, demo account if sign-in required
- [ ] Google Cloud OAuth clients restricted to production bundle + correct redirect / server client
- [ ] HealthKit capability enabled on App ID in Developer portal (matches entitlements)
- [ ] If Sign in with Apple used in build: enable capability on App ID + ASC
- [ ] Archive → Upload → submit with release version `1.0` (CFBundleShortVersionString) / build `1`

---

## Risks

| Risk | Why it matters |
|------|----------------|
| **Uncommitted local tree** | HEAD == origin/main but 33 local mods; easy to archive wrong tree or lose work. |
| **Prototype positioning** | README: no persistent history/sync; scan live route disabled; charts illustrative — Review may reject if metadata overclaims. |
| **Loopback proxy in Info.plist** | Shipping `127.0.0.1` is useless on device and looks unfinished. |
| **Placeholder Google server client** | Auth/session to proxy will fail; any leftover `REPLACE_WITH_*` is a reject smell. |
| **Missing photo library usage key** | Hard reject / crash when picking from library. |
| **No ASC IAP configured** | Paywall shows “products haven’t been configured”; Premium path dead until ASC products + agreements. |
| **Thin screenshots** | ASC upload will block without full device-size sets. |
| **No DEVELOPMENT_TEAM in project.yml** | Blocks reproducible CI/archive until Charlie sets team. |
| **Server not production** | Local Node + optional DeepSeek/China processing called out in Privacy Notice — do not enable live scan without hosted Worker + legal review. |
| **Git remote only initial commit** | Collaborators / backup of ship code not on GitHub until Charlie commits + pushes (do not push unless asked). |
| **HealthKit entitlement without portal match** | Archive/validation fails if App ID lacks HealthKit. |
| **DEBUG Settings toggles** | Safe in Release `#if DEBUG`, but verify Release binary has no unlock UI (spot-check Settings). |

---

## Top 10 ship blockers (priority)

1. Missing **`NSPhotoLibraryUsageDescription`** (and review library usage).
2. **Production HTTPS proxy** (or ship with live Food Scan fully disabled / hidden).
3. Replace **`GIDServerClientID` / Google Sign-In — **DELETE per Charlie** (Code)**; finish Google/Apple auth story for production.
4. Publish **hosted Privacy + Terms URLs** and wire ASC + app.
5. Configure **ASC subscription products** + Paid Apps agreement for StoreKit IDs already in code.
6. **Commit clean ship tree** (33 dirty files) and Archive with **DEVELOPMENT_TEAM** / distribution signing.
7. Produce **full App Store screenshot** set (current outputs insufficient).
8. Confirm **App ID capabilities** (HealthKit ± Sign in with Apple) match entitlements — entitlements file today is HealthKit-only.
9. Align **marketing/ASC copy** with prototype limits (no medical claims; scan unavailable; session data).
10. Add **app Privacy Manifest** / complete App Privacy answers; remove or gate any Release-visible **dev proxy URL** Settings controls.

---

## Commands used

```bash
# Failed (no sim):
xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Release build

# Succeeded:
xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -configuration Release build
# → ** BUILD SUCCEEDED **
```

**Checklist path:** `/workspace/pandaplate-ads/SHIP_CHECKLIST.md`  
**Also copied to Mac project:** `/Users/charlie/Projects/PandaPlate-iOS/SHIP_CHECKLIST.md` (if copy step ran)

*Do not invent entitlements. Do not push to GitHub unless Charlie asks.*


---

## Ship reconcile (Plate Ship · 2026-10-31 ~00:28 HKT)

Patrick Mac audit LAND folded in: Release sim **BUILD SUCCEEDED** (iPhone 17 / OS 27); 33 dirty files; marketing 01–11 already on Desktop.

**Code soft / clarify (Guard+Patrick)**
1. Photo library: PHPicker/`PhotosPicker` need **no** usage string; only if `CameraPhotoPicker` keeps `UIImagePickerController` `.photoLibrary` fallback → add `NSPhotoLibraryUsageDescription` **or** drop that fallback.
2. Settings proxy/LAN editor: Guard confirms `#if DEBUG` only — **not** a Release leak.

**Still P0 (do not archive)**
- Age `allowedAgeYears` → **LAND `13...100`** (verified tip)
- SIWA entitlement to match SIWA UI
- Hosted Privacy URL (Charlie Pages) — `docs/privacy.html` **replaced with Charlie Manus HTML**; Pages enable + 200 still Charlie
- Review notes locked **B** (`docs/REVIEW_NOTES.md`); matrix in `docs/SCREENSHOT_MATRIX.md`

Ship will not clear archive until age + SIWA + photo-library string + PrivacyInfo xgen + honest Release proxy story land.


---

## Charlie order (via Patrick · 2026-10-31 ~00:30 HKT)

1. **Hosted Privacy Policy** — Charlie’s Manus HTML now at `docs/privacy.html` (PLACEHOLDER_SUPPORT_EMAIL → `rigsby-dayf8v@bot.cue.im`). Push + enable GitHub Pages; ASC URL after live 200 → `https://charlie-1111.github.io/PandaPlate-iOS/privacy.html`.
2. **Production HTTPS Food Scan proxy** — still Charlie ops; until then review notes stay **B** (no production scan claim). Loopback `127.0.0.1:8787` is not ship-ready.
3. **Delete Google Sign-In entirely** — @Plate Code remove package / GID* / URL scheme / Sources; drop `GIDServerClientID` / Google Sign-In — **DELETE per Charlie** (Code) blocker once gone. Keep SIWA if still used.
4. **Real StoreKit payments only** — no fake/debug unlock in Release (Code: already stripped). Product IDs in code; ASC live IAP + IAP capability / `.storekit` for testing still required for “real” path (match shipping IAP — not invent).

**Also still P0 before Ship archive clear:** age `13...100`; SIWA entitlement if SIWA remains; photo-library string OR drop UIImagePicker library fallback; PrivacyInfo xcodegen’d; clean commit before archive.


## Status flip (Ship · ~00:31 HKT)
- **Age P0 CLOSED on tip:** `allowedAgeYears = 13...100` verified in `PandaPlateCategorizedOnboardingFlow.swift`.
- Guard legal/payments honesty LAND (SIWA-only copy in Legal/privacy/nutrition/review notes).
- **Google strip still open in Sources/Info.plist/project** — awaiting @Plate Code finish; Ship won’t treat GID blockers as cleared until package/UI/plist gone.
- ASC live IAP products still Charlie; review notes stay **B** until HTTPS proxy.


## Code LAND (~00:33 HKT) — Ship flips
- Age **`13...100`** + unit test passed → LAND
- SIWA entitlement `com.apple.developer.applesignin` + IAP/SIWA SystemCapabilities in `project.yml` → LAND (match shipping code)
- `Configuration.storekit` for monthly/yearly, scheme-wired → LAND (local); ASC live products still Charlie
- `xcodegen` + `PrivacyInfo.xcprivacy` in project → LAND
- Release sim SUCCEEDED after regen → LAND (sim only)
- `DEVELOPMENT_TEAM` still unset → Charlie
- Localhost proxy → still blocker; review notes **B**
- Google / `GIDServerClientID`: Patrick mid-strip — do not parallel-edit; GID row clears when strip LANDs (not by filling placeholder)


## Code update (~00:34 HKT)
- Photo-library usage string: **CLEARED** — `CameraPhotoPicker` camera-only; gallery via `PhotosPicker` (no UIImagePicker `.photoLibrary` fallback).
- Reminder: `GIDServerClientID` still listed by Code but Charlie ordered Google delete — Patrick mid-strip; treat as strip residual not a fill-in.


## Patrick LAND (~00:34 HKT) — Google gone
- Google Sign-In stripped end-to-end (package/plist/yml/Sources/UI). **GID*/Google rows → LAND CLEARED**
- Release sim iPhone 17 / iOS 27 BUILD SUCCEEDED (`.build/google-delete-release/`)
- StoreKit 2 purchase-only; DEBUG unlock stripped in Release
- Age `13...100`; PhotosPicker-only gallery path

**Still Charlie / Ship open before archive clear:** HTTPS Food Scan proxy (review notes **B** until then), `DEVELOPMENT_TEAM`, ASC live IAP products, hosted Privacy Policy URL (push `docs/privacy.html` + Pages 200), required screenshot sizes, clean commit/tag before archive.


## Guard final sweep LAND (~00:34 HKT)
Google/GID honesty cleared. Soft optional: dead `.google` cases in `PandaPlateProxyAuth` (no UI). **Not archive-clear:** hosted Privacy URL must 200; review notes **B** until HTTPS proxy. Charlie still: Team ID, ASC live IAP, screenshot sizes, clean commit.


## Patrick LAND (~00:36 HKT) — Privacy HTML
- Charlie Manus Privacy HTML at `docs/privacy.html` (support `rigsby-dayf8v@bot.cue.im`) — **on disk LAND**
- Hosted URL still **BLOCKED** until GitHub Pages (or other host) returns 200 — candidate `https://charlie-1111.github.io/PandaPlate-iOS/privacy.html` only after verify
- `GIDServerClientID` confirmed gone with Google — not open
- Ship archive still blocked: Pages 200, HTTPS proxy (notes **B**), Team ID, ASC live IAP, ASC screenshot sizes, clean commit


## Honesty sync (Guard · ~00:36 HKT) — Ship gate
`docs/privacy.html` currently describes Food Scan via **owner-hosted HTTPS proxy**, but tip is localhost and `docs/REVIEW_NOTES.md` is locked **B**. **No ASC Privacy URL paste / no archive clear** until either:
1. Production HTTPS proxy ships + notes flip to **A**, or
2. Privacy HTML Food Scan section softened to match in-app Legal (production recognition unavailable / test proxy only).
Also soft: avoid “tracking details” wording — prefer on-device activity/logs (nutrition tracking=No).

- Patrick softening `docs/privacy.html` Food Scan + tracking wording to match notes **B** before Pages paste.


## ~00:40 HKT
- Code: dead `.google` residuals removed; Sources Google-free; Release sim SUCCEEDED; proxy auth tests passed (5).
- Patrick: softened `docs/privacy.html` on disk (B-aligned); support **`lisbon-oondn8@bot.cue.im`** (was rigsby…). Honesty sync Food Scan claim → softened LAND pending Guard confirm.
- Hosted Privacy URL still open (no Pages). Archive still: Pages 200, HTTPS proxy or stay B, Team ID, ASC live IAP, screenshots, clean commit. Sync in-app `LegalDocuments.supportEmail` if mismatched.


## Guard LAND (~00:40 HKT)
- privacy.html honesty matches notes **B** → sync LAND
- `LegalDocuments.supportEmail` + nutrition sheet → **`lisbon-oondn8@bot.cue.im`** (mismatch CLOSED)
- Hosted Privacy URL still open until Pages 200


## ~00:45 HKT — HTTPS Worker
- Support email mismatch **CLOSED** (lisbon everywhere; no rigsby in Sources/docs)
- Cloudflare Worker deployed: `https://pandaplate-ai-proxy.charliengyt.workers.dev` (host responds; `/` → 404 as of check)
- **App tip NOT yet flipped:** `PandaPlateProxyAuth.defaultBaseURL` still `http://127.0.0.1:8787`; Info.plist has no workers.dev base yet; `REVIEW_NOTES` still locked **B**
- Ship: **do not** flip notes to **A** / clear HTTPS gate until tip `PandaPlateProxyBaseURL` (or default) points at Worker HTTPS and Guard confirms privacy.html Food Scan section matches **A**
- Still open: Pages 200, Team ID, ASC live IAP, screenshots, clean commit


## HTTPS tip (~00:47 HKT)
- App tip LAND: `PandaPlateProxyBaseURL` / `defaultBaseURL` = `https://pandaplate-ai-proxy.charliengyt.workers.dev` (Info.plist + yml + code); Release sim SUCCEEDED (Code)
- `docs/REVIEW_NOTES.md` already **A**
- `docs/privacy.html` describes owner-hosted HTTPS Food Scan + consent
- **Honesty BLOCKER remaining:** `Sources/LegalDocuments.swift` still says Food recognition / live scan **unavailable as a production service** / local test server — must sync to HTTPS+consent story before ASC paste / archive clear → @Plate Guard
- Still Charlie: Pages 200, Team ID, ASC live IAP, screenshots, clean commit


## Patrick LAND (~00:48 HKT) — HTTPS tip + notes A
- Tip HTTPS URL LAND (plist/yml/defaultBaseURL Worker)
- `REVIEW_NOTES` **A** LAND; `privacy.html` Food Scan HTTPS+consent LAND
- Debug localhost TextField `#if DEBUG` only
- **Still open honesty:** in-app `LegalDocuments` production-unavailable copy — await Guard sync before full honesty/archive clear
- Charlie: Pages 200, Team ID, ASC live IAP, screenshots, clean commit

- Patrick syncing in-app `LegalDocuments` Food Scan copy to HTTPS+consent (await LAND).


## Guard honesty gate CLEAR (~00:49 HKT)
- LegalDocuments Terms §4/§6 + Privacy §6 synced to HTTPS+consent+DeepSeek/USDA — **honesty row LAND**
- HTTPS tip + notes **A** + privacy.html aligned
- **Still open (Charlie/Ship):** Pages 200 Privacy URL, Team ID, ASC live IAP, ASC screenshots, clean commit before archive

## Guard Food Scan disclosure sync (~00:51 HKT)
- `LegalDocuments` already honesty **A** (HTTPS+consent+DeepSeek/USDA; no production-unavailable / test-proxy claims); support `lisbon-oondn8@bot.cue.im`
- Related UI disclosure strings synced: `FoodScanSheet` camera helper + consent overlay + free-limit error; `MainShellView` nutrition lock copy; `FoodScanClient` userMessage hedges no longer say “local server” as the production story
- Release sim **BUILD SUCCEEDED** (`.build/legal-honesty-a-release/`, iPhone 17 / iOS 27, `CODE_SIGNING_ALLOWED=NO`) — no DEVELOPMENT_TEAM invent; no git push
- Still Charlie/Ship open: Pages 200 Privacy URL, Team ID, ASC live IAP, ASC screenshots, clean commit before archive


## Patrick LAND (~00:52 HKT) — UI + Legal honesty A
LegalDocuments + FoodScanSheet + MainShellView + FoodScanClient disclosures synced to HTTPS+consent+DeepSeek/USDA. Legal sync row **CLEARED**. Honesty gate remains clear pending Guard re-verify. Charlie still: Pages 200, Team ID, live IAP, screenshots, clean commit.


## Guard re-verify CLEAR (~00:52 HKT)
Honesty gate **GREEN** (Worker URL, Legal+UI, notes A, privacy.html). Soft: proxy one-shot live test error strings optional.
**Charlie ASC remaining:** Pages 200 Privacy URL · DEVELOPMENT_TEAM · live IAP products · required screenshots · clean commit/tag before archive.
