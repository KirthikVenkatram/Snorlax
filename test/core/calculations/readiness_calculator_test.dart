import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/readiness_calculator.dart';
import 'package:fitness_tracker/features/readiness/domain/readiness_entry.dart';

void main() {
  group('ReadinessCalculator.calculate — normal scoring', () {
    test('excellent inputs produce green', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 8,
          sleepConsistency: 1.0,
          soreness: 0.0,
          fatigue: 0.0,
          energy: 1.0,
          recentTrainingLoad: 0.0,
        ),
      );

      expect(result.level, ReadinessLevel.green);
      expect(result.score, closeTo(1.0, 1e-9));
      expect(result.safetyOverrideTriggered, isFalse);
    });

    test('mediocre inputs produce yellow', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 6,
          sleepConsistency: 0.5,
          soreness: 0.5,
          fatigue: 0.5,
          energy: 0.5,
          recentTrainingLoad: 0.5,
        ),
      );

      expect(result.level, ReadinessLevel.yellow);
      expect(result.safetyOverrideTriggered, isFalse);
    });

    test('poor inputs (without a hard override) produce red via the composite score', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 3,
          sleepConsistency: 0.1,
          soreness: 0.6,
          fatigue: 0.7,
          energy: 0.1,
          recentTrainingLoad: 0.8,
        ),
      );

      expect(result.level, ReadinessLevel.red);
      // Composite-driven red, not a safety override, since soreness (0.6)
      // is below the high-soreness override threshold (0.8).
      expect(result.safetyOverrideTriggered, isFalse);
    });
  });

  group('ReadinessCalculator.calculate — hard safety overrides', () {
    test('pain/injury flag forces red regardless of otherwise excellent inputs', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 9,
          sleepConsistency: 1.0,
          soreness: 0.0,
          fatigue: 0.0,
          energy: 1.0,
          recentTrainingLoad: 0.0,
          painOrInjury: true,
        ),
      );

      expect(result.level, ReadinessLevel.red);
      expect(result.safetyOverrideTriggered, isTrue);
      expect(result.notes, isNotEmpty);
    });

    test('extreme sleep deprivation + high soreness forces red regardless of otherwise excellent inputs', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 3, // <= extremeSleepDeprivationHours (4)
          sleepConsistency: 1.0,
          soreness: 0.9, // >= highSorenessThreshold (0.8)
          fatigue: 0.0,
          energy: 1.0,
          recentTrainingLoad: 0.0,
        ),
      );

      expect(result.level, ReadinessLevel.red);
      expect(result.safetyOverrideTriggered, isTrue);
    });

    test('extreme sleep deprivation alone (without high soreness) does not trigger the override', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 3,
          sleepConsistency: 1.0,
          soreness: 0.1,
          fatigue: 0.0,
          energy: 1.0,
          recentTrainingLoad: 0.0,
        ),
      );

      expect(result.safetyOverrideTriggered, isFalse);
    });

    test('high soreness alone (without extreme sleep deprivation) does not trigger the override', () {
      final result = ReadinessCalculator.calculate(
        const ReadinessInputs(
          sleepHours: 8,
          sleepConsistency: 1.0,
          soreness: 0.9,
          fatigue: 0.0,
          energy: 1.0,
          recentTrainingLoad: 0.0,
        ),
      );

      expect(result.safetyOverrideTriggered, isFalse);
    });

    test('the pain/injury override cannot be outvoted by any combination of other inputs', () {
      // Sweep across a range of otherwise-maximal "good" inputs; the
      // override must always win. This is the structural guarantee a
      // future AI coach must never be able to bypass.
      for (final sleep in [0.0, 4.0, 8.0, 12.0]) {
        final result = ReadinessCalculator.calculate(
          ReadinessInputs(
            sleepHours: sleep,
            sleepConsistency: 1.0,
            soreness: 0.0,
            fatigue: 0.0,
            energy: 1.0,
            recentTrainingLoad: 0.0,
            painOrInjury: true,
          ),
        );
        expect(result.level, ReadinessLevel.red, reason: 'sleepHours=$sleep');
        expect(result.safetyOverrideTriggered, isTrue, reason: 'sleepHours=$sleep');
      }
    });
  });
}
