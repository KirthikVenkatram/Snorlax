export interface FoodSearchHit {
  name: string;
  source: 'usda' | 'openFoodFacts' | 'nutritionix';
  caloriesPer100g: number;
  proteinPer100g: number;
  carbsPer100g: number;
  fatPer100g: number;
}

// Read at call time (not module load) so emulator/test setups that populate
// the environment after import still see the configured credentials.
function usdaApiKey(): string {
  return process.env.USDA_API_KEY ?? '';
}

function nutritionixCredentials(): { appId: string; appKey: string } {
  return {
    appId: process.env.NUTRITIONIX_APP_ID ?? '',
    appKey: process.env.NUTRITIONIX_APP_KEY ?? '',
  };
}

function nutrientValue(nutrients: Array<{ nutrientName: string; value: number }>, name: string): number {
  return nutrients.find((n) => n.nutrientName === name)?.value ?? 0;
}

export async function searchUsda(query: string): Promise<FoodSearchHit[]> {
  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(query)}&pageSize=5&api_key=${usdaApiKey()}`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`USDA search failed: ${response.status}`);
  }
  const data = (await response.json()) as { foods?: Array<{ description: string; foodNutrients: Array<{ nutrientName: string; value: number }> }> };
  return (data.foods ?? []).map((food) => ({
    name: food.description,
    source: 'usda' as const,
    caloriesPer100g: nutrientValue(food.foodNutrients, 'Energy'),
    proteinPer100g: nutrientValue(food.foodNutrients, 'Protein'),
    carbsPer100g: nutrientValue(food.foodNutrients, 'Carbohydrate, by difference'),
    fatPer100g: nutrientValue(food.foodNutrients, 'Total lipid (fat)'),
  }));
}

export async function searchOpenFoodFacts(query: string): Promise<FoodSearchHit[]> {
  const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=5`;
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Open Food Facts search failed: ${response.status}`);
  }
  const data = (await response.json()) as {
    products?: Array<{ product_name?: string; nutriments?: Record<string, number> }>;
  };
  return (data.products ?? [])
    .filter((p) => p.product_name && p.nutriments)
    .map((p) => ({
      name: p.product_name!,
      source: 'openFoodFacts' as const,
      caloriesPer100g: p.nutriments?.['energy-kcal_100g'] ?? 0,
      proteinPer100g: p.nutriments?.['proteins_100g'] ?? 0,
      carbsPer100g: p.nutriments?.['carbohydrates_100g'] ?? 0,
      fatPer100g: p.nutriments?.['fat_100g'] ?? 0,
    }));
}

export async function searchNutritionix(query: string): Promise<FoodSearchHit[]> {
  const { appId, appKey } = nutritionixCredentials();
  const response = await fetch('https://trackapi.nutritionix.com/v2/natural/nutrients', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-app-id': appId,
      'x-app-key': appKey,
    },
    body: JSON.stringify({ query }),
  });
  if (!response.ok) {
    throw new Error(`Nutritionix search failed: ${response.status}`);
  }
  const data = (await response.json()) as {
    foods?: Array<{
      food_name: string;
      serving_weight_grams: number;
      nf_calories: number;
      nf_protein: number;
      nf_total_carbohydrate: number;
      nf_total_fat: number;
    }>;
  };
  return (data.foods ?? []).map((food) => {
    const grams = food.serving_weight_grams || 100;
    const scale = 100 / grams;
    return {
      name: food.food_name,
      source: 'nutritionix' as const,
      caloriesPer100g: food.nf_calories * scale,
      proteinPer100g: food.nf_protein * scale,
      carbsPer100g: food.nf_total_carbohydrate * scale,
      fatPer100g: food.nf_total_fat * scale,
    };
  });
}
