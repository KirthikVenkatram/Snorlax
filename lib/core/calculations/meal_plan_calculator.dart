/// Deterministic, pure cost/nutrition aggregation for budget-aware meal
/// planning.
///
/// This module performs no I/O: callers (`meal_plan_repository.dart`, and
/// the equivalent server-side logic in `functions/src/coach/mealPlanCost.ts`
/// for AI-proposed plans) are responsible for gathering `MealTemplate` data
/// and calling into this calculator. AI never calls this directly and never
/// supplies cost/nutrition numbers itself — see the Phase 8 plan and
/// `docs/superpowers/specs/2026-08-24-fitness-operating-system-architecture.md`,
/// "Budget-aware Nutrition and Meal Planning".
library;

import '../../features/meal_planning/domain/budget_settings.dart';
import '../../features/meal_planning/domain/meal_plan.dart';
import '../../features/meal_planning/domain/meal_template.dart';

/// One item to aggregate: a template plus how many servings of it.
class MealPlanLineInput {
  const MealPlanLineInput({required this.template, required this.servings}) : assert(servings > 0);

  final MealTemplate template;
  final double servings;
}

/// The days-per-period conventions used by [MealPlanCalculator.projectCost]
/// — an average month length (365.25 / 12) is used for the monthly
/// projection so it doesn't drift depending on which month it's computed in.
class MealPlanCalculator {
  MealPlanCalculator._();

  static const double _daysPerWeek = 7;
  static const double _averageDaysPerMonth = 365.25 / 12;

  /// Cost of a single line item (`template.costPerServing * servings`).
  /// Null if the template's cost is unknown — never fabricated as 0.
  static double? costPerLine(MealPlanLineInput line) {
    final perServing = line.template.costPerServing;
    if (perServing == null) return null;
    return perServing * line.servings;
  }

  /// Aggregates a list of line items into a [MealPlan]-ready set of items
  /// plus totals. [totalCost] (and therefore [MealPlan.proteinPerCurrencyUnit])
  /// is null if any line's cost is unknown, so a plan is never presented as
  /// "this is the total cost" when part of it is actually unpriced.
  static ({
    List<MealPlanItem> items,
    double? totalCost,
    double totalCalories,
    double totalProteinG,
    double? proteinPerCurrencyUnit,
  }) aggregate(List<MealPlanLineInput> lines) {
    var totalCost = 0.0;
    var costKnown = true;
    var totalCalories = 0.0;
    var totalProteinG = 0.0;

    final items = lines.map((line) {
      final lineCost = costPerLine(line);
      final lineCalories = line.template.caloriesPerServing * line.servings;
      final lineProteinG = line.template.proteinGPerServing * line.servings;

      if (lineCost == null) {
        costKnown = false;
      } else {
        totalCost += lineCost;
      }
      totalCalories += lineCalories;
      totalProteinG += lineProteinG;

      return MealPlanItem(
        templateId: line.template.id,
        templateName: line.template.name,
        servings: line.servings,
        costPerServing: line.template.costPerServing,
        lineCost: lineCost,
        lineCalories: lineCalories,
        lineProteinG: lineProteinG,
      );
    }).toList();

    final finalTotalCost = costKnown ? totalCost : null;
    return (
      items: items,
      totalCost: finalTotalCost,
      totalCalories: totalCalories,
      totalProteinG: totalProteinG,
      proteinPerCurrencyUnit: proteinPerCurrencyUnit(totalProteinG: totalProteinG, totalCost: finalTotalCost),
    );
  }

  /// Grams of protein per unit of currency spent. Null if cost is unknown
  /// or zero (division would be meaningless/undefined).
  static double? proteinPerCurrencyUnit({required double totalProteinG, required double? totalCost}) {
    if (totalCost == null || totalCost <= 0) return null;
    return totalProteinG / totalCost;
  }

  /// Projects a daily cost figure out to the requested period. [dailyCost]
  /// of null (unknown) propagates as null rather than being treated as 0.
  static double? projectCost(double? dailyCost, MealPlanPeriodType period) {
    if (dailyCost == null) return null;
    return switch (period) {
      MealPlanPeriodType.daily => dailyCost,
      MealPlanPeriodType.weekly => dailyCost * _daysPerWeek,
    };
  }

  /// Monthly cost projection from a daily cost figure, using an average
  /// month length so the result doesn't depend on the current month.
  static double? projectMonthlyCost(double? dailyCost) {
    if (dailyCost == null) return null;
    return dailyCost * _averageDaysPerMonth;
  }

  /// Converts a plan's own total cost (already for [periodType]) into an
  /// equivalent daily figure, the common unit [projectCost]/
  /// [projectMonthlyCost] expect.
  static double? dailyCostFromPlanTotal(double? planTotalCost, MealPlanPeriodType periodType) {
    if (planTotalCost == null) return null;
    return switch (periodType) {
      MealPlanPeriodType.daily => planTotalCost,
      MealPlanPeriodType.weekly => planTotalCost / _daysPerWeek,
    };
  }

  /// Returns the applicable budget ceiling from [settings] for [periodType],
  /// falling back to `dailyLimit * 7` for a weekly plan when no explicit
  /// `weeklyLimit` is set (same fallback `validateCommand.ts` uses
  /// server-side, kept consistent so client and AI-proposal paths agree on
  /// what "over budget" means). Null if no relevant limit is configured.
  static double? budgetCeilingFor(BudgetSettings settings, MealPlanPeriodType periodType) {
    switch (periodType) {
      case MealPlanPeriodType.daily:
        return settings.dailyLimit;
      case MealPlanPeriodType.weekly:
        if (settings.weeklyLimit != null) return settings.weeklyLimit;
        if (settings.dailyLimit != null) return settings.dailyLimit! * _daysPerWeek;
        return null;
    }
  }

  /// Whether [totalCost] is within the budget ceiling for [periodType].
  /// Returns null (indeterminate — not true or false) if either the cost or
  /// the relevant budget ceiling is unknown, so callers can distinguish
  /// "definitely over budget" from "we don't have enough information to
  /// say" instead of defaulting silently to one or the other.
  static bool? isWithinBudget({
    required double? totalCost,
    required BudgetSettings settings,
    required MealPlanPeriodType periodType,
  }) {
    final ceiling = budgetCeilingFor(settings, periodType);
    if (totalCost == null || ceiling == null) return null;
    return totalCost <= ceiling;
  }
}
