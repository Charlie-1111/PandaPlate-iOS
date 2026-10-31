# PandaPlate local proxy (development only)

This Node service is a local development proxy. It is not production-ready. By default it binds to `127.0.0.1` only. It writes no photos to disk and never logs request bodies, images, model responses or credentials. Do not expose it to a LAN or the public internet. A non-loopback bind is refused unless `PANDAPLATE_ALLOW_LAN=1` and `PANDAPLATE_SCAN_TOKEN` (at least 24 characters) are both set. When that token is set, `POST /v1/scan` and `POST /v1/scan/preview` require `Authorization: Bearer <token>` before any image is read or any provider is called.

## Current state

Run `npm start` from this directory to start the development service. Run `npm test` for local route/guard tests. The mock route is the default; tests use fake provider responses. No provider request is made by the app or ordinary test suite.

`GET /healthz` reports local status and a secret-free one-shot eligibility field. That field does not prove that credentials work, the provider is reachable or the result is accurate.

`POST /v1/scan/preview` is a server-side mock test endpoint. It accepts only `{"mode":"mock"}`, rejects photo fields, and returns a fixed placeholder. The iOS app does not call it.

## One-shot developer endpoint — already consumed

`POST /v1/scan` is a local developer route, not an app feature. It can only be considered eligible when `PANDAPLATE_ENABLE_ONE_LIVE_TEST=1`, a server-only `DEEPSEEK_API_KEY` is supplied as a runtime variable and the durable `.one-live-test-used` marker is absent. The marker is present because the previously approved single public-image test was consumed; the source package must preserve it. Do not set the flag, use a key or run another provider call without a new, explicit user approval. Never place a credential in source, `.env`, command history or the iOS bundle.

If separately authorized in future, the route expects explicit `consent: true` and a JPEG base64 image. It limits the encoded input, checks the signature, decodes it server-side, rejects animated images and images above 20 MP, then normalizes to a single JPEG no larger than 1,200 px on a side and 1 MB before DeepSeek. It performs a separate USDA FoodData Central lookup using server-side `FDC_API_KEY`, falling back to `DEMO_KEY` only for the one prototype test. Provider bodies are capped and numeric nutrition values are range-checked. This remains local-only and has no production authentication or rate limiting.

A single previously approved test used a public CC0 pear image outside the iOS app. Its sanitized result is kept as a deterministic test fixture in `test/fixtures/pear-live-response.json`; it is not evidence of validated accuracy. It is never presented as a real result by the current app.

## Accuracy and data strategy

Adding databases does not by itself improve image identification. A future system should use image models only for candidate foods, use databases for nutrient records, show multiple plausible matches, ask the user to confirm preparation and portion, preserve unknown values as unknown, and require editable user confirmation before saving.

For packaged food, an exact barcode/GTIN lookup is preferable to a guessed product; Open Food Facts is mainly packaged-product/ingredient-label data, not generic plated-food recognition. Do not imply a barcode feature exists in this app.

For Hong Kong coverage, the [Centre for Food Safety Nutrient Information Inquiry System](https://www.cfs.gov.hk/english/nutrient/index.php) covers energy and 18 nutrients, includes local foods, and offers downloadable nutrient-profile spreadsheets; no public API is documented. Its guide describes personal non-commercial reference use, so do not scrape or redistribute records until CFS confirms reuse rights and supported access.

Commercial services to evaluate only after coverage, terms and cost are checked include [FatSecret Platform](https://platform.fatsecret.com/api-editions) and [Edamam Food Database Vision](https://developer.edamam.com/food-database-api). Neither is integrated or credentialed in this project. Benchmark any future system on a held-out labeled set of local dishes and known portions; measure food-match accuracy separately from portion/calorie error.

## Before any hosted version

A production path would need an owner-controlled HTTPS endpoint, authentication, durable per-user quotas/rate limits, secret management and rotation, schema/numeric validation, provider timeouts/retry controls, image-dimension limits, explicit disclosure before every upload, no photo/key logging, documented retention and cross-border privacy review, a production FDC key and attribution. None of these hosted capabilities is present. Do not ship this local route as-is.
