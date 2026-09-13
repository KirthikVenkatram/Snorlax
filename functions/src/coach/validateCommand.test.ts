import { validateCommand } from './validateCommand';
import { CoachContext, coachContextSchemaVersion } from './buildCoachContext';
import {
  ProposedGoalChange,
  ProposedHabitChange,
  ProposedNutritionTargetChange,
  ProposedWorkoutChange,
} from '../ai/schemas';

function fixtureContext(overrides: Partial<CoachContext> = {}): CoachContext {
  return {
    contextSchemaVersion: coachContextSchemaVersion,
    generatedAt: '2026-01-01T00:00:00.000Z',
    goals: { activePrimary: null, activeSecondaryCount: 0 },
    nutrition: { dailyCalorieTarget: 2200, proteinTargetG: 170, carbsTargetG: 220, fatTargetG: 70 },
    adherence: { latestWeeklyOverallScore: 0.8 },
    readiness: { latestLevel: 'green', latestSafetyOverrideTriggered: false },
    habits: { activeCount: 3 },
    ...overrides,
  };
}

describe('validateCommand — nutritionTargetChange', () => {
  it('rejects a target below the safe floor', () => {
    const command: ProposedNutritionTargetChange = {
      type: 'nutritionTargetChange',
      dailyCalories: 900,
      proteinG: 100,
      carbsG: 100,
      fatG: 30,
    };
    const result = validateCommand(command, fixtureContext());
    expect(result.result).toBe('reject');
  });

  it('rejects negative macro targets even if calories are in range', () => {
    const command: ProposedNutritionTargetChange = {
      type: 'nutritionTargetChange',
      dailyCalories: 2000,
      proteinG: -10,
      carbsG: 200,
      fatG: 60,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('reject');
  });

  it('requires approval for a large calorie change from the current target', () => {
    const command: ProposedNutritionTargetChange = {
      type: 'nutritionTargetChange',
      dailyCalories: 2900,
      proteinG: 170,
      carbsG: 220,
      fatG: 70,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('requireApproval');
  });

  it('allows a small in-bounds calorie change', () => {
    const command: ProposedNutritionTargetChange = {
      type: 'nutritionTargetChange',
      dailyCalories: 2150,
      proteinG: 170,
      carbsG: 220,
      fatG: 70,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('allow');
  });
});

describe('validateCommand — goalChange (one-active-primary-goal invariant)', () => {
  it('rejects a new active primary goal when one is already active', () => {
    const command: ProposedGoalChange = {
      type: 'goalChange',
      goalId: null,
      name: 'New primary goal',
      category: 'primary',
      status: 'active',
      priority: 1,
      targetValue: null,
      unit: null,
    };
    const context = fixtureContext({
      goals: { activePrimary: { id: 'existing-goal', name: 'Existing', targetValue: null, unit: null }, activeSecondaryCount: 0 },
    });
    expect(validateCommand(command, context).result).toBe('reject');
  });

  it('rejects activating a *different* goal as primary while another is already active', () => {
    const command: ProposedGoalChange = {
      type: 'goalChange',
      goalId: 'other-goal',
      name: 'Other goal',
      category: 'primary',
      status: 'active',
      priority: 1,
      targetValue: null,
      unit: null,
    };
    const context = fixtureContext({
      goals: { activePrimary: { id: 'existing-goal', name: 'Existing', targetValue: null, unit: null }, activeSecondaryCount: 0 },
    });
    expect(validateCommand(command, context).result).toBe('reject');
  });

  it('does not reject editing the *same* already-active primary goal', () => {
    const command: ProposedGoalChange = {
      type: 'goalChange',
      goalId: 'existing-goal',
      name: 'Existing (renamed)',
      category: 'primary',
      status: 'active',
      priority: 1,
      targetValue: 10,
      unit: 'kg',
    };
    const context = fixtureContext({
      goals: { activePrimary: { id: 'existing-goal', name: 'Existing', targetValue: null, unit: null }, activeSecondaryCount: 0 },
    });
    expect(validateCommand(command, context).result).not.toBe('reject');
  });

  it('rejects a negative or non-integer priority', () => {
    const command: ProposedGoalChange = {
      type: 'goalChange',
      goalId: null,
      name: 'Goal',
      category: 'physique',
      status: 'active',
      priority: -1,
      targetValue: null,
      unit: null,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('reject');
  });

  it('requires approval for an otherwise-fine goal change', () => {
    const command: ProposedGoalChange = {
      type: 'goalChange',
      goalId: null,
      name: 'Physique goal',
      category: 'physique',
      status: 'active',
      priority: 2,
      targetValue: null,
      unit: null,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('requireApproval');
  });
});

describe('validateCommand — habitChange', () => {
  it('rejects a weekly habit missing timesPerWeek', () => {
    const command: ProposedHabitChange = {
      type: 'habitChange',
      habitId: null,
      name: 'Lift weights',
      cadence: 'weekly',
      timesPerWeek: null,
      archived: false,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('reject');
  });

  it('rejects a weekly habit with timesPerWeek out of range', () => {
    const command: ProposedHabitChange = {
      type: 'habitChange',
      habitId: null,
      name: 'Lift weights',
      cadence: 'weekly',
      timesPerWeek: 9,
      archived: false,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('reject');
  });

  it('allows a well-formed daily habit', () => {
    const command: ProposedHabitChange = {
      type: 'habitChange',
      habitId: null,
      name: 'Drink water',
      cadence: 'daily',
      timesPerWeek: null,
      archived: false,
    };
    expect(validateCommand(command, fixtureContext()).result).toBe('allow');
  });
});

describe('validateCommand — workoutChange and readiness hard-safety red', () => {
  it('requires approval (never auto-allows) when readiness is red', () => {
    const command: ProposedWorkoutChange = { type: 'workoutChange', description: 'Heavy squat day' };
    const context = fixtureContext({ readiness: { latestLevel: 'red', latestSafetyOverrideTriggered: false } });
    expect(validateCommand(command, context).result).toBe('requireApproval');
  });

  it('requires approval when a safety override has been triggered even if level is not red', () => {
    const command: ProposedWorkoutChange = { type: 'workoutChange', description: 'Rest day' };
    const context = fixtureContext({ readiness: { latestLevel: 'yellow', latestSafetyOverrideTriggered: true } });
    expect(validateCommand(command, context).result).toBe('requireApproval');
  });

  it('always requires approval for workout proposals, even on a green day', () => {
    const command: ProposedWorkoutChange = { type: 'workoutChange', description: 'Easy jog' };
    expect(validateCommand(command, fixtureContext()).result).toBe('requireApproval');
  });
});
