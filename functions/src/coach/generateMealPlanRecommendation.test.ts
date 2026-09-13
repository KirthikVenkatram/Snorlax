import { generateMealPlanRecommendationHandler } from './generateMealPlanRecommendation';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';
import { AiProvider } from '../ai/aiProvider';

function fakeProvider(response: string): AiProvider {
  return {
    generateCoachRecommendation: jest.fn(),
    summarizeProgress: jest.fn(),
    generateMealPlanProposal: jest.fn().mockResolvedValue(response),
  };
}

describe('generateMealPlanRecommendationHandler', () => {
  it('writes a valid mealPlanChange recommendation, computed from real template/budget context', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/budgetSettings/current': { currency: 'USD', dailyLimit: 20, weeklyLimit: null, monthlyLimit: null },
      'users/u1/mealTemplates/t1': {
        name: 'Chicken and rice',
        costPerServing: 3.5,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
      },
    });
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'A simple daily plan',
        rationale: 'Fits comfortably within your daily budget.',
        proposedCommand: {
          type: 'mealPlanChange',
          planId: null,
          name: 'Simple daily plan',
          periodType: 'daily',
          items: [{ templateId: 't1', servings: 2 }],
        },
      }),
    );

    const { id } = await generateMealPlanRecommendationHandler('u1', db, provider);

    const stored = await db.getDoc(`users/u1/coachRecommendations/${id}`);
    expect(stored).toMatchObject({ summary: 'A simple daily plan', status: 'pending' });
    expect(stored?.preliminaryValidation).toMatchObject({ result: 'requireApproval' });
    expect(provider.generateMealPlanProposal).toHaveBeenCalled();
  });

  it('passes budget and template data into the prompt sent to the provider', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/budgetSettings/current': { currency: 'USD', dailyLimit: 15, weeklyLimit: null, monthlyLimit: null },
      'users/u1/mealTemplates/t1': {
        name: 'Oats and yogurt',
        costPerServing: 1.5,
        caloriesPerServing: 350,
        proteinGPerServing: 20,
      },
    });
    const provider = fakeProvider(JSON.stringify({ summary: 'ok', rationale: 'ok', proposedCommand: null }));

    await generateMealPlanRecommendationHandler('u1', db, provider);

    const promptArg = (provider.generateMealPlanProposal as jest.Mock).mock.calls[0][0] as string;
    expect(promptArg).toContain('Oats and yogurt');
    expect(promptArg).toContain('15');
  });

  it('never writes a recommendation when the provider proposes a non-meal-plan command type', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'off topic',
        rationale: 'the model went rogue',
        proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 2000, proteinG: 150, carbsG: 200, fatG: 60 },
      }),
    );

    await expect(generateMealPlanRecommendationHandler('u1', db, provider)).rejects.toThrow();
    expect(Object.keys(db.dump())).toHaveLength(0);
  });

  it('never writes a recommendation when the provider output fails schema validation', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider('not json at all');

    await expect(generateMealPlanRecommendationHandler('u1', db, provider)).rejects.toThrow();
    expect(Object.keys(db.dump())).toHaveLength(0);
  });

  it('allows a null proposedCommand (advice-only, e.g. no templates exist yet)', async () => {
    const db = createFakeCoachFirestore();
    const provider = fakeProvider(
      JSON.stringify({
        summary: 'No templates yet',
        rationale: 'Create a meal template first so I can propose a plan.',
        proposedCommand: null,
      }),
    );

    const { id } = await generateMealPlanRecommendationHandler('u1', db, provider);
    const stored = await db.getDoc(`users/u1/coachRecommendations/${id}`);
    expect(stored).toMatchObject({ proposedCommand: null, status: 'pending' });
  });
});
