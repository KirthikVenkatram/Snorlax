import { buildCoachContext, coachContextSchemaVersion } from './buildCoachContext';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';

describe('buildCoachContext', () => {
  it('produces a deterministic, versioned, compact context from fixture data', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/goals/g1': { name: 'Lose fat', category: 'primary', status: 'active', targetValue: 15, unit: '%bf' },
      'users/u1/goals/g2': { name: 'Run 5k', category: 'performance', status: 'active' },
      'users/u1/goals/g3': { name: 'Old goal', category: 'primary', status: 'archived' },
      'users/u1/nutritionGoals/goals': { dailyCalories: 2200, proteinG: 170, carbsG: 220, fatG: 70 },
      'users/u1/adherenceWeekly/2026-W01': { overallScore: 0.7 },
      'users/u1/adherenceWeekly/2026-W02': { overallScore: 0.85 },
      'users/u1/readiness/2026-01-05': { result: { level: 'yellow', safetyOverrideTriggered: false } },
      'users/u1/readiness/2026-01-06': { result: { level: 'red', safetyOverrideTriggered: true } },
      'users/u1/habits/h1': { name: 'Sleep 8h', archived: false },
      'users/u1/habits/h2': { name: 'Old habit', archived: true },
    });

    const context = await buildCoachContext(db, 'u1');

    expect(context.contextSchemaVersion).toBe(coachContextSchemaVersion);
    expect(context.goals.activePrimary).toEqual({ id: 'g1', name: 'Lose fat', targetValue: 15, unit: '%bf' });
    expect(context.goals.activeSecondaryCount).toBe(1);
    expect(context.nutrition).toEqual({
      dailyCalorieTarget: 2200,
      proteinTargetG: 170,
      carbsTargetG: 220,
      fatTargetG: 70,
    });
    expect(context.adherence.latestWeeklyOverallScore).toBe(0.85);
    expect(context.readiness).toEqual({ latestLevel: 'red', latestSafetyOverrideTriggered: true });
    expect(context.habits.activeCount).toBe(1);
    expect(typeof context.generatedAt).toBe('string');
  });

  it('never includes raw/unlisted fields — only the documented compact shape', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/goals/g1': {
        name: 'Lose fat',
        category: 'primary',
        status: 'active',
        secretMedicalNote: 'this must never leak into the context',
      },
    });
    const context = await buildCoachContext(db, 'u1');
    expect(JSON.stringify(context)).not.toContain('secretMedicalNote');
  });

  it('handles a user with no data at all without throwing', async () => {
    const db = createFakeCoachFirestore({});
    const context = await buildCoachContext(db, 'brand-new-user');
    expect(context).toEqual(
      expect.objectContaining({
        contextSchemaVersion: coachContextSchemaVersion,
        goals: { activePrimary: null, activeSecondaryCount: 0 },
        nutrition: { dailyCalorieTarget: null, proteinTargetG: null, carbsTargetG: null, fatTargetG: null },
        adherence: { latestWeeklyOverallScore: null },
        readiness: { latestLevel: null, latestSafetyOverrideTriggered: false },
        habits: { activeCount: 0 },
        mealPlanning: { budget: null, templates: [] },
      }),
    );
  });

  it('includes budget settings and a compact meal-template summary (Phase 8)', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/budgetSettings/current': { currency: 'USD', dailyLimit: 20, weeklyLimit: 120, monthlyLimit: null },
      'users/u1/mealTemplates/t1': {
        name: 'Chicken and rice',
        costPerServing: 3.5,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
      },
      'users/u1/mealTemplates/t2': {
        name: 'Untriced smoothie',
        costPerServing: null,
        caloriesPerServing: 300,
        proteinGPerServing: 20,
      },
    });

    const context = await buildCoachContext(db, 'u1');

    expect(context.mealPlanning.budget).toEqual({
      currency: 'USD',
      dailyLimit: 20,
      weeklyLimit: 120,
      monthlyLimit: null,
    });
    expect(context.mealPlanning.templates).toEqual(
      expect.arrayContaining([
        { id: 't1', name: 'Chicken and rice', costPerServing: 3.5, caloriesPerServing: 550, proteinGPerServing: 45 },
        { id: 't2', name: 'Untriced smoothie', costPerServing: null, caloriesPerServing: 300, proteinGPerServing: 20 },
      ]),
    );
  });
});
