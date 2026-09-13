import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/meal_plan_calculator.dart';
import 'package:fitness_tracker/features/meal_planning/domain/budget_settings.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_plan.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_template.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

MealTemplate _template({
  String id = 't1',
  String name = 'Chicken and rice',
  double calories = 550,
  double protein = 45,
  double carbs = 60,
  double fat = 12,
  double? cost = 3.5,
}) =>
    MealTemplate(
      id: id,
      name: name,
      servings: 1,
      caloriesPerServing: calories,
      proteinGPerServing: protein,
      carbsGPerServing: carbs,
      fatGPerServing: fat,
      costPerServing: cost,
      currency: 'USD',
      costSource: PriceSource.manual,
      costTimestamp: DateTime(2026, 1, 1),
    );

void main() {
  group('MealPlanCalculator.costPerLine', () {
    test('multiplies cost per serving by servings', () {
      final line = MealPlanLineInput(template: _template(cost: 3.5), servings: 2);
      expect(MealPlanCalculator.costPerLine(line), 7.0);
    });

    test('returns null when the template has unknown cost, never 0', () {
      final line = MealPlanLineInput(template: _template(cost: null), servings: 2);
      expect(MealPlanCalculator.costPerLine(line), isNull);
    });
  });

  group('MealPlanCalculator.aggregate', () {
    test('sums cost, calories, and protein across line items', () {
      final lines = [
        MealPlanLineInput(template: _template(id: 't1', calories: 550, protein: 45, cost: 3.5), servings: 2),
        MealPlanLineInput(
          template: _template(id: 't2', name: 'Oats', calories: 350, protein: 20, cost: 1.5),
          servings: 1,
        ),
      ];

      final result = MealPlanCalculator.aggregate(lines);

      expect(result.totalCost, closeTo(8.5, 1e-9)); // 2*3.5 + 1*1.5
      expect(result.totalCalories, closeTo(1450, 1e-9)); // 2*550 + 350
      expect(result.totalProteinG, closeTo(110, 1e-9)); // 2*45 + 20
      expect(result.items, hasLength(2));
      expect(result.items[0].lineCost, closeTo(7.0, 1e-9));
    });

    test('total cost is null if any line has unknown cost, even when others are known', () {
      final lines = [
        MealPlanLineInput(template: _template(id: 't1', cost: 3.5), servings: 1),
        MealPlanLineInput(template: _template(id: 't2', cost: null), servings: 1),
      ];

      final result = MealPlanCalculator.aggregate(lines);

      expect(result.totalCost, isNull);
      expect(result.proteinPerCurrencyUnit, isNull);
      // Calories/protein are still summed even though cost is unknown.
      expect(result.totalCalories, greaterThan(0));
    });

    test('handles an empty line list without throwing', () {
      final result = MealPlanCalculator.aggregate(const []);
      expect(result.items, isEmpty);
      expect(result.totalCost, 0.0);
      expect(result.totalCalories, 0.0);
      expect(result.proteinPerCurrencyUnit, isNull); // totalCost is 0, not >0
    });
  });

  group('MealPlanCalculator.proteinPerCurrencyUnit', () {
    test('divides total protein by total cost', () {
      final value = MealPlanCalculator.proteinPerCurrencyUnit(totalProteinG: 90, totalCost: 9);
      expect(value, closeTo(10, 1e-9));
    });

    test('is null when cost is null', () {
      expect(MealPlanCalculator.proteinPerCurrencyUnit(totalProteinG: 90, totalCost: null), isNull);
    });

    test('is null when cost is zero (division would be meaningless)', () {
      expect(MealPlanCalculator.proteinPerCurrencyUnit(totalProteinG: 90, totalCost: 0), isNull);
    });
  });

  group('MealPlanCalculator.projectCost / projectMonthlyCost', () {
    test('daily projection returns the same value', () {
      expect(MealPlanCalculator.projectCost(10, MealPlanPeriodType.daily), 10);
    });

    test('weekly projection multiplies by 7', () {
      expect(MealPlanCalculator.projectCost(10, MealPlanPeriodType.weekly), closeTo(70, 1e-9));
    });

    test('monthly projection uses an average month length, not calendar days', () {
      final monthly = MealPlanCalculator.projectMonthlyCost(10);
      expect(monthly, closeTo(10 * (365.25 / 12), 1e-9));
    });

    test('null daily cost propagates as null through every projection', () {
      expect(MealPlanCalculator.projectCost(null, MealPlanPeriodType.weekly), isNull);
      expect(MealPlanCalculator.projectMonthlyCost(null), isNull);
    });
  });

  group('MealPlanCalculator.dailyCostFromPlanTotal', () {
    test('daily plan total is unchanged', () {
      expect(MealPlanCalculator.dailyCostFromPlanTotal(20, MealPlanPeriodType.daily), 20);
    });

    test('weekly plan total is divided by 7', () {
      expect(MealPlanCalculator.dailyCostFromPlanTotal(70, MealPlanPeriodType.weekly), closeTo(10, 1e-9));
    });
  });

  group('MealPlanCalculator.budgetCeilingFor', () {
    test('daily period uses dailyLimit directly', () {
      const settings = BudgetSettings(currency: 'USD', dailyLimit: 15, weeklyLimit: 90);
      expect(MealPlanCalculator.budgetCeilingFor(settings, MealPlanPeriodType.daily), 15);
    });

    test('weekly period uses weeklyLimit when set', () {
      const settings = BudgetSettings(currency: 'USD', dailyLimit: 15, weeklyLimit: 90);
      expect(MealPlanCalculator.budgetCeilingFor(settings, MealPlanPeriodType.weekly), 90);
    });

    test('weekly period falls back to dailyLimit * 7 when weeklyLimit is unset', () {
      const settings = BudgetSettings(currency: 'USD', dailyLimit: 15);
      expect(MealPlanCalculator.budgetCeilingFor(settings, MealPlanPeriodType.weekly), closeTo(105, 1e-9));
    });

    test('returns null when no relevant limit is configured', () {
      const settings = BudgetSettings(currency: 'USD');
      expect(MealPlanCalculator.budgetCeilingFor(settings, MealPlanPeriodType.weekly), isNull);
    });
  });

  group('MealPlanCalculator.isWithinBudget', () {
    const settings = BudgetSettings(currency: 'USD', dailyLimit: 20);

    test('true when cost is at or below the ceiling', () {
      expect(
        MealPlanCalculator.isWithinBudget(totalCost: 20, settings: settings, periodType: MealPlanPeriodType.daily),
        isTrue,
      );
    });

    test('false when cost exceeds the ceiling', () {
      expect(
        MealPlanCalculator.isWithinBudget(totalCost: 21, settings: settings, periodType: MealPlanPeriodType.daily),
        isFalse,
      );
    });

    test('null (indeterminate) when cost is unknown', () {
      expect(
        MealPlanCalculator.isWithinBudget(totalCost: null, settings: settings, periodType: MealPlanPeriodType.daily),
        isNull,
      );
    });

    test('null (indeterminate) when no budget ceiling is configured', () {
      const noBudget = BudgetSettings(currency: 'USD');
      expect(
        MealPlanCalculator.isWithinBudget(totalCost: 20, settings: noBudget, periodType: MealPlanPeriodType.daily),
        isNull,
      );
    });
  });
}
