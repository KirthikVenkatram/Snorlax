import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/adherence_calculator.dart';

void main() {
  group('AdherenceCalculator.calculateDaily', () {
    test('weights all four components by default', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(1.0),
          AdherenceComponent.training: const ComponentInput.scored(1.0),
          AdherenceComponent.habits: const ComponentInput.scored(1.0),
          AdherenceComponent.recovery: const ComponentInput.scored(1.0),
        },
      );

      expect(result.overallScore, closeTo(1.0, 1e-9));
    });

    test('produces a weighted average matching the default weights', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(1.0), // 0.40
          AdherenceComponent.training: const ComponentInput.scored(0.0), // 0.25
          AdherenceComponent.habits: const ComponentInput.scored(1.0), // 0.20
          AdherenceComponent.recovery: const ComponentInput.scored(0.0), // 0.15
        },
      );

      // (1.0*0.40 + 0*0.25 + 1.0*0.20 + 0*0.15) / 1.0 = 0.60
      expect(result.overallScore, closeTo(0.60, 1e-9));
    });

    test('excluded components are removed from both numerator and denominator', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(1.0),
          AdherenceComponent.training: const ComponentInput.excluded(),
          AdherenceComponent.habits: const ComponentInput.scored(1.0),
          AdherenceComponent.recovery: const ComponentInput.excluded(),
        },
      );

      // Only nutrition (0.40) and habits (0.20) remain, renormalized: both scored 1.0.
      expect(result.overallScore, closeTo(1.0, 1e-9));
      expect(result.excludedComponents, {AdherenceComponent.training, AdherenceComponent.recovery});
    });

    test('an excluded component never drags the score down', () {
      final withExclusion = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(0.5),
          AdherenceComponent.training: const ComponentInput.excluded(),
          AdherenceComponent.habits: const ComponentInput.scored(0.5),
          AdherenceComponent.recovery: const ComponentInput.scored(0.5),
        },
      );
      final withZero = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(0.5),
          AdherenceComponent.training: const ComponentInput.scored(0.0),
          AdherenceComponent.habits: const ComponentInput.scored(0.5),
          AdherenceComponent.recovery: const ComponentInput.scored(0.5),
        },
      );

      expect(withExclusion.overallScore! > withZero.overallScore!, isTrue);
    });

    test('all components excluded yields a null overall score', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.excluded(),
          AdherenceComponent.training: const ComponentInput.excluded(),
          AdherenceComponent.habits: const ComponentInput.excluded(),
          AdherenceComponent.recovery: const ComponentInput.excluded(),
        },
      );

      expect(result.overallScore, isNull);
    });

    test('missing components are treated as excluded, not zero', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(0.8),
        },
      );

      expect(result.overallScore, closeTo(0.8, 1e-9));
      expect(
        result.excludedComponents,
        {AdherenceComponent.training, AdherenceComponent.habits, AdherenceComponent.recovery},
      );
    });

    test('custom weights are respected', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        weights: const AdherenceWeights(nutrition: 1, training: 0, habits: 0, recovery: 0),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(0.3),
          AdherenceComponent.training: const ComponentInput.scored(1.0),
          AdherenceComponent.habits: const ComponentInput.scored(1.0),
          AdherenceComponent.recovery: const ComponentInput.scored(1.0),
        },
      );

      expect(result.overallScore, closeTo(0.3, 1e-9));
    });

    test('score outside [0, 1] is rejected', () {
      expect(() => ComponentInput.scored(1.5), throwsA(isA<AssertionError>()));
      expect(() => ComponentInput.scored(-0.1), throwsA(isA<AssertionError>()));
    });
  });

  group('AdherenceCalculator.calculateWeekly', () {
    test('averages daily scores, ignoring null (excluded/no-data) days', () {
      final result = AdherenceCalculator.calculateWeekly(
        weekId: '2026-W37',
        dailyScores: [1.0, 0.5, null, 0.5],
      );

      expect(result.overallScore, closeTo((1.0 + 0.5 + 0.5) / 3, 1e-9));
    });

    test('a week with no scored days yields a null overall score', () {
      final result = AdherenceCalculator.calculateWeekly(
        weekId: '2026-W37',
        dailyScores: [null, null],
      );

      expect(result.overallScore, isNull);
    });
  });

  group('AdherenceCalculator.weekIdFor', () {
    test('produces stable ISO week ids', () {
      expect(AdherenceCalculator.weekIdFor(DateTime(2026, 9, 10)), '2026-W37');
    });
  });

  group('AdherenceCalculator.supportiveSummary', () {
    test('never returns punitive language and handles the null (excluded) case', () {
      final punitiveWords = ['fail', 'bad', 'lazy', 'streak', 'broke', 'shame'];

      for (final score in [null, 0.0, 0.2, 0.5, 0.7, 0.9, 1.0]) {
        final summary = AdherenceCalculator.supportiveSummary(score);
        for (final word in punitiveWords) {
          expect(summary.toLowerCase().contains(word), isFalse, reason: 'summary: $summary');
        }
      }

      expect(AdherenceCalculator.supportiveSummary(null), contains("don't count"));
    });
  });
}
