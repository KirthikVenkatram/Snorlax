import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/meal_plan_calculator.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_plan_repository.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_plan.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_template.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

MealTemplate _template({String id = 't1', double? cost = 3.5}) => MealTemplate(
      id: id,
      name: 'Chicken and rice',
      servings: 1,
      caloriesPerServing: 550,
      proteinGPerServing: 45,
      carbsGPerServing: 60,
      fatGPerServing: 12,
      costPerServing: cost,
      currency: 'USD',
      costSource: PriceSource.manual,
      costTimestamp: DateTime(2026, 9, 13),
    );

void main() {
  test('list returns an empty list for a new user', () async {
    final repository = MealPlanRepository(firestore: FakeFirebaseFirestore());
    expect(await repository.list('u'), isEmpty);
  });

  test('createFromTemplates computes totals via the deterministic calculator, never accepting a caller-supplied total', () async {
    final repository = MealPlanRepository(firestore: FakeFirebaseFirestore());

    final plan = await repository.createFromTemplates(
      uid: 'u',
      name: 'Weekday lunches',
      periodType: MealPlanPeriodType.daily,
      lines: [MealPlanLineInput(template: _template(), servings: 2)],
      currency: 'USD',
    );

    expect(plan.totalCost, closeTo(7.0, 1e-9)); // 2 * 3.5
    expect(plan.totalCalories, closeTo(1100, 1e-9));
    expect(plan.source, MealPlanSource.manual);

    final fetched = await repository.get('u', plan.id);
    expect(fetched!.totalCost, closeTo(7.0, 1e-9));
  });

  test('a plan built from an unpriced template has a null totalCost, never a partial sum', () async {
    final repository = MealPlanRepository(firestore: FakeFirebaseFirestore());

    final plan = await repository.createFromTemplates(
      uid: 'u',
      name: 'Partly unpriced plan',
      periodType: MealPlanPeriodType.daily,
      lines: [MealPlanLineInput(template: _template(cost: null), servings: 1)],
      currency: 'USD',
    );

    expect(plan.totalCost, isNull);
    expect(plan.proteinPerCurrencyUnit, isNull);
  });

  test('delete removes a plan', () async {
    final repository = MealPlanRepository(firestore: FakeFirebaseFirestore());
    final plan = await repository.createFromTemplates(
      uid: 'u',
      name: 'x',
      periodType: MealPlanPeriodType.daily,
      lines: [MealPlanLineInput(template: _template(), servings: 1)],
      currency: 'USD',
    );

    await repository.delete('u', plan.id);

    expect(await repository.get('u', plan.id), isNull);
  });
}
