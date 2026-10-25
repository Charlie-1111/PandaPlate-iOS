import sharp from "sharp";

const DEEPSEEK_URL = "https://api.deepseek.com/chat/completions";
const FDC_SEARCH_URL = "https://api.nal.usda.gov/fdc/v1/foods/search";
const MAX_DECODED_PIXELS = 20_000_000;
const MAX_IMAGE_OUTPUT_BYTES = 1_000_000;
const MAX_IMAGE_DIMENSION = 1_200;
const MAX_DEEPSEEK_RESPONSE_BYTES = 128_000;
const MAX_FDC_RESPONSE_BYTES = 256_000;

function finiteNumber(value, min, max) {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
}

export function parseVisionJSON(content) {
  if (typeof content !== "string" || content.length > 8_000) throw new Error("invalid_provider_response");
  const parsed = JSON.parse(content);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("invalid_provider_response");
  const foodName = typeof parsed.foodName === "string" ? parsed.foodName.trim().slice(0, 120) : "";
  const portionDescription = typeof parsed.portionDescription === "string" ? parsed.portionDescription.trim().slice(0, 120) : "";
  const notes = typeof parsed.notes === "string" ? parsed.notes.trim().slice(0, 240) : "";
  const estimatedGrams = finiteNumber(parsed.estimatedGrams, 1, 3_000) ? Math.round(parsed.estimatedGrams) : null;
  const confidence = finiteNumber(parsed.confidence, 0, 1) ? Math.round(parsed.confidence * 100) / 100 : null;
  if (!foodName) throw new Error("no_food_detected");
  return { foodName, portionDescription, estimatedGrams, confidence, notes };
}

function nutrientAmount(food, nutrientId, maximum) {
  const nutrient = Array.isArray(food?.foodNutrients)
    ? food.foodNutrients.find((item) => Number(item?.nutrientId) === nutrientId)
    : null;
  const rawAmount = nutrient?.value ?? nutrient?.amount;
  if (rawAmount === null || rawAmount === undefined || rawAmount === "") return null;
  const amount = typeof rawAmount === "number" ? rawAmount : Number(rawAmount);
  return Number.isFinite(amount) && amount >= 0 && amount <= maximum ? amount : null;
}

export function mapFoodMatch(food) {
  const fdcId = Number(food?.fdcId);
  const description = typeof food?.description === "string" ? food.description.trim().slice(0, 180) : "";
  return {
    fdcId: Number.isSafeInteger(fdcId) && fdcId > 0 && fdcId <= 100_000_000 ? fdcId : 0,
    description,
    dataType: String(food?.dataType ?? "").slice(0, 40),
    nutrientsPer100g: {
      caloriesKcal: nutrientAmount(food, 1008, 1_000),
      proteinG: nutrientAmount(food, 1003, 100),
      fatG: nutrientAmount(food, 1004, 100),
      carbohydrateG: nutrientAmount(food, 1005, 100),
      fiberG: nutrientAmount(food, 1079, 100),
    },
  };
}

async function readBoundedJSON(response, maximumBytes) {
  const announcedLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(announcedLength) && announcedLength > maximumBytes) {
    throw new Error("invalid_provider_response");
  }
  if (!response.body) throw new Error("invalid_provider_response");
  const reader = response.body.getReader();
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maximumBytes) {
      await reader.cancel();
      throw new Error("invalid_provider_response");
    }
    chunks.push(Buffer.from(value));
  }
  try {
    const text = new TextDecoder("utf-8", { fatal: true }).decode(Buffer.concat(chunks, total));
    return JSON.parse(text);
  } catch {
    throw new Error("invalid_provider_response");
  }
}

async function requestDeepSeekVision(imageBase64, mimeType, apiKey, fetchImpl = fetch) {
  const contentType = mimeType === "image/png" ? "image/png" : "image/jpeg";
  const prompt = `Identify the main clearly visible food item in this meal photo and provide a cautious visual portion estimate. Do not infer hidden ingredients, oils, sauces, or exact recipe composition. Do not estimate calories or other nutrients. If the portion cannot be judged, use null grams and explain briefly. If several foods are present, name the main visible item and mention other visible items in notes. Return valid json only in this exact shape: {"foodName":"plain generic food name","portionDescription":"short human-readable portion","estimatedGrams":150,"confidence":0.85,"notes":"brief uncertainty note"}. estimatedGrams must be a number or null. confidence must be a number from 0 to 1 or null. This confidence is not a calibrated probability. This is an uncertain visual estimate that a person will review.`;
  const response = await fetchImpl(DEEPSEEK_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "deepseek-flash",
      messages: [{
        role: "user",
        content: [
          { type: "text", text: prompt },
          { type: "image_url", image_url: { url: `data:${contentType};base64,${imageBase64}`, detail: "high" } },
        ],
      }],
      response_format: { type: "json_object" },
      max_tokens: 500,
      stream: false,
    }),
    signal: AbortSignal.timeout(30_000),
  });
  if (!response.ok) throw new Error("deepseek_request_failed");
  const payload = await readBoundedJSON(response, MAX_DEEPSEEK_RESPONSE_BYTES);
  return parseVisionJSON(payload?.choices?.[0]?.message?.content);
}

async function searchFDC(foodName, apiKey, fetchImpl = fetch) {
  const response = await fetchImpl(`${FDC_SEARCH_URL}?api_key=${encodeURIComponent(apiKey)}`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify({
      query: foodName,
      dataType: ["Foundation", "SR Legacy"],
      pageSize: 5,
      pageNumber: 1,
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error("usda_request_failed");
  const payload = await readBoundedJSON(response, MAX_FDC_RESPONSE_BYTES);
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Error("invalid_provider_response");
  return Array.isArray(payload.foods) ? payload.foods.slice(0, 5).map(mapFoodMatch).filter((food) => food.fdcId && food.description) : [];
}

export async function runLiveFoodScan({ imageBase64, mimeType, deepSeekApiKey, fdcApiKey = "DEMO_KEY", fetchImpl = fetch }) {
  if (!deepSeekApiKey) throw new Error("deepseek_key_missing");
  const vision = await requestDeepSeekVision(imageBase64, mimeType, deepSeekApiKey, fetchImpl);
  const fdcMatches = await searchFDC(vision.foodName, fdcApiKey, fetchImpl);
  const best = fdcMatches[0] ?? null;
  const kcalPer100g = best?.nutrientsPer100g.caloriesKcal ?? null;
  const estimatedCalories = kcalPer100g !== null && vision.estimatedGrams !== null
    ? Math.round((kcalPer100g * vision.estimatedGrams) / 100)
    : null;

  return {
    mode: "live",
    candidate: {
      foodDescription: vision.foodName,
      portion: vision.portionDescription || null,
      grams: vision.estimatedGrams,
      confidence: vision.confidence,
      notes: vision.notes || null,
      calories: estimatedCalories,
      fdcMatches,
      nutritionSource: best ? "USDA FoodData Central" : null,
    },
    notice: best
      ? "Visual food and portion are estimates. Calories are calculated from a USDA FoodData Central match; edit before saving."
      : "Food and portion are visual estimates. No USDA match was found, so calories remain unknown.",
  };
}

export function validateUploadedImage({ imageBase64, mimeType }) {
  if (typeof imageBase64 !== "string" || imageBase64.length === 0 || imageBase64.length > 1_400_000) return null;
  if (!/^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(imageBase64)) return null;
  if (mimeType !== "image/jpeg" && mimeType !== "image/png") return null;
  const buffer = Buffer.from(imageBase64, "base64");
  if (buffer.length === 0 || buffer.length > 1_000_000) return null;
  const jpeg = buffer.length >= 3 && buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff;
  const png = buffer.length >= 8 && buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
  if ((mimeType === "image/jpeg" && !jpeg) || (mimeType === "image/png" && !png)) {
    buffer.fill(0);
    return null;
  }
  return buffer;
}

export async function normalizeUploadedImage(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0 || buffer.length > MAX_IMAGE_OUTPUT_BYTES) {
    throw new Error("invalid_image");
  }
  const metadata = await sharp(buffer, { limitInputPixels: MAX_DECODED_PIXELS, failOn: "error" }).metadata();
  if (!metadata.width || !metadata.height
    || metadata.width * metadata.height > MAX_DECODED_PIXELS
    || (metadata.pages ?? 1) > 1) {
    throw new Error("invalid_image");
  }
  const output = await sharp(buffer, { limitInputPixels: MAX_DECODED_PIXELS, failOn: "error" })
    .rotate()
    .resize({ width: MAX_IMAGE_DIMENSION, height: MAX_IMAGE_DIMENSION, fit: "inside", withoutEnlargement: true })
    .jpeg({ quality: 75, mozjpeg: true })
    .toBuffer();
  if (!output.length || output.length > MAX_IMAGE_OUTPUT_BYTES) {
    output.fill(0);
    throw new Error("invalid_image");
  }
  return output;
}
