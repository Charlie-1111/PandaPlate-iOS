import assert from "node:assert/strict";
import http from "node:http";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import sharp from "sharp";
import { afterEach, test } from "node:test";
import { createServer, listenConfigurationError } from "../src/server.mjs";
import { normalizeUploadedImage } from "../src/liveProviders.mjs";

const running = new Set();
const tempDirectories = new Set();

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
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  running.add(server);
  return `http://127.0.0.1:${port}`;
}

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

afterEach(async () => {
  await Promise.all([...running].map((server) => new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  })));
  running.clear();
  await Promise.all([...tempDirectories].map((directory) => rm(directory, { recursive: true, force: true })));
  tempDirectories.clear();
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

test("live route requires consent and a valid JPEG before calling its provider", async () => {
  let calls = 0;
  const baseURL = await startServer({
    env: { PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1", DEEPSEEK_API_KEY: "test-only" },
    providers: { runLiveFoodScan: async () => { calls += 1; throw new Error("unexpected"); } },
  });
  const missingConsent = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: false, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(missingConsent.status, 400);
  const invalidImage = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(invalidImage.status, 400);
  assert.equal(calls, 0);
});

test("live route accepts one consented valid image, then blocks a second provider call", async () => {
  let calls = 0;
  const liveTestMarkerPath = await newLiveTestMarkerPath();
  const sourceImage = await jpegBytes();
  const result = {
    mode: "live",
    candidate: { foodDescription: "Pear", portion: "1 medium", grams: 170, notes: "Estimate", calories: 97, fdcMatches: [], nutritionSource: "USDA FoodData Central" },
    notice: "Estimate; review before saving.",
  };
  const baseURL = await startServer({
    env: { PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1", DEEPSEEK_API_KEY: "test-only", FDC_API_KEY: "DEMO_KEY" },
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
      return result;
    } },
  });
  const healthBefore = await fetch(`${baseURL}/healthz`);
  assert.equal((await healthBefore.json()).oneShotTestEligible, true);
  const body = { mode: "live", consent: true, imageBase64: sourceImage.toString("base64"), mimeType: "image/jpeg" };
  const first = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
  });
  assert.equal(first.status, 200);
  assert.deepEqual(await first.json(), result);
  const second = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
  });
  assert.equal(second.status, 409);
  assert.equal(calls, 1);
  const healthAfter = await fetch(`${baseURL}/healthz`);
  assert.equal((await healthAfter.json()).oneShotTestEligible, false);

  const restartedURL = await startServer({
    env: { PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1", DEEPSEEK_API_KEY: "test-only", FDC_API_KEY: "DEMO_KEY" },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async () => { calls += 1; return result; } },
  });
  const healthAfterRestart = await fetch(`${restartedURL}/healthz`);
  assert.equal((await healthAfterRestart.json()).oneShotTestEligible, false);
  const afterRestart = await fetch(`${restartedURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
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

test("continuous live mode reports health mode live and allows multiple scans without marker", async () => {
  let calls = 0;
  const liveTestMarkerPath = await newLiveTestMarkerPath();
  const sourceImage = await jpegBytes();
  const result = {
    mode: "live",
    candidate: { foodDescription: "Pear", portion: "1 medium", grams: 170, notes: "Estimate", calories: 97, fdcMatches: [], nutritionSource: "USDA FoodData Central" },
    notice: "Estimate; review before saving.",
  };
  const baseURL = await startServer({
    env: { PANDAPLATE_ENABLE_LIVE_SCAN: "1", DEEPSEEK_API_KEY: "test-only", FDC_API_KEY: "DEMO_KEY" },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async (input) => {
      calls += 1;
      assert.equal(input.deepSeekApiKey, "test-only");
      assert.equal(input.fdcApiKey, "DEMO_KEY");
      return result;
    } },
  });
  const health = await fetch(`${baseURL}/healthz`);
  assert.deepEqual(await health.json(), {
    status: "ok",
    mode: "live",
    oneShotTestEligible: false,
    continuousLive: true,
  });
  const body = { mode: "live", consent: true, imageBase64: sourceImage.toString("base64"), mimeType: "image/jpeg" };
  const first = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
  });
  assert.equal(first.status, 200);
  const second = await fetch(`${baseURL}/v1/scan`, {
    method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body),
  });
  assert.equal(second.status, 200);
  assert.equal(calls, 2);
  // Marker must not be claimed in continuous mode.
  await assert.rejects(readFile(liveTestMarkerPath), { code: "ENOENT" });
});

function rawGet(baseURL, path) {
  const url = new URL(baseURL);
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path,
      method: "GET",
    }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => resolve({
        status: res.statusCode,
        body: Buffer.concat(chunks).toString("utf8"),
      }));
    });
    req.on("error", reject);
    req.end();
  });
}

test("unknown paths do not return repository files", async () => {
  const baseURL = await startServer();
  for (const path of ["/../.env", "/package.json", "/%2e%2e/package.json", "/v1/scan/preview/../../package.json"]) {
    const response = await rawGet(baseURL, path);
    assert.equal(response.status, 404);
    assert.equal(response.body, JSON.stringify({ error: "not_found" }));
    assert.doesNotMatch(response.body, /DEEPSEEK|PRIVATE KEY|node_modules/);
  }
});

test("non-loopback listen is refused unless LAN mode and a long token are both set", () => {
  assert.equal(listenConfigurationError("127.0.0.1", {}), null);
  assert.equal(listenConfigurationError("localhost", {}), null);
  assert.match(listenConfigurationError("0.0.0.0", {}), /Refusing to listen/);
  assert.match(listenConfigurationError("0.0.0.0", { PANDAPLATE_ALLOW_LAN: "1" }), /Refusing to listen/);
  assert.match(listenConfigurationError("0.0.0.0", {
    PANDAPLATE_ALLOW_LAN: "1",
    PANDAPLATE_SCAN_TOKEN: "short",
  }), /Refusing to listen/);
  assert.equal(listenConfigurationError("192.168.1.20", {
    PANDAPLATE_ALLOW_LAN: "1",
    PANDAPLATE_SCAN_TOKEN: "test-token-not-a-real-secret-01",
  }), null);
});

test("a scan token rejects unauthenticated callers before a provider call or one-shot claim", async () => {
  let calls = 0;
  const liveTestMarkerPath = await newLiveTestMarkerPath();
  const token = "test-token-not-a-real-secret-01";
  const baseURL = await startServer({
    env: {
      PANDAPLATE_ENABLE_ONE_LIVE_TEST: "1",
      DEEPSEEK_API_KEY: "test-only",
      PANDAPLATE_SCAN_TOKEN: token,
    },
    liveTestMarkerPath,
    providers: { runLiveFoodScan: async () => { calls += 1; throw new Error("unexpected"); } },
  });
  const denied = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(denied.status, 401);
  assert.deepEqual(await denied.json(), { error: "unauthorized" });
  const wrong = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: "Bearer wrong-token-value-not-the-real-one",
    },
    body: JSON.stringify({ mode: "live", consent: true, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(wrong.status, 401);
  assert.equal(calls, 0);
  const health = await fetch(`${baseURL}/healthz`);
  assert.equal((await health.json()).oneShotTestEligible, true);
  const preview = await fetch(`${baseURL}/v1/scan/preview`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${token}` },
    body: JSON.stringify({ mode: "mock" }),
  });
  assert.equal(preview.status, 200);
});

test("continuous live mode still requires explicit consent", async () => {
  let calls = 0;
  const baseURL = await startServer({
    env: { PANDAPLATE_ENABLE_LIVE_SCAN: "1", DEEPSEEK_API_KEY: "test-only" },
    providers: { runLiveFoodScan: async () => { calls += 1; throw new Error("unexpected"); } },
  });
  const missingConsent = await fetch(`${baseURL}/v1/scan`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ mode: "live", consent: false, imageBase64: "AA==", mimeType: "image/jpeg" }),
  });
  assert.equal(missingConsent.status, 400);
  assert.deepEqual(await missingConsent.json(), { error: "explicit_live_consent_required" });
  assert.equal(calls, 0);
});
