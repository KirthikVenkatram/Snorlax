import { parseFoodTextHandler } from './parseFoodText';
import * as llmClient from './llmClient';

jest.mock('./llmClient');

describe('parseFoodTextHandler', () => {
  it('parses natural language into structured food items', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      '[{"foodName": "Idli", "estimatedQuantityGrams": 150}, {"foodName": "Sambar", "estimatedQuantityGrams": 200}]',
    );

    const result = await parseFoodTextHandler('2 idlis and a cup of sambar');

    expect(result.items).toEqual([
      { foodName: 'Idli', estimatedQuantityGrams: 150 },
      { foodName: 'Sambar', estimatedQuantityGrams: 200 },
    ]);
  });

  it('extracts a JSON array even if the model wraps it in prose or markdown', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue(
      'Here you go:\n```json\n[{"foodName": "Rice", "estimatedQuantityGrams": 100}]\n```',
    );

    const result = await parseFoodTextHandler('rice');

    expect(result.items).toEqual([{ foodName: 'Rice', estimatedQuantityGrams: 100 }]);
  });

  it('throws if the model response has no parseable JSON array', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('I cannot help with that.');

    await expect(parseFoodTextHandler('gibberish')).rejects.toThrow();
  });
});
