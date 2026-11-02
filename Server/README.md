# PandaPlate local proxy (development only)

This is an unhosted Node service for local development only. Its loopback HTTP transport is development-only and must not be used as a hosted endpoint. The iOS app can send a photo to `/v1/scan` after the person sees the provider disclosure and opts in, but the server’s live route stays disabled by default. It always binds to `127.0.0.1`; `HOST` is ignored because this HTTP-only development server must not be exposed to a network. It stores no photos on disk and does not log request bodies, images, provider responses, or credentials.

The app’s default URL is `http://127.0.0.1:8787`, which is useful only when the app and server share the same device. On an iPhone, `127.0.0.1` means the iPhone itself. This local server cannot securely serve an iPhone over Wi-Fi; use a hosted HTTPS proxy for that.

## Key handling

Do not put the saved DeepSeek key in this local server’s `.env`, even though that file is Git-ignored: it is still plaintext, and the local live route is disabled. The one-shot live-test marker has already been used and must stay spent. `npm test` uses fake provider responses and makes no live calls.

The replacement key has not been copied to this Mac or written to a file. When you are ready to configure the hosted proxy, use the standalone [Cloudflare Worker setup guide](../../../outputs/pandaplate-proxy-starter-20261027/README.md). It shows Wrangler’s interactive secret entry and warns that the regular `wrangler secret put` command deploys immediately.

## Current routes

- `GET /healthz` returns local status and a secret-free one-shot eligibility field. It does not prove that a key works, a provider is reachable, or food results are accurate.
- `POST /v1/auth/nonce` creates a short-lived one-use Apple- or Google-bound nonce; `POST /v1/auth/session` verifies the matching provider identity token and nonce claim, then returns a signed app session.
- `POST /v1/scan/preview` accepts only `{"mode":"mock"}` and returns a deterministic placeholder. It rejects photo fields.
- `POST /v1/scan` requires a valid bearer session, explicit `consent: true`, a valid JPEG/PNG, and a server-only provider key plus a live-enable flag. The one-shot mode has already been consumed. Do not attempt another live request here.

The image route limits the request size, checks signatures, decodes images server-side, rejects animation and images above 20 MP, then normalizes to one JPEG no larger than 1,200 px on a side and 1 MB before DeepSeek. It looks up the food name in USDA FoodData Central, falling back to `DEMO_KEY` for the prototype route. Numeric results are range-checked. The local Node server verifies Apple/Google identity tokens and requires a signed session for scans; it applies per-user burst and daily caps in process memory. Those caps reset if the process restarts, so this is not a durable hosted quota. The separate Worker uses D1 for persistent daily quotas.

A previously approved public CC0 pear test was used once outside the app. Its sanitized result remains as a deterministic fixture in `test/fixtures/pear-live-response.json`; it is not evidence of validated accuracy. The app does not present it as a real result.

## Run locally

Requires Node.js 22.9 or newer and the existing npm dependencies.

```sh
cd /Users/charlie/Projects/PandaPlate-iOS/Server
npm test
npm start
```

The server prints a loopback-only address, normally `http://127.0.0.1:8787`. Never change it to bind all interfaces or expose it to the public internet.

## Accuracy and data strategy

Adding databases does not by itself improve image identification. A future system should use image models only for candidate foods, use databases for nutrient records, show plausible matches, ask the user to confirm preparation and portion, preserve unknown values as unknown, and require editable confirmation before saving.

For packaged food, an exact barcode/GTIN lookup is preferable to a guessed product; Open Food Facts is mainly packaged-product/ingredient-label data, not generic plated-food recognition. Do not imply a barcode feature exists unless it is implemented.

For Hong Kong coverage, the [Centre for Food Safety Nutrient Information Inquiry System](https://www.cfs.gov.hk/english/nutrient/index.php) covers energy and 18 nutrients, includes local foods, and offers downloadable nutrient-profile spreadsheets; no public API is documented. Its guide describes personal non-commercial reference use, so do not scrape or redistribute records until CFS confirms reuse rights and supported access.

Commercial services to evaluate only after coverage, terms and cost are checked include [FatSecret Platform](https://platform.fatsecret.com/api-editions) and [Edamam Food Database Vision](https://developer.edamam.com/food-database-api). Neither is integrated or credentialed in this project. Benchmark any future system on a held-out labeled set of local dishes and known portions; measure food-match accuracy separately from portion/calorie error.

## Before hosted use

The local route is not production-ready. The separate Cloudflare Worker starter contains Apple/Google verification, provider-bound one-use nonce handling, an explicit hosted HTTPS guard, D1 daily quotas, burst limiting, image bounds, and server-side secret bindings. The native app’s token-to-session integration is now present, but the Worker is not configured or deployed. It still needs owner-controlled Cloudflare resources and OAuth values, including the Google Web/server client ID, secret entry, deployment review, real-account/provider validation, and privacy/cross-border review. Keep provider keys out of the app bundle, local plaintext files, and source repository.
