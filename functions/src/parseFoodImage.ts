import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as llmClient from './llmClient';
import { ParsedFoodItem } from './parseFoodText';

/**
 * Extracts the first JSON array literal from a model response, tolerating
 * surrounding prose or a markdown code fence — models don't reliably return
 * bare JSON even when asked to.
 */
function extractJsonArray(text: string): unknown[] {
  const match = text.match(/\[[\s\S]*\]/);
  if (!match) {
    throw new Error('No JSON array found in model response');
  }
  return JSON.parse(match[0]) as unknown[];
}

export async function parseFoodImageHandler(
  imageBase64: string,
  mimeType: string,
): Promise<{ items: ParsedFoodItem[] }> {
  const prompt =
    'Identify each distinct food item visible in this photo of a meal. Respond with ' +
    'ONLY a JSON array of objects with "foodName" and "estimatedQuantityGrams" (a ' +
    'reasonable gram estimate for the visible portion), no other text.';

  const response = await llmClient.generateVisionText(prompt, imageBase64, mimeType);
  const parsed = extractJsonArray(response);

  const items: ParsedFoodItem[] = parsed.map((item) => {
    const record = item as Record<string, unknown>;
    return {
      foodName: String(record.foodName),
      estimatedQuantityGrams: Number(record.estimatedQuantityGrams),
    };
  });

  return { items };
}

export const parseFoodImage = onCall(
  { secrets: ['NVIDIA_NIM_API_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const imageBase64 = request.data?.imageBase64 as string | undefined;
    const mimeType = request.data?.mimeType as string | undefined;
    if (!imageBase64 || !mimeType) {
      throw new HttpsError('invalid-argument', 'Missing imageBase64 or mimeType.');
    }
    return parseFoodImageHandler(imageBase64, mimeType);
  },
);
