/**
 * Runtime validators for AI-provider output, following the same
 * extract-then-hand-validate style as `parseFoodText.ts` /
 * `estimateNutrition.ts` (no schema library is used elsewhere in
 * `functions/`, so this stays consistent rather than introducing zod for
 * just this feature).
 *
 * Nothing here trusts the model's output shape — every field is checked by
 * type and, where meaningful, range, before being accepted. Invalid output
 * throws and is never written to Firestore or coerced into health data.
 */

export type GoalCategory = 'primary' | 'physique' | 'performance' | 'lifestyle';
export type GoalStatus = 'active' | 'paused' | 'completed' | 'archived';
export type HabitCadence = 'daily' | 'weekly';

export interface ProposedNutritionTargetChange {
  type: 'nutritionTargetChange';
  dailyCalories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

export interface ProposedGoalChange {
  type: 'goalChange';
  /** null means "propose creating a new goal". */
  goalId: string | null;
  name: string;
  category: GoalCategory;
  status: GoalStatus;
  priority: number;
  targetValue: number | null;
  unit: string | null;
}

export interface ProposedHabitChange {
  type: 'habitChange';
  /** null means "propose creating a new habit". */
  habitId: string | null;
  name: string;
  cadence: HabitCadence;
  timesPerWeek: number | null;
  archived: boolean;
}

/**
 * Workouts have no structured proposal model yet (Phase 7 does not extend
 * the workouts feature) — this is a free-text advisory proposal only, never
 * auto-applied. See docs/superpowers/ISSUES.md, "Phase 7".
 */
export interface ProposedWorkoutChange {
  type: 'workoutChange';
  description: string;
}

/**
 * One line item in a proposed meal plan: a reference to an existing
 * `mealTemplates/{templateId}` document plus how many servings of it. The AI
 * never proposes a price, calorie count, or cost total here — those are
 * always looked up from the template/price data already in Firestore and
 * computed deterministically by `coach/mealPlanCost.ts`, never trusted from
 * model output. See the spec's "Budget-aware Nutrition and Meal Planning"
 * section and docs/superpowers/ISSUES.md, "Phase 8".
 */
export interface ProposedMealPlanItem {
  templateId: string;
  servings: number;
}

export type MealPlanPeriodType = 'daily' | 'weekly';

export interface ProposedMealPlanChange {
  type: 'mealPlanChange';
  /** null means "propose creating a new plan". */
  planId: string | null;
  name: string;
  periodType: MealPlanPeriodType;
  items: ProposedMealPlanItem[];
}

export type ProposedCommand =
  | ProposedNutritionTargetChange
  | ProposedGoalChange
  | ProposedHabitChange
  | ProposedWorkoutChange
  | ProposedMealPlanChange;

export interface CoachRecommendation {
  summary: string;
  rationale: string;
  proposedCommand: ProposedCommand | null;
}

const GOAL_CATEGORIES: GoalCategory[] = ['primary', 'physique', 'performance', 'lifestyle'];
const GOAL_STATUSES: GoalStatus[] = ['active', 'paused', 'completed', 'archived'];
const HABIT_CADENCES: HabitCadence[] = ['daily', 'weekly'];

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

export function isProposedNutritionTargetChange(value: unknown): value is ProposedNutritionTargetChange {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.type === 'nutritionTargetChange' &&
    isFiniteNumber(v.dailyCalories) &&
    isFiniteNumber(v.proteinG) &&
    isFiniteNumber(v.carbsG) &&
    isFiniteNumber(v.fatG)
  );
}

export function isProposedGoalChange(value: unknown): value is ProposedGoalChange {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.type === 'goalChange' &&
    (v.goalId === null || isNonEmptyString(v.goalId)) &&
    isNonEmptyString(v.name) &&
    GOAL_CATEGORIES.includes(v.category as GoalCategory) &&
    GOAL_STATUSES.includes(v.status as GoalStatus) &&
    isFiniteNumber(v.priority) &&
    (v.targetValue === null || isFiniteNumber(v.targetValue)) &&
    (v.unit === null || isNonEmptyString(v.unit))
  );
}

export function isProposedHabitChange(value: unknown): value is ProposedHabitChange {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.type === 'habitChange' &&
    (v.habitId === null || isNonEmptyString(v.habitId)) &&
    isNonEmptyString(v.name) &&
    HABIT_CADENCES.includes(v.cadence as HabitCadence) &&
    (v.timesPerWeek === null || isFiniteNumber(v.timesPerWeek)) &&
    typeof v.archived === 'boolean'
  );
}

export function isProposedWorkoutChange(value: unknown): value is ProposedWorkoutChange {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return v.type === 'workoutChange' && isNonEmptyString(v.description);
}

function isProposedMealPlanItem(value: unknown): value is ProposedMealPlanItem {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return isNonEmptyString(v.templateId) && isFiniteNumber(v.servings) && v.servings > 0;
}

export function isProposedMealPlanChange(value: unknown): value is ProposedMealPlanChange {
  if (typeof value !== 'object' || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.type === 'mealPlanChange' &&
    (v.planId === null || isNonEmptyString(v.planId)) &&
    isNonEmptyString(v.name) &&
    (v.periodType === 'daily' || v.periodType === 'weekly') &&
    Array.isArray(v.items) &&
    v.items.length > 0 &&
    v.items.every(isProposedMealPlanItem)
  );
}

export function isProposedCommand(value: unknown): value is ProposedCommand {
  return (
    isProposedNutritionTargetChange(value) ||
    isProposedGoalChange(value) ||
    isProposedHabitChange(value) ||
    isProposedWorkoutChange(value) ||
    isProposedMealPlanChange(value)
  );
}

/**
 * Extracts the first JSON object literal from a model response, tolerating
 * surrounding prose or a markdown code fence — same tolerance as
 * `parseFoodText.ts`/`estimateNutrition.ts`.
 */
function extractJsonObject(text: string): Record<string, unknown> {
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) {
    throw new Error('No JSON object found in model response');
  }
  return JSON.parse(match[0]) as Record<string, unknown>;
}

/**
 * Parses and validates a raw AI provider response into a `CoachRecommendation`.
 * Throws if the response is not well-formed JSON, is missing required
 * fields, or has a `proposedCommand` that doesn't match one of the known
 * proposal shapes. A `proposedCommand` of `null` (advice-only, no proposed
 * mutation) is valid.
 */
export function parseCoachRecommendation(text: string): CoachRecommendation {
  const parsed = extractJsonObject(text);

  if (!isNonEmptyString(parsed.summary) || !isNonEmptyString(parsed.rationale)) {
    throw new Error('Coach recommendation missing summary/rationale text');
  }

  const rawCommand = parsed.proposedCommand;
  if (rawCommand !== null && rawCommand !== undefined && !isProposedCommand(rawCommand)) {
    throw new Error('Coach recommendation has an invalid proposedCommand shape');
  }

  return {
    summary: parsed.summary,
    rationale: parsed.rationale,
    proposedCommand: (rawCommand as ProposedCommand | null | undefined) ?? null,
  };
}

/**
 * Parses a raw `aiProvider.generateMealPlanProposal` response using the same
 * `{summary, rationale, proposedCommand}` shape and validation as
 * `parseCoachRecommendation`, but additionally requires that a non-null
 * `proposedCommand` be a `mealPlanChange` specifically — this call site only
 * ever asked for a meal plan, so any other proposal type in the response
 * indicates a malformed/off-topic model reply and is rejected rather than
 * silently accepted.
 */
export function parseMealPlanRecommendation(text: string): CoachRecommendation {
  const recommendation = parseCoachRecommendation(text);
  if (recommendation.proposedCommand !== null && recommendation.proposedCommand.type !== 'mealPlanChange') {
    throw new Error(
      `Expected a mealPlanChange proposal or none, got "${recommendation.proposedCommand.type}"`,
    );
  }
  return recommendation;
}
