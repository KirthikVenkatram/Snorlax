import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as foodSources from './foodSources';
import type { FoodSearchHit } from './foodSources';

export async function searchFoodHandler(query: string): Promise<{ results: FoodSearchHit[] }> {
  const settled = await Promise.allSettled([
    foodSources.searchUsda(query),
    foodSources.searchOpenFoodFacts(query),
    foodSources.searchNutritionix(query),
  ]);

  const results: FoodSearchHit[] = [];
  for (const outcome of settled) {
    if (outcome.status === 'fulfilled') {
      results.push(...outcome.value);
    } else {
      console.error('Food source search failed', outcome.reason);
    }
  }
  return { results };
}

export const searchFood = onCall(
  { secrets: ['USDA_API_KEY', 'NUTRITIONIX_APP_ID', 'NUTRITIONIX_APP_KEY'] },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Must be signed in.');
    }
    const query = request.data?.query as string | undefined;
    if (!query) {
      throw new HttpsError('invalid-argument', 'Missing search query.');
    }
    return searchFoodHandler(query);
  },
);
