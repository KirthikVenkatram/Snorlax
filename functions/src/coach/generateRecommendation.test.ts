import { generateRecommendationHandler } from './generateRecommendation';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';
import { AiProvider } from '../ai/aiProvider';

function fakeProvider(response: string): AiProvider {
  return {
    generateCoachRecommendation: jest.fn().mockResolvedValue(response),
    summarizeProgress: jest.fn(),
    generateMealPlanProposal: jest.fn(),
  };
}

describe('generateRecommendationHandler', () => {
  it('writes a valid recommendation to coachRecommendations', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'Stay the course',
        rationale: 'Adherence and readiness both look solid.',
        proposedCommand: null,
      }),
    );

    const { id } = await generateRecommendationHandler('u1', db, provider);

    const stored = await db.getDoc(`users/u1/coachRecommendations/${id}`);
    expect(stored).toMatchObject({
      summary: 'Stay the course',
      rationale: 'Adherence and readiness both look solid.',
      proposedCommand: null,
      status: 'pending',
    });
  });

  it('includes the context and a preliminary validation result on the stored doc', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/nutritionGoals/goals': { dailyCalories: 2200, proteinG: 170, carbsG: 220, fatG: 70 },
    });
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'Small deficit',
        rationale: 'Progress has stalled.',
        proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 2000, proteinG: 170, carbsG: 180, fatG: 60 },
      }),
    );

    const { id } = await generateRecommendationHandler('u1', db, provider);
    const stored = await db.getDoc(`users/u1/coachRecommendations/${id}`);
    expect(stored?.context).toMatchObject({ nutrition: { dailyCalorieTarget: 2200 } });
    expect(stored?.preliminaryValidation).toMatchObject({ result: 'allow' });
  });

  it('never writes a recommendation when the provider output fails schema validation', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider('not json at all');

    await expect(generateRecommendationHandler('u1', db, provider)).rejects.toThrow();
    expect(Object.keys(db.dump())).toHaveLength(0);
  });

  it('never writes a recommendation when proposedCommand has an invalid shape', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'ok',
        rationale: 'ok',
        proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 'a lot' },
      }),
    );

    await expect(generateRecommendationHandler('u1', db, provider)).rejects.toThrow();
    expect(Object.keys(db.dump())).toHaveLength(0);
  });
});
