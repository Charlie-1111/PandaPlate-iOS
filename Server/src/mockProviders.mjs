// Local stand-in. This function intentionally makes no network calls and reads no credentials.
export async function createMockScanPreview() {
  return {
    mode: "mock",
    candidate: {
      foodDescription: "Example meal",
      portion: null,
      grams: null,
      confidence: null,
      notes: "Example only; not generated from a photo.",
      calories: null,
      fdcMatches: [],
      nutritionSource: null,
    },
    notice: "Local mock only. No photo was sent; DeepSeek and USDA were not contacted.",
  };
}
