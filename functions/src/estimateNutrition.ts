import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as llmClient from './llmClient';

export interface EstimatedNutrition {
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
}

/**
 * Extracts the first JSON object literal from a model response, tolerating
 * surrounding prose or a markdown code fence.
 */
function extractJsonObject(text: string): Record<string, unknown> {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    throw new Error('No JSON object found in model response');
  }
  return JSON.parse(match[0]) as Record<string, unknown>;
}

export async function estimateNutritionHandler(foodName: string): Promise<EstimatedNutrition> {
  const prompt = `Estimate the nutrition per 100g for this food as a JSON object with keys "caloriesPer100g", "proteinPer100g", "carbsPer100g", "fatPer100g" (all numbers). Respond with ONLY the JSON object, no other text.\n\nFood: "${foodName}"`;

  const response = await llmClient.generateText(prompt);
  const parsed = extractJsonObject(response);

  return {
    caloriesPer100g: Number(parsed.caloriesPer100g),
    proteinPer100g: Number(parsed.proteinPer100g),
    carbsPer100g: Number(parsed.carbsPer100g),
    fatPer100g: Number(parsed.fatPer100g),
  };
}

export const estimateNutrition = onCall(
  { secrets: ['GROQ_API_KEY', 'NVIDIA_NIM_API_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const foodName = request.data?.foodName as string | undefined;
    if (!foodName) {
      throw new HttpsError('invalid-argument', 'Missing foodName.');
    }
    return estimateNutritionHandler(foodName);
  },
);
