import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_plan.dart';

void main() {
  group('MealPlan JSON round-trip', () {
    test('round-trips items and totals', () {
      final plan = MealPlan(
        id: 'p1',
        name: 'Weekday lunches',
        periodType: MealPlanPeriodType.daily,
        items: const [
          MealPlanItem(
            templateId: 't1',
            templateName: 'Chicken and rice',
            servings: 2,
            costPerServing: 3.5,
            lineCost: 7.0,
            lineCalories: 1100,
            lineProteinG: 90,
          ),
        ],
        totalCost: 7.0,
        totalCalories: 1100,
        totalProteinG: 90,
        proteinPerCurrencyUnit: 90 / 7,
        currency: 'USD',
        source: MealPlanSource.manual,
        createdAt: DateTime(2026, 9, 13),
      );

      final decoded = MealPlan.fromJson('p1', plan.toJson());

      expect(decoded.name, 'Weekday lunches');
      expect(decoded.periodType, MealPlanPeriodType.daily);
      expect(decoded.items, hasLength(1));
      expect(decoded.items.first.templateName, 'Chicken and rice');
      expect(decoded.totalCost, 7.0);
      expect(decoded.source, MealPlanSource.manual);
    });

    test('a plan with an unpriced item has a null totalCost, never a partial sum', () {
      final plan = MealPlan(
        id: 'p2',
        name: 'Partly unpriced plan',
        periodType: MealPlanPeriodType.weekly,
        items: const [
          MealPlanItem(
            templateId: 't2',
            templateName: 'Unpriced smoothie',
            servings: 1,
            costPerServing: null,
            lineCost: null,
            lineCalories: 300,
            lineProteinG: 20,
          ),
        ],
        totalCost: null,
        totalCalories: 300,
        totalProteinG: 20,
        proteinPerCurrencyUnit: null,
        currency: 'USD',
        source: MealPlanSource.aiProposal,
        createdAt: DateTime(2026, 9, 13),
      );

      final decoded = MealPlan.fromJson('p2', plan.toJson());
      expect(decoded.totalCost, isNull);
      expect(decoded.proteinPerCurrencyUnit, isNull);
      expect(decoded.source, MealPlanSource.aiProposal);
    });
  });
}
