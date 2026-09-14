import { parseFoodImageHandler } from './parseFoodImage';
import * as llmClient from './llmClient';

jest.mock('./llmClient');

describe('parseFoodImageHandler', () => {
  it('parses a photo into structured food items', async () => {
    (llmClient.generateVisionText as jest.Mock).mockResolvedValue(
      '[{"foodName": "Grilled chicken", "estimatedQuantityGrams": 180}, {"foodName": "Rice", "estimatedQuantityGrams": 150}]',
    );

    const result = await parseFoodImageHandler('base64data', 'image/jpeg');

    expect(result.items).toEqual([
      { foodName: 'Grilled chicken', estimatedQuantityGrams: 180 },
      { foodName: 'Rice', estimatedQuantityGrams: 150 },
    ]);
    expect(llmClient.generateVisionText).toHaveBeenCalledWith(
      expect.any(String),
      'base64data',
      'image/jpeg',
    );
  });

  it('extracts a JSON array even if the model wraps it in prose or markdown', async () => {
    (llmClient.generateVisionText as jest.Mock).mockResolvedValue(
      'Here you go:\n```json\n[{"foodName": "Salad", "estimatedQuantityGrams": 120}]\n```',
    );

    const result = await parseFoodImageHandler('base64data', 'image/png');

    expect(result.items).toEqual([{ foodName: 'Salad', estimatedQuantityGrams: 120 }]);
  });

  it('throws if the model response has no parseable JSON array', async () => {
    (llmClient.generateVisionText as jest.Mock).mockResolvedValue("I can't tell what that is.");

    await expect(parseFoodImageHandler('base64data', 'image/jpeg')).rejects.toThrow();
  });
});
