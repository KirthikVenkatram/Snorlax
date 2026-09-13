import { CoachContext } from './buildCoachContext';
import {
  ProposedCommand,
  ProposedGoalChange,
  ProposedHabitChange,
  ProposedMealPlanChange,
  ProposedNutritionTargetChange,
  ProposedWorkoutChange,
} from '../ai/schemas';
import { computeMealPlanCost } from './mealPlanCost';

export type ValidationResult = 'allow' | 'requireApproval' | 'reject';

export interface CommandValidation {
  result: ValidationResult;
  reason: string;
}

/**
 * Below this, a proposed daily calorie target is not a plausible safe
 * target for any adult regardless of goal — a hard floor independent of
 * the user's current target. This is deliberately conservative; it is not
 * a substitute for the nutrition goal calculator's per-user math, just a
 * last-line guard against an AI-hallucinated unsafe number ever reaching
 * a write.
 */
const MIN_SAFE_DAILY_CALORIES = 1200;

/**
 * A same-direction change in daily calorie target larger than this (from
 * the user's current target, when known) requires explicit approval rather
 * than being auto-allowed, even though it's not unsafe outright.
 */
const LARGE_CALORIE_CHANGE_THRESHOLD = 300;

function validateNutritionTargetChange(
  command: ProposedNutritionTargetChange,
  context: CoachContext,
): CommandValidation {
  if (command.dailyCalories < MIN_SAFE_DAILY_CALORIES) {
    return {
      result: 'reject',
      reason: `Proposed daily calorie target ${command.dailyCalories} is below the safe floor of ${MIN_SAFE_DAILY_CALORIES}.`,
    };
  }
  if (command.proteinG < 0 || command.carbsG < 0 || command.fatG < 0) {
    return { result: 'reject', reason: 'Proposed macro targets cannot be negative.' };
  }

  const currentTarget = context.nutrition.dailyCalorieTarget;
  if (currentTarget !== null && Math.abs(command.dailyCalories - currentTarget) > LARGE_CALORIE_CHANGE_THRESHOLD) {
    return {
      result: 'requireApproval',
      reason: `Proposed change of ${Math.abs(command.dailyCalories - currentTarget)} kcal from the current target is large enough to require explicit approval.`,
    };
  }

  return { result: 'allow', reason: 'Nutrition target change is within safe bounds.' };
}

function validateGoalChange(command: ProposedGoalChange, context: CoachContext): CommandValidation {
  if (command.priority < 0 || !Number.isInteger(command.priority)) {
    return { result: 'reject', reason: 'Goal priority must be a non-negative integer.' };
  }

  const wouldBeActivePrimary = command.category === 'primary' && command.status === 'active';
  if (wouldBeActivePrimary) {
    const existingPrimary = context.goals.activePrimary;
    const isSameGoal = existingPrimary !== null && command.goalId !== null && existingPrimary.id === command.goalId;
    if (existingPrimary !== null && !isSameGoal) {
      // The proposal, applied as-is, would create a second concurrently
      // active primary goal alongside `existingPrimary` — the one-active-
      // primary-goal invariant enforced client-side in
      // `GoalRepository.updateGoal`/`createGoal`. The coach command layer
      // does not get to auto-archive the other goal on the AI's behalf;
      // reject and let the user (or a follow-up recommendation) resolve it
      // explicitly.
      return {
        result: 'reject',
        reason: `Would create a second active primary goal alongside existing active primary goal "${existingPrimary.id}".`,
      };
    }
  }

  return { result: 'requireApproval', reason: 'Goal changes always require explicit user approval.' };
}

function validateHabitChange(command: ProposedHabitChange): CommandValidation {
  if (command.cadence === 'weekly') {
    if (command.timesPerWeek === null || command.timesPerWeek < 1 || command.timesPerWeek > 7) {
      return {
        result: 'reject',
        reason: 'Weekly-cadence habits require timesPerWeek between 1 and 7.',
      };
    }
  }
  return { result: 'allow', reason: 'Habit change is well-formed.' };
}

function validateWorkoutChange(command: ProposedWorkoutChange, context: CoachContext): CommandValidation {
  // Workouts have no structured intensity field to reason about (see
  // ai/schemas.ts) — a free-text proposal can't be mechanically checked
  // against the readiness hard-safety override the way a numeric target
  // can. Rather than guess whether a given description is safe on a red
  // readiness day, always require explicit approval in that case (never
  // silently allow), and never silently reject either since a coach might
  // legitimately be proposing a rest day. This is a deliberate,
  // conservative judgment call — see docs/superpowers/ISSUES.md, "Phase 7".
  if (context.readiness.latestLevel === 'red' || context.readiness.latestSafetyOverrideTriggered) {
    return {
      result: 'requireApproval',
      reason: 'Readiness is red (or a safety override is active); workout proposals require explicit approval.',
    };
  }
  return { result: 'requireApproval', reason: 'Workout proposals always require explicit user approval.' };
}

/** Sanity bound: no single line item may propose an implausible serving count. */
const MAX_SERVINGS_PER_ITEM = 20;

/** Sanity bound: a plan may not propose an implausible number of line items. */
const MAX_ITEMS_PER_PLAN = 40;

function validateMealPlanChange(command: ProposedMealPlanChange, context: CoachContext): CommandValidation {
  if (command.items.length === 0) {
    return { result: 'reject', reason: 'A meal plan proposal must include at least one item.' };
  }
  if (command.items.length > MAX_ITEMS_PER_PLAN) {
    return { result: 'reject', reason: `Meal plan proposes too many line items (max ${MAX_ITEMS_PER_PLAN}).` };
  }
  for (const item of command.items) {
    if (!Number.isFinite(item.servings) || item.servings <= 0 || item.servings > MAX_SERVINGS_PER_ITEM) {
      return {
        result: 'reject',
        reason: `Servings for template "${item.templateId}" must be > 0 and <= ${MAX_SERVINGS_PER_ITEM}.`,
      };
    }
  }

  // The AI never calculates or supplies cost/nutrition totals itself — only
  // template ids and servings. Cost is computed here, deterministically,
  // from already-persisted `mealTemplates` data (see `mealPlanCost.ts`).
  // Every referenced template must already exist; an unknown template id
  // means the proposal cannot be safely priced, so it is rejected outright
  // rather than allowed through with an unknown/zero cost.
  const costResult = computeMealPlanCost(command.items, context.mealPlanning.templates);
  if (!costResult.allTemplatesResolved) {
    return {
      result: 'reject',
      reason: 'Meal plan proposal references one or more unknown meal templates.',
    };
  }

  const budget = context.mealPlanning.budget;
  if (budget !== null && costResult.totalCost !== null) {
    const ceiling = command.periodType === 'daily' ? budget.dailyLimit : budget.weeklyLimit ?? (budget.dailyLimit !== null ? budget.dailyLimit * 7 : null);
    if (ceiling !== null && costResult.totalCost > ceiling) {
      return {
        result: 'reject',
        reason: `Proposed plan cost ${costResult.totalCost.toFixed(2)} ${budget.currency} exceeds the ${command.periodType} budget ceiling of ${ceiling.toFixed(2)} ${budget.currency}.`,
      };
    }
  }

  return {
    result: 'requireApproval',
    reason: 'Meal plan proposals always require explicit user approval before a plan is persisted.',
  };
}

/**
 * Pure, deterministic command validator. Independent of the AI provider
 * call entirely — it only looks at the proposed command and the (already
 * server-built) `CoachContext`. Must be called again, from scratch, at
 * `handleCommand` time with freshly-read context; a validation result
 * computed earlier (e.g. at recommendation-generation time) is informational
 * only and must never be trusted as the basis for a write.
 */
export function validateCommand(command: ProposedCommand, context: CoachContext): CommandValidation {
  switch (command.type) {
    case 'nutritionTargetChange':
      return validateNutritionTargetChange(command, context);
    case 'goalChange':
      return validateGoalChange(command, context);
    case 'habitChange':
      return validateHabitChange(command);
    case 'workoutChange':
      return validateWorkoutChange(command, context);
    case 'mealPlanChange':
      return validateMealPlanChange(command, context);
  }
}
