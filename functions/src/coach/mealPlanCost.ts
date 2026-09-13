import { ProposedMealPlanItem } from '../ai/schemas';
import { MealTemplateSummary } from './buildCoachContext';

/**
 * Deterministic, pure cost/nutrition aggregation for a proposed or persisted
 * meal plan — the server-side mirror of
 * `lib/core/calculations/meal_plan_calculator.dart`'s aggregation logic (kept
 * as a small, independently-testable function here rather than shared across
 * languages, since this repo has no cross-language shared-code mechanism;
 * see docs/superpowers/ISSUES.md, "Phase 8" for that duplication note).
 *
 * The AI never calls this — it only proposes `templateId`/`servings` pairs.
 * `validateCommand`/`handleCommand` are the only callers, so cost is always
 * computed from already-persisted, deterministic template data.
 */

export interface MealPlanLineTotal {
  templateId: string;
  templateName: string;
  servings: number;
  costPerServing: number | null;
  lineCost: number | null;
  lineCalories: number | null;
  lineProteinG: number | null;
}

export interface MealPlanCostResult {
  lines: MealPlanLineTotal[];
  /** Null if any line item references a template with unknown cost. */
  totalCost: number | null;
  totalCalories: number | null;
  totalProteinG: number | null;
  /** Null if totalCost is null or zero (division would be meaningless). */
  proteinPerCurrencyUnit: number | null;
  /** True if every item's templateId resolved to a known template. */
  allTemplatesResolved: boolean;
}

export function computeMealPlanCost(
  items: ProposedMealPlanItem[],
  templates: MealTemplateSummary[],
): MealPlanCostResult {
  const byId = new Map(templates.map((t) => [t.id, t]));
  let totalCost = 0;
  let totalCalories = 0;
  let totalProteinG = 0;
  let costKnown = true;
  let allTemplatesResolved = true;

  const lines: MealPlanLineTotal[] = items.map((item) => {
    const template = byId.get(item.templateId);
    if (!template) {
      allTemplatesResolved = false;
      costKnown = false;
      return {
        templateId: item.templateId,
        templateName: '(unknown template)',
        servings: item.servings,
        costPerServing: null,
        lineCost: null,
        lineCalories: null,
        lineProteinG: null,
      };
    }
    const lineCost = template.costPerServing !== null ? template.costPerServing * item.servings : null;
    const lineCalories = template.caloriesPerServing !== null ? template.caloriesPerServing * item.servings : null;
    const lineProteinG = template.proteinGPerServing !== null ? template.proteinGPerServing * item.servings : null;

    if (lineCost === null) costKnown = false;
    else totalCost += lineCost;
    if (lineCalories !== null) totalCalories += lineCalories;
    if (lineProteinG !== null) totalProteinG += lineProteinG;

    return {
      templateId: item.templateId,
      templateName: template.name,
      servings: item.servings,
      costPerServing: template.costPerServing,
      lineCost,
      lineCalories,
      lineProteinG,
    };
  });

  const finalTotalCost = costKnown ? totalCost : null;

  return {
    lines,
    totalCost: finalTotalCost,
    totalCalories,
    totalProteinG,
    proteinPerCurrencyUnit: finalTotalCost !== null && finalTotalCost > 0 ? totalProteinG / finalTotalCost : null,
    allTemplatesResolved,
  };
}
