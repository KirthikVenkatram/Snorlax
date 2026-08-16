import { searchFoodHandler } from './searchFood';
import * as foodSources from './foodSources';

jest.mock('./foodSources');

describe('searchFoodHandler', () => {
  it('merges results from all three sources', async () => {
    (foodSources.searchUsda as jest.Mock).mockResolvedValue([
      { name: 'White Rice', source: 'usda', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3 },
    ]);
    (foodSources.searchOpenFoodFacts as jest.Mock).mockResolvedValue([
      { name: 'Basmati Rice', source: 'openFoodFacts', caloriesPer100g: 121, proteinPer100g: 3.5, carbsPer100g: 25, fatPer100g: 0.4 },
    ]);
    (foodSources.searchNutritionix as jest.Mock).mockResolvedValue([
      { name: 'Cooked Rice', source: 'nutritionix', caloriesPer100g: 128, proteinPer100g: 2.4, carbsPer100g: 28, fatPer100g: 0.2 },
    ]);

    const result = await searchFoodHandler('rice');

    expect(result.results).toHaveLength(3);
    expect(result.results.map((r) => r.source)).toEqual(
      expect.arrayContaining(['usda', 'openFoodFacts', 'nutritionix']),
    );
  });

  it('tolerates one source failing and still returns the others', async () => {
    (foodSources.searchUsda as jest.Mock).mockResolvedValue([
      { name: 'White Rice', source: 'usda', caloriesPer100g: 130, proteinPer100g: 2.7, carbsPer100g: 28, fatPer100g: 0.3 },
    ]);
    (foodSources.searchOpenFoodFacts as jest.Mock).mockRejectedValue(new Error('OFF down'));
    (foodSources.searchNutritionix as jest.Mock).mockResolvedValue([]);

    const result = await searchFoodHandler('rice');

    expect(result.results).toHaveLength(1);
    expect(result.results[0].source).toBe('usda');
  });

  it('returns an empty list if every source fails', async () => {
    (foodSources.searchUsda as jest.Mock).mockRejectedValue(new Error('down'));
    (foodSources.searchOpenFoodFacts as jest.Mock).mockRejectedValue(new Error('down'));
    (foodSources.searchNutritionix as jest.Mock).mockRejectedValue(new Error('down'));

    const result = await searchFoodHandler('anything');

    expect(result.results).toEqual([]);
  });
});
