import http from "node:http";
import { timingSafeEqual } from "node:crypto";
import { open, access } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { createMockScanPreview } from "./mockProviders.mjs";
import { normalizeUploadedImage, runLiveFoodScan, validateUploadedImage } from "./liveProviders.mjs";

const MAX_MOCK_BODY_BYTES = 4_096;
const MAX_LIVE_BODY_BYTES = 1_450_000;
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

function sendJSON(response, statusCode, body) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
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

const safeScanErrors = new Set([
  "deepseek_key_missing",
  "deepseek_request_failed",
  "usda_request_failed",
  "no_food_detected",
  "invalid_provider_response",
]);

const LOOPBACK_HOSTS = new Set(["127.0.0.1", "::1", "localhost"]);

export function listenConfigurationError(host, env = process.env) {
  if (LOOPBACK_HOSTS.has(host)) return null;
  const token = env.PANDAPLATE_SCAN_TOKEN;
  const tokenOk = typeof token === "string" && token.length >= 24;
  if (env.PANDAPLATE_ALLOW_LAN === "1" && tokenOk) return null;
  return "Refusing to listen on a non-loopback address. Use 127.0.0.1, or set PANDAPLATE_ALLOW_LAN=1 and a PANDAPLATE_SCAN_TOKEN of at least 24 characters.";
}

function configuredScanToken(env) {
  const token = env.PANDAPLATE_SCAN_TOKEN;
  return typeof token === "string" && token.length > 0 ? token : null;
}

function bearerMatches(header, token) {
  const prefix = "Bearer ";
  if (typeof header !== "string" || !header.startsWith(prefix)) return false;
  const presented = Buffer.from(header.slice(prefix.length));
  const expected = Buffer.from(token);
  if (presented.length !== expected.length) {
    timingSafeEqual(expected, expected);
    return false;
  }
  return timingSafeEqual(presented, expected);
}

export function createServer({ env = process.env, providers = {}, liveTestMarkerPath = DEFAULT_LIVE_TEST_MARKER } = {}) {
  const previewProvider = providers.createMockScanPreview ?? createMockScanPreview;
  const liveProvider = providers.runLiveFoodScan ?? runLiveFoodScan;
  let liveTestClaimed = false;
  let liveTestReserved = false;
  const hasDeepSeekKey = () => typeof env.DEEPSEEK_API_KEY === "string" && env.DEEPSEEK_API_KEY.length > 0;
  const continuousLiveEnabled = () => env.PANDAPLATE_ENABLE_LIVE_SCAN === "1" && hasDeepSeekKey();
  const runtimeTestConfigured = () => env.PANDAPLATE_ENABLE_ONE_LIVE_TEST === "1" && hasDeepSeekKey();
  const liveScanEnabled = () => continuousLiveEnabled() || runtimeTestConfigured();

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

    const isMock = request.method === "POST" && request.url === "/v1/scan/preview";
    const isLive = request.method === "POST" && request.url === "/v1/scan";
    if (!isMock && !isLive) {
      sendJSON(response, 404, { error: "not_found" });
      return;
    }
    const requiredToken = configuredScanToken(env);
    if (requiredToken && !bearerMatches(request.headers.authorization, requiredToken)) {
      request.resume();
      sendJSON(response, 401, { error: "unauthorized" });
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
      sendJSON(response, 200, result);
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
  const host = process.env.HOST || "127.0.0.1";
  const hostError = listenConfigurationError(host, process.env);
  if (hostError) {
    console.error(hostError);
    process.exit(1);
  }
  const server = createServer();
  server.listen(port, host, async () => {
    console.log(`PandaPlate local proxy listening at http://${host}:${port}`);
    if (!LOOPBACK_HOSTS.has(host)) {
      console.log("LAN listening is enabled. Scan routes require the configured bearer token. Requests and secrets are not logged.");
    }
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
