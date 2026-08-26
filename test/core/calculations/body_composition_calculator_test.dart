import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/body_composition_calculator.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';

void main() {
  group('BodyCompositionCalculator', () {
    test('calculates a labelled male circumference estimate', () {
      final result = BodyCompositionCalculator.estimate(
        sex: Sex.male, heightCm: 178, weightKg: 80, waistCm: 90, neckCm: 38,
      );
      expect(result.method, 'us-navy-circumference');
      expect(result.bodyFatPercent, inInclusiveRange(5, 45));
      expect(result.fatMassKg + result.leanBodyMassKg, closeTo(80, 0.01));
    });

    test('requires hip circumference for a female circumference estimate', () {
      expect(() => BodyCompositionCalculator.estimate(
        sex: Sex.female, heightCm: 165, weightKg: 65, waistCm: 75, neckCm: 32,
      ), throwsArgumentError);
    });

    test('rejects impossible circumference geometry', () {
      expect(() => BodyCompositionCalculator.estimate(
        sex: Sex.male, heightCm: 178, weightKg: 80, waistCm: 35, neckCm: 38,
      ), throwsArgumentError);
    });
  });
}
