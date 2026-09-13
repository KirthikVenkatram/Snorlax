import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_template.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

void main() {
  group('MealTemplate JSON round-trip', () {
    test('round-trips all fields including a known cost', () {
      final template = MealTemplate(
        id: 't1',
        name: 'Chicken and rice',
        servings: 4,
        caloriesPerServing: 550,
        proteinGPerServing: 45,
        carbsGPerServing: 60,
        fatGPerServing: 12,
        costPerServing: 3.5,
        currency: 'USD',
        costSource: PriceSource.manual,
        costTimestamp: DateTime(2026, 9, 13),
      );

      final decoded = MealTemplate.fromJson('t1', template.toJson());

      expect(decoded.name, 'Chicken and rice');
      expect(decoded.servings, 4);
      expect(decoded.caloriesPerServing, 550);
      expect(decoded.proteinGPerServing, 45);
      expect(decoded.costPerServing, 3.5);
      expect(decoded.costSource, PriceSource.manual);
    });

    test('an unpriced template has a null costPerServing, never 0', () {
      final template = MealTemplate(
        id: 't2',
        name: 'Mystery smoothie',
        servings: 1,
        caloriesPerServing: 300,
        proteinGPerServing: 20,
        carbsGPerServing: 40,
        fatGPerServing: 5,
        costPerServing: null,
        currency: 'USD',
        costSource: PriceSource.unavailable,
        costTimestamp: DateTime(2026, 9, 13),
      );

      final decoded = MealTemplate.fromJson('t2', template.toJson());
      expect(decoded.costPerServing, isNull);
      expect(decoded.costSource, PriceSource.unavailable);
    });

    test('rejects a negative costPerServing', () {
      expect(
        () => MealTemplate(
          id: 't3',
          name: 'x',
          servings: 1,
          caloriesPerServing: 100,
          proteinGPerServing: 10,
          carbsGPerServing: 10,
          fatGPerServing: 1,
          costPerServing: -1,
          currency: 'USD',
          costSource: PriceSource.manual,
          costTimestamp: DateTime(2026, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
