import { estimateNutritionHandler } from './estimateNutrition';
import * as llmClient from './llmClient';

jest.mock('./llmClient');

describe('estimateNutritionHandler', () => {
  it('parses an LLM nutrition estimate into structured fields', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      '{"caloriesPer100g": 195, "proteinPer100g": 6, "carbsPer100g": 40, "fatPer100g": 1.5}',
    );

    const result = await estimateNutritionHandler('Idli');

    expect(result).toEqual({
      caloriesPer100g: 195,
      proteinPer100g: 6,
      carbsPer100g: 40,
      fatPer100g: 1.5,
    });
  });

  it('throws if the model response has no parseable JSON object', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('no idea');

    await expect(estimateNutritionHandler('Unknown Food')).rejects.toThrow();
  });
});
