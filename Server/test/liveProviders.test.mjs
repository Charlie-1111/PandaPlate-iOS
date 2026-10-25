import assert from "node:assert/strict";
import { test } from "node:test";
import { mapFoodMatch, parseVisionJSON, runLiveFoodScan } from "../src/liveProviders.mjs";

const jsonResponse = (value) => new Response(JSON.stringify(value), {
  status: 200,
  headers: { "content-type": "application/json" },
});

test("vision response bounds strings and discards out-of-range estimates", () => {
  const parsed = parseVisionJSON(JSON.stringify({
    foodName: "  Pear slices  ",
    portionDescription: "A plate",
    estimatedGrams: 3_001,
    confidence: 1.4,
    notes: "x".repeat(300),
  }));
  assert.equal(parsed.foodName, "Pear slices");
  assert.equal(parsed.estimatedGrams, null);
  assert.equal(parsed.confidence, null);
  assert.equal(parsed.notes.length, 240);
  assert.throws(() => parseVisionJSON("not json"));
  assert.throws(() => parseVisionJSON("null"), /invalid_provider_response/);
  assert.throws(() => parseVisionJSON(JSON.stringify({ foodName: " " })), /no_food_detected/);
});

test("FDC missing and invalid nutrient values remain unknown", () => {
  const match = mapFoodMatch({
    fdcId: 169118,
    description: "Pears, raw",
    dataType: "Foundation",
    foodNutrients: [
      { nutrientId: 1008, value: null },
      { nutrientId: 1003, value: "not-number" },
      { nutrientId: 1004, value: -1 },
      { nutrientId: 1005, value: 140 },
      { nutrientId: 1079, value: 140 },
    ],
  });
  assert.equal(match.nutrientsPer100g.caloriesKcal, null);
  assert.equal(match.nutrientsPer100g.proteinG, null);
  assert.equal(match.nutrientsPer100g.fatG, null);
  assert.equal(match.nutrientsPer100g.carbohydrateG, null);
  assert.equal(match.nutrientsPer100g.fiberG, null);
});

test("oversized provider response is rejected before JSON parsing", async () => {
  const fetchImpl = async () => new Response(new Uint8Array(128_001), { status: 200 });
  await assert.rejects(runLiveFoodScan({
    imageBase64: "AA==",
    mimeType: "image/jpeg",
    deepSeekApiKey: "fake-token",
    fetchImpl,
  }), /invalid_provider_response/);
});

test("food vision is followed by an FDC lookup and scaled nutrients", async () => {
  const requests = [];
  const fetchImpl = async (url, options) => {
    requests.push({ url: String(url), options });
    if (String(url).includes("chat/completions")) {
      return jsonResponse({ choices: [{ message: { content: JSON.stringify({
        foodName: "pear",
        portionDescription: "one medium pear",
        estimatedGrams: 170,
        confidence: 0.85,
        notes: "Weight is approximate.",
      }) } }] });
    }
    return jsonResponse({ foods: [{
      fdcId: 169118,
      description: "Pears, raw",
      dataType: "Foundation",
      foodNutrients: [
        { nutrientId: 1008, value: 57 },
        { nutrientId: 1003, value: 0.36 },
        { nutrientId: 1004, value: 0.14 },
        { nutrientId: 1005, value: 15.23 },
        { nutrientId: 1079, value: 3.1 },
      ],
    }] });
  };

  const result = await runLiveFoodScan({
    imageBase64: Buffer.from([0xff, 0xd8, 0xff, 0xd9]).toString("base64"),
    mimeType: "image/jpeg",
    deepSeekApiKey: "test-token-only",
    fdcApiKey: "DEMO_KEY",
    fetchImpl,
  });

  assert.equal(requests.length, 2);
  assert.match(requests[0].url, /api\.deepseek\.com\/chat\/completions/);
  assert.equal(requests[0].options.headers.Authorization, "Bearer test-token-only");
  assert.match(requests[1].url, /api\.nal\.usda\.gov\/fdc\/v1\/foods\/search/);
  assert.match(requests[1].url, /api_key=DEMO_KEY/);
  assert.equal(JSON.parse(requests[1].options.body).query, "pear");
  assert.equal(result.candidate.grams, 170);
  assert.equal(result.candidate.confidence, 0.85);
  assert.equal(result.candidate.calories, 97);
  assert.equal(result.candidate.fdcMatches[0].nutrientsPer100g.fiberG, 3.1);
});
