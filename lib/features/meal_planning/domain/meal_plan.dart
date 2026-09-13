/// A proposed or saved daily/weekly meal plan, persisted at
/// `users/{uid}/mealPlans/{planId}`.
///
/// Totals ([MealPlan.totalCost]/[totalCalories]/[totalProteinG]/
/// [proteinPerCurrencyUnit]) are always produced by
/// `core/calculations/meal_plan_calculator.dart` — never computed ad hoc in
/// UI code or trusted from an AI proposal — mirroring how
/// `functions/src/coach/mealPlanCost.ts` computes the same figures
/// server-side for AI-originated plans. See the Phase 8 plan and
/// docs/superpowers/ISSUES.md for why the two implementations are separate,
/// hand-kept-in-sync pure functions rather than shared code.
library;

enum MealPlanPeriodType { daily, weekly }

/// Where a [MealPlan] came from — purely informational/for display; both
/// paths write through the same deterministic calculator.
enum MealPlanSource { manual, aiProposal }

/// One line item in a plan: a reference to a `MealTemplate` plus how many
/// servings, with the per-line totals already computed and denormalized so
/// the plan is self-contained (matches how `mealPlanCost.ts`'s `lines`
/// output is stored server-side).
class MealPlanItem {
  const MealPlanItem({
    required this.templateId,
    required this.templateName,
    required this.servings,
    required this.costPerServing,
    required this.lineCost,
    required this.lineCalories,
    required this.lineProteinG,
  }) : assert(servings > 0, 'servings must be positive');

  final String templateId;
  final String templateName;
  final double servings;

  /// Null when the referencing template has no known cost — [lineCost] is
  /// then also null (never fabricated as 0).
  final double? costPerServing;
  final double? lineCost;
  final double? lineCalories;
  final double? lineProteinG;

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'templateName': templateName,
        'servings': servings,
        'costPerServing': costPerServing,
        'lineCost': lineCost,
        'lineCalories': lineCalories,
        'lineProteinG': lineProteinG,
      };

  factory MealPlanItem.fromJson(Map<String, dynamic> json) => MealPlanItem(
        templateId: json['templateId'] as String? ?? '',
        templateName: json['templateName'] as String? ?? '',
        servings: (json['servings'] as num?)?.toDouble() ?? 1,
        costPerServing: (json['costPerServing'] as num?)?.toDouble(),
        lineCost: (json['lineCost'] as num?)?.toDouble(),
        lineCalories: (json['lineCalories'] as num?)?.toDouble(),
        lineProteinG: (json['lineProteinG'] as num?)?.toDouble(),
      );
}

class MealPlan {
  const MealPlan({
    required this.id,
    required this.name,
    required this.periodType,
    required this.items,
    required this.totalCost,
    required this.totalCalories,
    required this.totalProteinG,
    required this.proteinPerCurrencyUnit,
    required this.currency,
    required this.source,
    required this.createdAt,
  });

  final String id;
  final String name;
  final MealPlanPeriodType periodType;
  final List<MealPlanItem> items;

  /// Null if any item's cost is unknown — a plan total is never partially
  /// summed and presented as complete.
  final double? totalCost;
  final double? totalCalories;
  final double? totalProteinG;
  final double? proteinPerCurrencyUnit;
  final String currency;
  final MealPlanSource source;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'name': name,
        'periodType': periodType.name,
        'items': items.map((i) => i.toJson()).toList(),
        'totalCost': totalCost,
        'totalCalories': totalCalories,
        'totalProteinG': totalProteinG,
        'proteinPerCurrencyUnit': proteinPerCurrencyUnit,
        'currency': currency,
        'source': source.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MealPlan.fromJson(String id, Map<String, dynamic> json) => MealPlan(
        id: id,
        name: json['name'] as String? ?? '',
        periodType: MealPlanPeriodType.values.byName((json['periodType'] as String?) ?? 'daily'),
        items: (json['items'] as List? ?? const [])
            .map((raw) => MealPlanItem.fromJson(Map<String, dynamic>.from(raw as Map)))
            .toList(),
        totalCost: (json['totalCost'] as num?)?.toDouble(),
        totalCalories: (json['totalCalories'] as num?)?.toDouble(),
        totalProteinG: (json['totalProteinG'] as num?)?.toDouble(),
        proteinPerCurrencyUnit: (json['proteinPerCurrencyUnit'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        source: MealPlanSource.values.byName((json['source'] as String?) ?? 'manual'),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
