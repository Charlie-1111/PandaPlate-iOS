# PandaPlate — App Review notes (draft)

**Owner:** Plate Ship  
**Updated:** 2026-11-02 Asia/Hong_Kong  
**Paste into ASC only after blockers below are resolved or explicitly disclosed.**

## Draft text for App Review Information

PandaPlate is a gentle food-logging and wellness companion for ages 13+. It is not medical advice and does not diagnose or prescribe calories.

**Sign-in:** Users can Sign in with Apple or continue without an account for session-local use. Google Sign-In is not included. [Add demo account credentials here if Review must pass a gated path.]

**Free vs Premium:** Free includes manual logging and related tools as shown in the build. Live food recognition is limited to 3 scans per day on Free when a scan server is configured; Premium is sold only through Apple In-App Purchase (product IDs `com.charlie.pandaplate.premium.monthly` and `com.charlie.pandaplate.premium.yearly`). Prices and renewals come from the App Store sheet. Manage/cancel in Apple ID subscriptions.

**Food Scan / network:** **A** (production HTTPS owner proxy configured)
- A) **ACTIVE** Production HTTPS owner proxy is configured (`https://pandaplate-ai-proxy.charliengyt.workers.dev`). Each scan requires fresh in-app consent. The image may be sent to the owner proxy for recognition (DeepSeek vision + USDA FoodData Central lookup; details match the public Privacy Policy). Results are editable estimates. Free: 3 live scans/day; Premium: unlimited via IAP.
- B) *(retired for this build)* Live food recognition is **not** offered as a production service. Localhost/LAN proxy remains Debug-only override.

**HealthKit:** Read-only (steps, active energy, exercise time, workouts) only after the user taps Connect. The app does not write to Health.

**Camera / photos:** Used when the user opens Food Scan to take or pick one still meal photo.

**Privacy Policy:** https://charlie-1111.github.io/PandaPlate-iOS/privacy.html. In-app Terms and Privacy Notice are also reachable from welcome and Profile. `LegalDocuments.privacyPolicyURL` is wired to the same URL.

**Support:** lisbon-oondn8@bot.cue.im (replace if Charlie swaps).

## Do not claim

- Medical diagnosis, guaranteed weight loss, or “AI always accurate calories”
- Production Food Scan without consent, or that DeepSeek/USDA results are medically authoritative
- Tracking or third-party advertising (nutrition sheet: tracking = No)


## Honesty sync gate
Food Scan honesty is **A** with production HTTPS proxy live. Hosted Privacy Policy URL is live (GitHub Pages 200). Paste the same URL into ASC App Privacy / Review Information. Keep DeepSeek + USDA honesty aligned with `docs/privacy.html`.


## Privacy HTML
Food Scan section updated for owner-hosted HTTPS proxy + consent (DeepSeek+USDA honesty retained). Support email on page: `lisbon-oondn8@bot.cue.im`. Hosted URL live: https://charlie-1111.github.io/PandaPlate-iOS/privacy.html (verified HTTP 200).
