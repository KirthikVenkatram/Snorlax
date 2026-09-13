import { handleCommandHandler } from './handleCommand';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';

describe('handleCommandHandler — target deleted between recommendation and approval (review fix)', () => {
  it('gracefully fails with a coachEvents audit record, instead of throwing, when the update target no longer exists', async () => {
    // Mirrors the real Admin SDK: `.update()` on a missing doc throws
    // NOT_FOUND (see adminFirestore.ts) rather than silently upserting like
    // the lenient default fake does.
    const db = createFakeCoachFirestore(
      {
        'users/u1/coachRecommendations/r1': {
          proposedCommand: {
            type: 'goalChange',
            goalId: 'goal-that-was-deleted',
            name: 'Updated goal',
            category: 'physique',
            status: 'active',
            priority: 1,
            targetValue: null,
            unit: null,
          },
          status: 'pending',
        },
        // Note: no `users/u1/goals/goal-that-was-deleted` doc seeded — it
        // was deleted after the recommendation was generated but before the
        // user approved it.
      },
      { strictUpdate: true },
    );

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('failed');
    expect(result.reason).toMatch(/no longer exists/);

    const events = await db.getCollection('users/u1/coachEvents');
    expect(events).toHaveLength(1);
    expect(events[0].data).toMatchObject({ recommendationId: 'r1', outcome: 'failed', decision: 'approve' });

    const rec = await db.getDoc('users/u1/coachRecommendations/r1');
    expect(rec?.status).toBe('rejected');
  });
});

describe('handleCommandHandler', () => {
  it('applies an allowed nutritionTargetChange on approval and writes an audit event', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 2100, proteinG: 170, carbsG: 200, fatG: 70 },
        status: 'pending',
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('applied');
    const goals = await db.getDoc('users/u1/nutritionGoals/goals');
    expect(goals).toEqual({ dailyCalories: 2100, proteinG: 170, carbsG: 200, fatG: 70 });

    const events = await db.getCollection('users/u1/coachEvents');
    expect(events).toHaveLength(1);
    expect(events[0].data).toMatchObject({ recommendationId: 'r1', outcome: 'applied', decision: 'approve' });

    const rec = await db.getDoc('users/u1/coachRecommendations/r1');
    expect(rec?.status).toBe('accepted');
  });

  it('never mutates protected data when the user rejects', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: { type: 'nutritionTargetChange', dailyCalories: 2100, proteinG: 170, carbsG: 200, fatG: 70 },
        status: 'pending',
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'reject', db);

    expect(result.outcome).toBe('rejectedByUser');
    expect(await db.getDoc('users/u1/nutritionGoals/goals')).toBeNull();
    const events = await db.getCollection('users/u1/coachEvents');
    expect(events).toHaveLength(1);
    expect(events[0].data.outcome).toBe('rejectedByUser');
  });

  it('no-bypass: an "approve" decision cannot force through a command that fails fresh re-validation', async () => {
    // Simulates a stale client: the recommendation was generated when it
    // looked safe/allowed, but by the time the user approves it, context
    // has changed (here: dailyCalories has since dropped below the safe
    // floor would be an odd AI edit, so instead we simulate the more
    // realistic case — a second goal has since become active primary,
    // making this proposed goalChange now invalid) and a stale client-side
    // "allow" must not be trusted.
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: {
          type: 'goalChange',
          goalId: null,
          name: 'New primary goal',
          category: 'primary',
          status: 'active',
          priority: 1,
          targetValue: null,
          unit: null,
        },
        // A stale/forged client-side validation claiming this is safe —
        // handleCommand must ignore this entirely and recompute.
        preliminaryValidation: { result: 'allow', reason: 'stale' },
        status: 'pending',
      },
      // Context has since changed: another primary goal is now active.
      'users/u1/goals/existing': { name: 'Existing primary', category: 'primary', status: 'active' },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('rejectedByValidation');
    // No new goal document should have been created.
    const goals = await db.getCollection('users/u1/goals');
    expect(goals).toHaveLength(1);
    expect(goals[0].id).toBe('existing');
  });

  it('a decision of "approve" on a recommendation with no proposed command never mutates anything', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': { proposedCommand: null, status: 'pending' },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('rejectedByUser');
    expect(await db.getCollection('users/u1/goals')).toHaveLength(0);
  });

  it('applies a requireApproval command (e.g. workoutChange) as a no-op mutation but still logs an event', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: { type: 'workoutChange', description: 'Easy recovery jog' },
        status: 'pending',
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('applied');
    const events = await db.getCollection('users/u1/coachEvents');
    expect(events).toHaveLength(1);
  });

  it('throws for an unknown recommendation id', async () => {
    const db = createFakeCoachFirestore();
    await expect(handleCommandHandler('u1', 'missing', 'approve', db)).rejects.toThrow();
  });
});

describe('handleCommandHandler — mealPlanChange (Phase 8)', () => {
  it('applies an approved, in-budget mealPlanChange by writing a deterministically-computed mealPlans document', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: {
          type: 'mealPlanChange',
          planId: null,
          name: 'Weekday lunches',
          periodType: 'daily',
          items: [{ templateId: 't1', servings: 2 }],
        },
        status: 'pending',
      },
      'users/u1/budgetSettings/current': { currency: 'USD', dailyLimit: 20, weeklyLimit: null, monthlyLimit: null },
      'users/u1/mealTemplates/t1': {
        name: 'Chicken and rice',
        costPerServing: 3.5,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('applied');
    const plans = await db.getCollection('users/u1/mealPlans');
    expect(plans).toHaveLength(1);
    expect(plans[0].data).toMatchObject({
      name: 'Weekday lunches',
      periodType: 'daily',
      totalCost: 7,
      totalCalories: 1100,
      totalProteinG: 90,
      currency: 'USD',
      source: 'aiProposal',
    });
  });

  it('adversarial no-bypass: an approve decision cannot force through a mealPlanChange that now exceeds budget at fresh re-validation', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: {
          type: 'mealPlanChange',
          planId: null,
          name: 'Way too much food',
          periodType: 'daily',
          items: [{ templateId: 't1', servings: 10 }],
        },
        // A stale/forged client-side validation claiming this is fine.
        preliminaryValidation: { result: 'requireApproval', reason: 'stale' },
        status: 'pending',
      },
      // Budget is tight enough that 10 servings blows through it.
      'users/u1/budgetSettings/current': { currency: 'USD', dailyLimit: 20, weeklyLimit: null, monthlyLimit: null },
      'users/u1/mealTemplates/t1': {
        name: 'Chicken and rice',
        costPerServing: 3.5,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('rejectedByValidation');
    expect(await db.getCollection('users/u1/mealPlans')).toHaveLength(0);
  });

  it('rejects a mealPlanChange referencing an unknown template and never writes a mealPlans doc', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: {
          type: 'mealPlanChange',
          planId: null,
          name: 'Mystery meal',
          periodType: 'daily',
          items: [{ templateId: 'ghost', servings: 1 }],
        },
        status: 'pending',
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('rejectedByValidation');
    expect(await db.getCollection('users/u1/mealPlans')).toHaveLength(0);
  });

  it('updates an existing plan in place when planId is supplied', async () => {
    const db = createFakeCoachFirestore({
      'users/u1/coachRecommendations/r1': {
        proposedCommand: {
          type: 'mealPlanChange',
          planId: 'p1',
          name: 'Updated plan',
          periodType: 'daily',
          items: [{ templateId: 't1', servings: 1 }],
        },
        status: 'pending',
      },
      'users/u1/mealPlans/p1': { name: 'Old plan', createdAt: '2026-01-01T00:00:00.000Z' },
      'users/u1/mealTemplates/t1': {
        name: 'Chicken and rice',
        costPerServing: 3.5,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
      },
    });

    const result = await handleCommandHandler('u1', 'r1', 'approve', db);

    expect(result.outcome).toBe('applied');
    const plan = await db.getDoc('users/u1/mealPlans/p1');
    expect(plan).toMatchObject({ name: 'Updated plan', totalCost: 3.5, createdAt: '2026-01-01T00:00:00.000Z' });
    expect(await db.getCollection('users/u1/mealPlans')).toHaveLength(1);
  });
});
