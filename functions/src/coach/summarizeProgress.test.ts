import { summarizeProgressHandler } from './summarizeProgress';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';
import { AiProvider } from '../ai/aiProvider';

function fakeProvider(response: string): AiProvider {
  return {
    generateCoachRecommendation: jest.fn(),
    summarizeProgress: jest.fn().mockResolvedValue(response),
    generateMealPlanProposal: jest.fn(),
  };
}

describe('summarizeProgressHandler', () => {
  it('returns the trimmed AI provider text as the summary', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider('  Great week overall, keep it up!  ');

    const result = await summarizeProgressHandler('u1', db, provider);

    expect(result).toEqual({ summary: 'Great week overall, keep it up!' });
  });

  it('does not write anything to Firestore', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider('Solid progress this week.');

    await summarizeProgressHandler('u1', db, provider);

    expect(Object.keys(db.dump())).toHaveLength(0);
  });

  it('builds the prompt from the deterministic coach context', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/nutritionGoals/goals': { dailyCalories: 2200, proteinG: 170, carbsG: 220, fatG: 70 },
    });
    const provider = fakeProvider('ok');

    await summarizeProgressHandler('u1', db, provider);

    const promptArg = (provider.summarizeProgress as jest.Mock).mock.calls[0][0] as string;
    expect(promptArg).toContain('"dailyCalorieTarget":2200');
  });
});
