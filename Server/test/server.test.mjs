import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Readable } from "node:stream";
import sharp from "sharp";
import { afterEach, test } from "node:test";
import { createServer } from "../src/server.mjs";
import { normalizeUploadedImage } from "../src/liveProviders.mjs";

const running = new Set();
const tempDirectories = new Set();
const testServers = new Map();
let nextTestServer = 0;

async function fetch(input, init = {}) {
  const url = new URL(input);
  const server = testServers.get(url.origin);
  if (!server) return globalThis.fetch(input, init);
  return new Promise((resolve, reject) => {
    const requestBody = init.body === undefined ? [] : [Buffer.from(init.body)];
    const request = Readable.from(requestBody);
    request.method = init.method ?? "GET";
    request.url = `${url.pathname}${url.search}`;
    request.headers = Object.fromEntries(new Headers(init.headers).entries());
    const result = {
      statusCode: 200,
      headers: {},
      writeHead(statusCode, headers = {}) {
        this.statusCode = statusCode;
        this.headers = headers;
      },
      end(body = "") {
        resolve(new Response(body, { status: this.statusCode, headers: this.headers }));
      },
    };
    request.on("error", reject);
    server.emit("request", request, result);
  });
}

async function newLiveTestMarkerPath() {
  const directory = await mkdtemp(join(tmpdir(), "pandaplate-live-test-"));
  tempDirectories.add(directory);
  return join(directory, "spent");
}

async function jpegBytes(width = 16, height = 16) {
  return sharp({ create: { width, height, channels: 3, background: "#73a85d" } })
    .jpeg({ quality: 75 })
    .toBuffer();
}

async function startServer(options = {}) {
  const server = createServer(options);
  running.add(server);
  const origin = `http://pandaplate-${++nextTestServer}.test`;
  testServers.set(origin, server);
  return origin;
}

async function authNonce(baseURL, provider) {
  const response = await fetch(`${baseURL}/v1/auth/nonce`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ provider }),
  });
  assert.equal(response.status, 200);
  return (await response.json()).nonce;
}

async function login(baseURL, provider = "google", identityToken = "fake-google-id-token") {
  const body = { provider, nonce: await authNonce(baseURL, provider) };
  const response = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${identityToken}`,
    },
    body: JSON.stringify(body),
  });
  if (response.status !== 200) throw new Error(`Session exchange failed (${response.status}): ${await response.text()}`);
  return (await response.json()).sessionToken;
}

function fakeIdentityVerifier() {
  return async ({ provider, token, audience, expectedNonce }) => {
    if (!token.startsWith("fake-")) throw new Error("invalid_identity_token");
    assert.equal(audience, provider === "apple" ? "com.charlie.pandaplate" : "google-server-client-id");
    if (provider === "apple") assert.match(expectedNonce ?? "", /^[a-f0-9]{64}$/);
    else assert.match(expectedNonce ?? "", /^[A-Za-z0-9_-]{32,128}$/);
    return { subject: `${provider}-test-subject` };
  };
}

function liveServerOptions(overrides = {}) {
  const { env: envOverrides = {}, providers: providerOverrides = {}, ...rest } = overrides;
  return {
    env: {
      PANDAPLATE_ENABLE_LIVE_SCAN: "1",
      DEEPSEEK_API_KEY: "test-only",
      APPLE_CLIENT_ID: "com.charlie.pandaplate",
      GOOGLE_SERVER_CLIENT_ID: "google-server-client-id",
      ...envOverrides,
    },
    providers: {
      verifyIdentityToken: fakeIdentityVerifier(),
      runLiveFoodScan: async () => ({
        mode: "live",
        candidate: {
          foodDescription: "Pear",
          portion: "1 medium",
          grams: 170,
          notes: "Estimate",
          calories: 97,
          fdcMatches: [],
          nutritionSource: "USDA FoodData Central",
        },
        notice: "Estimate; review before saving.",
      }),
      ...providerOverrides,
    },
    ...rest,
  };
}

afterEach(async () => {
  await Promise.all([...running].filter((server) => server.listening).map((server) => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  })));
  running.clear();
  testServers.clear();
  await Promise.all([...tempDirectories].map((directory) => rm(directory, { recursive: true, force: true })));
  tempDirectories.clear();
});

test("server image normalization caps dimensions and decoded pixel count", async () => {
  const validLarge = await jpegBytes(2_400, 1_800);
  const normalized = await normalizeUploadedImage(validLarge);
  assert.ok(normalized.length <= 1_000_000);
  const metadata = await sharp(normalized).metadata();
  assert.ok(metadata.width <= 1_200 && metadata.height <= 1_200);
  assert.equal(metadata.format, "jpeg");

  const oversizedPixels = await jpegBytes(5_001, 4_000);
  await assert.rejects(normalizeUploadedImage(oversizedPixels));
});

test("health reports mock mode with providers disabled", async () => {
  const baseURL = await startServer();
  const response = await fetch(`${baseURL}/healthz`);
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), {
    status: "ok",
    mode: "mock",
    oneShotTestEligible: false,
    continuousLive: false,
  });
  assert.equal(response.headers.get("cache-control"), "no-store");
});

test("preview returns a mock with unknown calories and never accepts a photo", async () => {
  const baseURL = await startServer();
  const response = await fetch(`${baseURL}/v1/scan/preview`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "mock" }),
  });
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.mode, "mock");
  assert.equal(payload.candidate.calories, null);
  assert.deepEqual(payload.candidate.fdcMatches, []);
  const photoRequest = await fetch(`${baseURL}/v1/scan/preview`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "mock", imageBase64: "AA==" }),
  });
  assert.equal(photoRequest.status, 400);
});

test("Apple and Google identities exchange into scoped, signed proxy sessions", async () => {
  const baseURL = await startServer({
    env: { APPLE_CLIENT_ID: "com.charlie.pandaplate", GOOGLE_SERVER_CLIENT_ID: "google-server-client-id" },
    providers: { verifyIdentityToken: fakeIdentityVerifier() },
  });

  const appleToken = await login(baseURL, "apple", "fake-apple-id-token");
  const googleToken = await login(baseURL, "google", "fake-google-id-token");
  assert.ok(appleToken.split(".").length === 3);
  assert.ok(googleToken.split(".").length === 3);
  assert.notEqual(appleToken, googleToken);

  const invalid = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-google-id-token" },
    body: JSON.stringify({ provider: "google", nonce: "not-allowed", extra: true }),
  });
  assert.equal(invalid.status, 400);
});

test("Apple nonce is one-use and invalid provider tokens cannot mint sessions", async () => {
  const baseURL = await startServer({
    env: { APPLE_CLIENT_ID: "com.charlie.pandaplate", GOOGLE_SERVER_CLIENT_ID: "google-server-client-id" },
    providers: { verifyIdentityToken: fakeIdentityVerifier() },
  });
  const nonce = await authNonce(baseURL, "apple");
  const body = JSON.stringify({ provider: "apple", nonce });
  const first = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-apple-id-token" },
    body,
  });
  assert.equal(first.status, 200);
  const replay = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-apple-id-token" },
    body,
  });
  assert.equal(replay.status, 401);

  const invalid = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer bad-token" },
    body: JSON.stringify({ provider: "google" }),
  });
  assert.equal(invalid.status, 401);
});

test("Google nonce is provider-bound, token-bound, and one-use", async () => {
  const baseURL = await startServer({
    env: { APPLE_CLIENT_ID: "com.charlie.pandaplate", GOOGLE_SERVER_CLIENT_ID: "google-server-client-id" },
    providers: { verifyIdentityToken: fakeIdentityVerifier() },
  });
  const nonce = await authNonce(baseURL, "google");
  const body = JSON.stringify({ provider: "google", nonce });
  const first = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-google-id-token" },
    body,
  });
  assert.equal(first.status, 200);

  const replay = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-google-id-token" },
    body,
  });
  assert.equal(replay.status, 401);

  const appleNonce = await authNonce(baseURL, "apple");
  const crossProvider = await fetch(`${baseURL}/v1/auth/session`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer fake-google-id-token" },
    body: JSON.stringify({ provider: "google", nonce: appleNonce }),
  });
  assert.equal(crossProvider.status, 401);
});

test("live route stays disabled by default", async () => {
  const baseURL = await startServer();
  const response = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: "live_scan_not_enabled" });
});

test("live scans require an authenticated proxy session before processing a photo", async () => {
  let calls = 0;
  const baseURL = await startServer(liveServerOptions({ providers: { runLiveFoodScan: async () => { calls += 1; } } }));
  const response = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(response.status, 401);
  assert.equal(calls, 0);
});

test("live route requires consent and a valid JPEG before calling its provider", async () => {
  let calls = 0;
  const baseURL = await startServer(liveServerOptions({
    env: { PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1", PANDAPLATE_ENABLE_LIVE_SCAN: undefined },
    providers: { runLiveFoodScan: async () => { calls += 1; throw new Error("unexpected"); } },
  }));
  const token = await login(baseURL);
  const missingConsent = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ mode: "live", consent: false, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(missingConsent.status, 400);
  const invalidImage = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(invalidImage.status, 400);
  assert.equal(calls, 0);
});

test("live route accepts one consented image, spends one-shot marker, then blocks another provider call", async () => {
  let calls = 0;
  const liveTestMarkerPath = await newLiveTestMarkerPath();
  const sourceImage = await jpegBytes();
  const baseURL = await startServer(liveServerOptions({
    env: { PANDAPLATE_ENABLE_LIVE_SCAN: undefined, PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1" },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async (input) => {
      calls += 1;
      assert.equal(input.deepSeekApiKey, "test-only");
      assert.equal(input.fdcApiKey, "DEMO_KEY");
      assert.equal(input.mimeType, "image/jpeg");
      const normalized = Buffer.from(input.imageBase64, "base64");
      assert.ok(normalized.length <= 1_000_000);
      const metadata = await sharp(normalized).metadata();
      assert.ok(metadata.width <= 1_200 && metadata.height <= 1_200);
      return {
        mode: "live",
        candidate: { foodDescription: "Pear", portion: "1 medium", grams: 170, notes: "Estimate", calories: 97, fdcMatches: [], nutritionSource: "USDA FoodData Central" },
        notice: "Estimate; review before saving.",
      };
    } },
  }));
  const healthBefore = await fetch(`${baseURL}/healthz`);
  assert.equal((await healthBefore.json()).oneShotTestEligible, true);
  const token = await login(baseURL);
  const body = { mode: "live", consent: true, imageBase64: sourceImage.toString("base64"), mimeType: "image/jpeg" };
  const first = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });
  assert.equal(first.status, 200);
  assert.deepEqual((await first.json()).candidate.foodDescription, "Pear");
  assert.equal(first.headers.get("x-scan-daily-limit"), "10");
  const second = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });
  assert.equal(second.status, 409);
  assert.equal(calls, 1);
  const healthAfter = await fetch(`${baseURL}/healthz`);
  assert.equal((await healthAfter.json()).oneShotTestEligible, false);

  const restartedURL = await startServer(liveServerOptions({
    env: { PANDAPLATE_ENABLE_LIVE_SCAN: undefined, PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1" },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async () => { calls += 1; return {}; } },
  }));
  const healthAfterRestart = await fetch(`${restartedURL}/healthz`);
  assert.equal((await healthAfterRestart.json()).oneShotTestEligible, false);
  const restartedToken = await login(restartedURL);
  const afterRestart = await fetch(`${restartedURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${restartedToken}` }, body: JSON.stringify(body),
  });
  assert.equal(afterRestart.status, 409);
  assert.equal(calls, 1);
});

test("the sanitized real pear response remains editable and clearly estimated", async () => {
  const fixture = JSON.parse(await readFile(new URL("./fixtures/pear-live-response.json", import.meta.url), "utf8"));
  assert.equal(fixture.mode, "live");
  assert.equal(fixture.candidate.fdcMatches[0].fdcId, 169118);
  assert.equal(fixture.candidate.calories, 97);
  assert.equal(fixture.candidate.grams, 170);
  assert.equal(fixture.candidate.confidence, 0.85);
  assert.match(fixture.candidate.notes, /cannot establish exact weight or calories/i);
  assert.match(fixture.notice, /estimates/i);
});

test("continuous live mode requires consent and enforces a per-user daily quota", async () => {
  let calls = 0;
  const liveTestMarkerPath = await newLiveTestMarkerPath();
  const sourceImage = await jpegBytes();
  const baseURL = await startServer(liveServerOptions({
    env: { PANDAPLATE_DAILY_SCAN_LIMIT: "1" },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async () => {
      calls += 1;
      return { mode: "live", candidate: { foodDescription: "Pear" }, notice: "Estimate." };
    } },
  }));
  const health = await fetch(`${baseURL}/healthz`);
  assert.deepEqual(await health.json(), {
    status: "ok",
    mode: "live",
    oneShotTestEligible: false,
    continuousLive: true,
  });
  const token = await login(baseURL);
  const body = { mode: "live", consent: true, imageBase64: sourceImage.toString("base64"), mimeType: "image/jpeg" };
  const first = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });
  assert.equal(first.status, 200);
  const second = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json", authorization: `Bearer ${token}` }, body: JSON.stringify(body),
  });
  assert.equal(second.status, 429);
  assert.equal((await second.json()).error, "daily_scan_limit_reached");
  assert.equal(calls, 1);
  // The spent one-shot marker remains untouched in continuous mode.
  await assert.rejects(readFile(liveTestMarkerPath), { code: "ENOENT" });
});

test("continuous live mode still requires explicit consent", async () => {
  let calls = 0;
  const baseURL = await startServer(liveServerOptions({
    providers: { runLiveFoodScan: async () => { calls += 1; throw new Error("unexpected"); } },
  }));
  const token = await login(baseURL);
  const missingConsent = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ mode: "live", consent: false, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(missingConsent.status, 400);
  assert.deepEqual(await missingConsent.json(), { error: "explicit_live_consent_required" });
  assert.equal(calls, 0);
});
