# Debug developer sign-in (Simulator SIWA bypass)

## Purpose
On **Debug** builds only, onboarding (and any screen that hosts `PandaPlateProxySignInButtons`) shows **Continue as Developer** under Sign in with Apple so Charlie can finish setup on Simulator without a real Apple ID.

## Guard / honesty (locked)
- **Compile-time gate:** the button, hint copy, coordinator entry (`continueAsDeveloper`), and `PandaPlateDebugDeveloperSignIn` are wrapped in `#if DEBUG`.
- **Release / App Store archive:** those symbols and UI strings must not appear in the product. Do **not** add a Release runtime unlock, feature flag, or hidden gesture.
- **Production auth remains Sign in with Apple only** (Google stays gone).
- **No Premium invent:** this path does not set `pandaplate.debugPremiumUnlock` or otherwise fake Premium. Existing Debug Premium toggle (Profile → Advanced) is unchanged and separate.
- **No proxy scan session:** developer continue does **not** mint a Worker session token. Food scan still needs real SIWA for the proxy; manual logging works.
- **No** new IAP / StoreKit IDs / `DEVELOPMENT_TEAM`, PrivacyInfo, legal, proxy, or age 13+ drift.

## What it unlocks
Sets the same onboarding identity fields SIWA would (`appleUserIdentifier` / `appleEmail` on the draft) via `onAuthenticated`, so `hasSignedInAccount` becomes true and **Enter PandaPlate** / post-auth shell match a normal SIWA completion.

Stable Debug identity (Debug binary only):
- userID: `pandaplate.debug.developer`
- email: `developer@localhost`

## How to verify (Guard-friendly)

### Source
```bash
rg -n "Continue as Developer|continueAsDeveloper|PandaPlateDebugDeveloperSignIn|pandaplate.debug.developer" Sources
# Every hit must sit inside #if DEBUG … #endif
```

### Debug build (Simulator)
```bash
xcodebuild -project PandaPlate.xcodeproj -scheme PandaPlate -configuration Debug \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" \
  -derivedDataPath /tmp/PandaPlate-DevSignIn-Debug \
  CODE_SIGNING_ALLOWED=NO build
# Debug may ship code in `PandaPlate.debug.dylib` (stub `PandaPlate` binary is tiny):
strings /tmp/PandaPlate-DevSignIn-Debug/Build/Products/Debug-iphonesimulator/PandaPlate.app/PandaPlate.debug.dylib \
  | rg "Continue as Developer|pandaplate.debug.developer|developer@localhost"
# Expect hits.
```

### Release build (strip evidence)
```bash
xcodebuild -project PandaPlate.xcodeproj -scheme PandaPlate -configuration Release \
  -destination "platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0" \
  -derivedDataPath /tmp/PandaPlate-DevSignIn-Release \
  CODE_SIGNING_ALLOWED=NO build
# Expect ZERO matches across the app bundle:
find /tmp/PandaPlate-DevSignIn-Release/Build/Products/Release-iphonesimulator/PandaPlate.app -type f -print0 \
  | xargs -0 strings 2>/dev/null \
  | rg "Continue as Developer|pandaplate.debug.developer|developer@localhost" || true
nm /tmp/PandaPlate-DevSignIn-Release/Build/Products/Release-iphonesimulator/PandaPlate.app/PandaPlate \
  | rg -i "DeveloperSignIn|continueAsDeveloper" || true
```

If `rg` finds those strings/symbols in the Release product, fail the change — gating is broken.

## Evidence captured (this change)

- Debug build: **BUILD SUCCEEDED** — iPhone 18 Pro / iOS 27.0, `CODE_SIGNING_ALLOWED=NO`, DerivedData `/tmp/PandaPlate-DevSignIn-Debug`
- Release build: **BUILD SUCCEEDED** — same destination, DerivedData `/tmp/PandaPlate-DevSignIn-Release`
- `strings` on Debug `PandaPlate.debug.dylib`: contains `Continue as Developer`, `pandaplate.debug.developer`, `developer@localhost`
- `strings` on whole Release `.app` + `nm` on Release binary: **zero** hits for those tokens / `continueAsDeveloper` / `DeveloperSignIn`
