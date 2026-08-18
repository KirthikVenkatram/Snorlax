import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as llmClient from './llmClient';

export interface ParsedFoodItem {
  foodName: string;
  estimatedQuantityGrams: number;
}

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

export async function parseFoodTextHandler(text: string): Promise<{ items: ParsedFoodItem[] }> {
  const prompt = `Extract each distinct food item from this meal description as a JSON array of objects with "foodName" and "estimatedQuantityGrams" (a reasonable gram estimate for the portion described). Respond with ONLY the JSON array, no other text.\n\nMeal description: "${text}"`;

  const response = await llmClient.generateText(prompt);
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

export const parseFoodText = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const text = request.data?.text as string | undefined;
    if (!text) {
      throw new HttpsError('invalid-argument', 'Missing meal description text.');
    }
    return parseFoodTextHandler(text);
  },
);
