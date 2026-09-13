import { defaultAiProvider } from './aiProvider';
import * as llmClient from '../llmClient';

jest.mock('../llmClient');

describe('defaultAiProvider', () => {
  it('routes generateCoachRecommendation through llmClient.generateText', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('{"summary":"ok"}');
    const result = await defaultAiProvider.generateCoachRecommendation('prompt');
    expect(result).toBe('{"summary":"ok"}');
    expect(llmClient.generateText).toHaveBeenCalledWith('prompt');
  });

  it('routes summarizeProgress through llmClient.generateText', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('summary text');
    const result = await defaultAiProvider.summarizeProgress('prompt');
    expect(result).toBe('summary text');
    expect(llmClient.generateText).toHaveBeenCalledWith('prompt');
  });

  it('routes generateMealPlanProposal through llmClient.generateText (Phase 8 stub)', async () => {
    (llmClient.generateText as jest.Mock).mockResolvedValue('meal plan text');
    const result = await defaultAiProvider.generateMealPlanProposal('prompt');
    expect(result).toBe('meal plan text');
    expect(llmClient.generateText).toHaveBeenCalledWith('prompt');
  });
});
