import { createHash, randomBytes } from "node:crypto";
import http from "node:http";
import { open, access } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { createMockScanPreview } from "./mockProviders.mjs";
import {
  issueSessionToken,
  makeUserSubject,
  verifyIdentityToken,
  verifySessionToken,
} from "./auth.mjs";
import { normalizeUploadedImage, runLiveFoodScan, validateUploadedImage } from "./liveProviders.mjs";

const MAX_AUTH_BODY_BYTES = 4_096;
const MAX_MOCK_BODY_BYTES = 4_096;
const MAX_LIVE_BODY_BYTES = 1_450_000;
const DEFAULT_DAILY_SCAN_LIMIT = 10;
const DEFAULT_BURST_LIMIT = 5;
const DEFAULT_LIVE_TEST_MARKER = fileURLToPath(new URL("../.one-live-test-used", import.meta.url));

async function markerExists(path) {
  try {
    await access(path);
    return true;
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
}

async function claimMarker(path) {
  try {
    const handle = await open(path, "wx", 0o600);
    try {
      await handle.writeFile("One-shot live test consumed.\n");
    } finally {
      await handle.close();
    }
    return true;
  } catch (error) {
    if (error?.code === "EEXIST") return false;
    throw error;
  }
}

function sendJSON(response, statusCode, body, headers = {}) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    ...headers,
  });
  response.end(JSON.stringify(body));
}

async function readSmallJSON(request, limit) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > limit) throw new Error("body-too-large");
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString("utf8"));
}

function bearerToken(request) {
  const header = request.headers.authorization ?? "";
  return header.startsWith("Bearer ") ? header.slice(7).trim() : "";
}

function boundedPositiveInteger(value, fallback, maximum = 10_000) {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 && parsed <= maximum ? parsed : fallback;
}

const safeScanErrors = new Set([
  "deepseek_key_missing",
  "deepseek_request_failed",
  "usda_request_failed",
  "no_food_detected",
  "invalid_provider_response",
]);

export function createServer({ env = process.env, providers = {}, liveTestMarkerPath = DEFAULT_LIVE_TEST_MARKER } = {}) {
  const previewProvider = providers.createMockScanPreview ?? createMockScanPreview;
  const liveProvider = providers.runLiveFoodScan ?? runLiveFoodScan;
  const now = providers.nowSeconds ?? (() => Math.floor(Date.now() / 1_000));
  // A per-process secret is sufficient for the loopback development server; sessions expire after 7 days.
  // The hosted Worker uses a separately managed SESSION_SIGNING_SECRET.
  const sessionSecret = env.PANDAPLATE_SESSION_SIGNING_SECRET || randomBytes(32).toString("hex");
  const identityVerifier = providers.verifyIdentityToken ?? ((input) => verifyIdentityToken(input));
  const sessionVerifier = providers.verifySessionToken ?? ((token) => verifySessionToken(sessionSecret, token, now()));
  const nonces = new Map();
  const dailyUsage = new Map();
  const burstUsage = new Map();
  let liveTestClaimed = false;
  let liveTestReserved = false;
  const hasDeepSeekKey = () => typeof env.DEEPSEEK_API_KEY === "string" && env.DEEPSEEK_API_KEY.length > 0;
  const continuousLiveEnabled = () => env.PANDAPLATE_ENABLE_LIVE_SCAN === "1" && hasDeepSeekKey();
  const runtimeTestConfigured = () => env.PANDAPLATE_ENABLE_ONE_LIVE_TEST === "1" && hasDeepSeekKey();
  const liveScanEnabled = () => continuousLiveEnabled() || runtimeTestConfigured();

  function takeBurstSlot(subject) {
    const minute = Math.floor(now() / 60);
    const key = `${subject}:${minute}`;
    const used = burstUsage.get(key) ?? 0;
    if (used >= boundedPositiveInteger(env.PANDAPLATE_BURST_PER_MINUTE, DEFAULT_BURST_LIMIT, 100)) return false;
    burstUsage.set(key, used + 1);
    for (const existingKey of burstUsage.keys()) {
      if (!existingKey.endsWith(`:${minute}`)) burstUsage.delete(existingKey);
    }
    return true;
  }

  function takeDailySlot(subject) {
    const day = new Date(now() * 1_000).toISOString().slice(0, 10);
    const key = `${subject}:${day}`;
    const used = dailyUsage.get(key) ?? 0;
    const limit = boundedPositiveInteger(env.PANDAPLATE_DAILY_SCAN_LIMIT, DEFAULT_DAILY_SCAN_LIMIT, 1_000);
    if (used >= limit) return { allowed: false, limit, used };
    dailyUsage.set(key, used + 1);
    for (const existingKey of dailyUsage.keys()) {
      if (!existingKey.endsWith(`:${day}`)) dailyUsage.delete(existingKey);
    }
    return { allowed: true, limit, used: used + 1 };
  }

  async function authenticateSession(request) {
    const token = bearerToken(request);
    if (!token) return null;
    try {
      return await sessionVerifier(token);
    } catch {
      return null;
    }
  }

  const server = http.createServer(async (request, response) => {
    if (request.method === "GET" && request.url === "/healthz") {
      if (continuousLiveEnabled()) {
        sendJSON(response, 200, {
          status: "ok",
          mode: "live",
          oneShotTestEligible: false,
          continuousLive: true,
        });
        return;
      }
      let oneShotTestEligible = false;
      if (runtimeTestConfigured() && !liveTestClaimed && !liveTestReserved) {
        try {
          oneShotTestEligible = !(await markerExists(liveTestMarkerPath));
        } catch {
          oneShotTestEligible = false;
        }
      }
      sendJSON(response, 200, {
        status: "ok",
        mode: oneShotTestEligible ? "one-shot-test-eligible" : "mock",
        oneShotTestEligible,
        continuousLive: false,
      });
      return;
    }

    const isNonce = request.method === "POST" && request.url === "/v1/auth/nonce";
    const isSession = request.method === "POST" && request.url === "/v1/auth/session";
    if (isNonce || isSession) {
      if (!request.headers["content-type"]?.toLowerCase().startsWith("application/json")) {
        sendJSON(response, 415, { error: "content_type_must_be_json" });
        return;
      }
      let body;
      try {
        body = await readSmallJSON(request, MAX_AUTH_BODY_BYTES);
      } catch (error) {
        const status = error?.message === "body-too-large" ? 413 : 400;
        sendJSON(response, status, { error: status === 413 ? "request_too_large" : "invalid_json" });
        return;
      }
      if (!body || typeof body !== "object" || Array.isArray(body)) {
        sendJSON(response, 400, { error: "invalid_request" });
        return;
      }

      if (isNonce) {
        if (Object.keys(body).length !== 1
          || (body.provider !== "apple" && body.provider !== "google")) {
          sendJSON(response, 400, { error: "invalid_request" });
          return;
        }
        const nonce = randomBytes(32).toString("base64url");
        const expiresAt = now() + 300;
        const hash = createHash("sha256").update(nonce).digest("hex");
        nonces.set(`${body.provider}:${hash}`, expiresAt);
        for (const [key, expiry] of nonces) if (expiry <= now()) nonces.delete(key);
        sendJSON(response, 200, { nonce, expiresInSeconds: 300 });
        return;
      }

      const allowedKeys = new Set(["provider", "nonce"]);
      if (Object.keys(body).some((key) => !allowedKeys.has(key))
        || (body.provider !== "apple" && body.provider !== "google")) {
        sendJSON(response, 400, { error: "invalid_request" });
        return;
      }
      const provider = body.provider;
      const audience = provider === "apple" ? env.APPLE_CLIENT_ID : env.GOOGLE_SERVER_CLIENT_ID;
      if (typeof audience !== "string" || audience.length === 0) {
        sendJSON(response, 503, { error: "identity_provider_not_configured" });
        return;
      }
      const identityToken = bearerToken(request);
      if (!identityToken) {
        sendJSON(response, 401, { error: "unauthorized" });
        return;
      }

      if (typeof body.nonce !== "string" || body.nonce.length < 32 || body.nonce.length > 128) {
        sendJSON(response, 401, { error: "invalid_nonce" });
        return;
      }
      const nonceHash = createHash("sha256").update(body.nonce).digest("hex");
      const nonceKey = `${provider}:${nonceHash}`;
      const expiresAt = nonces.get(nonceKey);
      if (!expiresAt || expiresAt <= now()) {
        sendJSON(response, 401, { error: "nonce_expired_or_reused" });
        return;
      }
      // Consume before awaiting remote key retrieval so concurrent/replayed tokens cannot reuse it.
      nonces.delete(nonceKey);
      const expectedNonce = provider === "apple" ? nonceHash : body.nonce;

      let identity;
      try {
        identity = await identityVerifier({
          provider,
          token: identityToken,
          audience,
          expectedNonce,
          nowSeconds: now(),
        });
      } catch {
        sendJSON(response, 401, { error: "invalid_identity_token" });
        return;
      }
      if (typeof identity?.subject !== "string" || identity.subject.length < 1 || identity.subject.length > 255) {
        sendJSON(response, 401, { error: "invalid_identity_token" });
        return;
      }
      const subject = makeUserSubject(sessionSecret, provider, identity.subject);
      const issued = issueSessionToken(sessionSecret, subject, now());
      sendJSON(response, 200, issued);
      return;
    }

    const isMock = request.method === "POST" && request.url === "/v1/scan/preview";
    const isLive = request.method === "POST" && request.url === "/v1/scan";
    if (!isMock && !isLive) {
      sendJSON(response, 404, { error: "not_found" });
      return;
    }
    if (!request.headers["content-type"]?.toLowerCase().startsWith("application/json")) {
      sendJSON(response, 415, { error: "content_type_must_be_json" });
      return;
    }

    if (isMock) {
      try {
        const body = await readSmallJSON(request, MAX_MOCK_BODY_BYTES);
        const keys = body && typeof body === "object" && !Array.isArray(body) ? Object.keys(body) : [];
        if (!body || body.mode !== "mock" || keys.some((key) => key !== "mode")) {
          sendJSON(response, 400, { error: "mock_mode_only_no_photo_fields_allowed" });
          return;
        }
        sendJSON(response, 200, await previewProvider());
      } catch (error) {
        const status = error?.message === "body-too-large" ? 413 : 400;
        sendJSON(response, status, { error: status === 413 ? "request_too_large" : "invalid_json" });
      }
      return;
    }

    if (!liveScanEnabled()) {
      sendJSON(response, 503, { error: "live_scan_not_enabled" });
      return;
    }
    const session = await authenticateSession(request);
    if (!session || typeof session.subject !== "string") {
      sendJSON(response, 401, { error: "unauthorized" });
      return;
    }
    if (!takeBurstSlot(session.subject)) {
      sendJSON(response, 429, { error: "too_many_requests" });
      return;
    }

    const continuous = continuousLiveEnabled();
    if (!continuous) {
      if (liveTestClaimed || liveTestReserved) {
        sendJSON(response, 409, { error: "one_live_test_already_used_or_in_progress" });
        return;
      }
      liveTestReserved = true;
    }

    let body;
    try {
      body = await readSmallJSON(request, MAX_LIVE_BODY_BYTES);
    } catch (error) {
      if (!continuous) liveTestReserved = false;
      const status = error?.message === "body-too-large" ? 413 : 400;
      sendJSON(response, status, { error: status === 413 ? "request_too_large" : "invalid_json" });
      return;
    }

    const allowedKeys = new Set(["mode", "consent", "imageBase64", "mimeType"]);
    if (!body || typeof body !== "object" || Array.isArray(body)
      || Object.keys(body).some((key) => !allowedKeys.has(key))
      || body.mode !== "live"
      || body.consent !== true) {
      if (!continuous) liveTestReserved = false;
      sendJSON(response, 400, { error: "explicit_live_consent_required" });
      return;
    }

    const imageBuffer = validateUploadedImage(body);
    if (!imageBuffer) {
      if (!continuous) liveTestReserved = false;
      if (typeof body?.imageBase64 === "string") body.imageBase64 = "";
      sendJSON(response, 400, { error: "invalid_image_or_image_too_large" });
      return;
    }

    let normalizedImage;
    try {
      normalizedImage = await normalizeUploadedImage(imageBuffer);
    } catch {
      imageBuffer.fill(0);
      body.imageBase64 = "";
      if (!continuous) liveTestReserved = false;
      sendJSON(response, 400, { error: "invalid_image_or_image_too_large" });
      return;
    }
    imageBuffer.fill(0);
    body.imageBase64 = "";

    const quota = takeDailySlot(session.subject);
    if (!quota.allowed) {
      if (!continuous) liveTestReserved = false;
      normalizedImage.fill(0);
      sendJSON(response, 429, {
        error: "daily_scan_limit_reached",
        dailyLimit: quota.limit,
        resetsAtUtc: "00:00 UTC",
      });
      return;
    }

    if (!continuous) {
      // Persist the claim before any provider call. A server restart cannot re-enable the test.
      try {
        if (!(await claimMarker(liveTestMarkerPath))) {
          liveTestReserved = false;
          normalizedImage.fill(0);
          sendJSON(response, 409, { error: "one_live_test_already_used_or_in_progress" });
          return;
        }
      } catch {
        liveTestReserved = false;
        normalizedImage.fill(0);
        sendJSON(response, 503, { error: "live_test_marker_unavailable" });
        return;
      }
      liveTestClaimed = true;
      liveTestReserved = false;
    }

    let normalizedBase64 = normalizedImage.toString("base64");
    try {
      const result = await liveProvider({
        imageBase64: normalizedBase64,
        mimeType: "image/jpeg",
        deepSeekApiKey: env.DEEPSEEK_API_KEY,
        fdcApiKey: env.FDC_API_KEY || "DEMO_KEY",
      });
      sendJSON(response, 200, result, {
        "X-Scan-Daily-Limit": String(quota.limit),
        "X-Scan-Remaining": String(Math.max(0, quota.limit - quota.used)),
      });
    } catch (error) {
      const errorCode = safeScanErrors.has(error?.message) ? error.message : "scan_failed";
      const message = continuous
        ? "The scan did not complete. Try again with a clearer photo."
        : "The scan did not complete. The one-shot live test is now used.";
      sendJSON(response, 502, { error: errorCode, message });
    } finally {
      normalizedImage.fill(0);
      normalizedBase64 = "";
      body.imageBase64 = "";
    }
  });

  server.headersTimeout = 5_000;
  server.requestTimeout = 60_000;
  server.keepAliveTimeout = 1_000;
  return server;
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT ?? 8787);
  if (!Number.isInteger(port) || port < 1024 || port > 65_535) {
    console.error("PORT must be an integer from 1024 to 65535.");
    process.exit(1);
  }
  // This development server has no TLS; keep it on-device even if HOST is set in the shell.
  const host = "127.0.0.1";
  const server = createServer();
  server.listen(port, host, async () => {
    console.log(`PandaPlate local proxy listening at http://${host}:${port}`);
    const continuous = process.env.PANDAPLATE_ENABLE_LIVE_SCAN === "1"
      && typeof process.env.DEEPSEEK_API_KEY === "string"
      && process.env.DEEPSEEK_API_KEY.length > 0;
    if (continuous) {
      console.log("Continuous live scan is enabled; provider connectivity is not verified, and requests/secrets are not logged.");
      return;
    }
    let oneShotTestEligible = process.env.PANDAPLATE_ENABLE_ONE_LIVE_TEST === "1"
      && typeof process.env.DEEPSEEK_API_KEY === "string"
      && process.env.DEEPSEEK_API_KEY.length > 0;
    if (oneShotTestEligible) {
      try {
        oneShotTestEligible = !(await markerExists(DEFAULT_LIVE_TEST_MARKER));
      } catch {
        oneShotTestEligible = false;
      }
    }
    console.log(oneShotTestEligible
      ? "One-shot local test is eligible; provider connectivity is not verified, and requests/secrets are not logged."
      : "Mock mode is active or the one-shot test is spent; external requests are disabled.");
  });
}
