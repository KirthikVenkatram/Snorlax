import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/domain/budget_settings.dart';

void main() {
  group('BudgetSettings JSON round-trip', () {
    test('round-trips all fields', () {
      const settings = BudgetSettings(
        currency: 'INR',
        dailyLimit: 500,
        weeklyLimit: 3000,
        monthlyLimit: 12000,
        preferredStores: ['Blinkit', 'Local market'],
        substitutions: {'almond milk': 'oat milk'},
      );

      final decoded = BudgetSettings.fromJson(settings.toJson());

      expect(decoded.currency, 'INR');
      expect(decoded.dailyLimit, 500);
      expect(decoded.weeklyLimit, 3000);
      expect(decoded.monthlyLimit, 12000);
      expect(decoded.preferredStores, ['Blinkit', 'Local market']);
      expect(decoded.substitutions, {'almond milk': 'oat milk'});
    });

    test('all limits are optional (no budget configured yet is a valid state)', () {
      const settings = BudgetSettings(currency: 'USD');
      final decoded = BudgetSettings.fromJson(settings.toJson());
      expect(decoded.dailyLimit, isNull);
      expect(decoded.weeklyLimit, isNull);
      expect(decoded.monthlyLimit, isNull);
    });

    test('defaults currency to USD when missing from JSON', () {
      final decoded = BudgetSettings.fromJson({});
      expect(decoded.currency, 'USD');
    });

    test('rejects a negative limit', () {
      expect(() => BudgetSettings(currency: 'USD', dailyLimit: -1), throwsA(isA<AssertionError>()));
    });
  });
}
