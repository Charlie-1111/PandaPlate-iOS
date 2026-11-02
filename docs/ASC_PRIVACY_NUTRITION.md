# PandaPlate — App Privacy nutrition labels (ASC fill-in)

**Source of truth:** `Sources/LegalDocuments.swift` Privacy Notice + current code paths (2026-10-31).  
**Hosted Notice:** `docs/privacy.html` = Charlie’s Manus Privacy Policy HTML (2026-10-31); needs public HTTPS URL (Pages) before ASC submit.  
**Do not claim:** medical diagnosis, guaranteed weight loss, “AI always accurate calories,” Screen Time APIs, or tracking for ads.

## Privacy Policy URL (Charlie)

1. Publish `docs/privacy.html` on HTTPS (GitHub Pages on this repo, or any owner site).
2. Paste that URL into App Store Connect → App Privacy / App Information.
3. Keep in-app Notice text aligned with the hosted page.

Suggested Pages path if enabled on `main` / `docs/`:  
`https://charlie-1111.github.io/PandaPlate-iOS/privacy.html`  
(Confirm after Pages is turned on — do not paste until the URL loads.)

## Nutrition labels — declare for this build

| Data type | Collected? | Linked to identity? | Used for tracking? | Purpose | Notes |
|-----------|------------|---------------------|--------------------|---------|-------|
| Photos or Videos | Yes (optional) | No for manual attach; Yes if signed in and scan consented | No | App Functionality | Meal still image; sent only after per-scan consent when a scan server is configured |
| Health | Yes (optional) | No | No | App Functionality | Steps, active energy, exercise time, workouts — read only if user taps Connect; no write |
| Contact Info — Email Address | Yes (optional) | Yes | No | App Functionality | May arrive via Sign in with Apple on first auth |
| Contact Info — Name | Yes (optional) | Yes | No | App Functionality | May arrive via Sign in with Apple |
| User ID | Yes (optional) | Yes | No | App Functionality | Sign in with Apple subject / identity for setup / proxy session |
| Purchases | Yes | Yes (via Apple) | No | App Functionality | StoreKit entitlement status only; Apple processes payment |
| Product Interaction | No | — | — | — | No third-party analytics SDK in this build |
| Advertising Data | No | — | — | — | No ad networks |
| Other Diagnostic / Crash | No | — | — | — | None declared until a crash reporter ships |

### Tracking
- **Does this app track users?** **No** (current build).

### Age
- ASC age rating / in-app floor: **13+**. Not Made for Kids.

### Food Scan / third parties (disclose if production scan ships)
If Release still has no production HTTPS scan, keep App description + review notes aligned: recognition unavailable as production.  
If production scan ships later, update hosted Notice + nutrition labels before submit: photo → owner proxy → DeepSeek (may process in China / training per their policy) + USDA FoodData Central for name match.

### Support contact on page
Current: `lisbon-oondn8@bot.cue.im` (synced in-app LegalDocuments + privacy.html + review notes).
