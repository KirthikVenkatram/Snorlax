import { handleCommandHandler } from './handleCommand';
import { createFakeCoachFirestore } from './fakeCoachFirestoreForTests';

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
