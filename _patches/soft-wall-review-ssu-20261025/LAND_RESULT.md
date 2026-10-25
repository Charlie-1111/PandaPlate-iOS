# LAND RESULT — Soft wall + Review + Soft Show-Up + StoreKit/LAN
**Date:** 2026-10-25 Asia/Hong_Kong  
**Repo:** `/Users/charlie/Projects/PandaPlate-iOS`  
**Build:** **SUCCEEDED** · iPhone 17 Simulator (`xcodebuild -scheme PandaPlate -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'`)  
**Cosmetics:** paused / untouched

## Soft Show-Up #5 — H-SSU PASS (Clear)
Already landed before this pass. Entry: Progress→History + Profile cards. Free earns presence days; history gated Premium. Copy from Clear repair doc. SoftShowUpRepairBanner wired on Progress history when seen today after gap-capable count.

## Soft wall #1
FirstSuccessMoments after first meal save OR Pip ritual only. Soft sheet `PremiumPaywallView(isSoftPrompt: true)` — Not now / keep Free. Never mid-onboarding. No fake timers.

## Review #6
requestReview once/install (`didRequestReviewAtFirstSuccess`). Before soft wall; NEVER after paywall.

## This pass — StoreKit + LAN
**StoreKit** `Sources/PremiumAccess.swift`: Product.products monthly `com.charlie.pandaplate.premium.monthly` / yearly `.yearly`; purchase; StoreKit.AppStore.sync restore; Transaction.updates; honest unavailable copy; unlockForTesting DEBUG-only.

**LAN** Profile LOCAL SCAN SERVER → `pandaplate.scanBaseURL` (default `http://127.0.0.1:8787`). Server `HOST||0.0.0.0`.

## Files changed this pass
- Sources/PremiumAccess.swift
- Sources/MainShellView.swift (soft prompt, scan URL, RepairBanner)
- Server/src/server.mjs

## Backup
`_patches/soft-wall-review-ssu-20261025/`

## Blockers
- Live prices need ASC / StoreKit config — DEBUG local unlock until then
- Device scan needs Mac LAN IP in Profile
