import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/readiness/domain/readiness_entry.dart';

void main() {
  group('ReadinessInputs JSON round-trip', () {
    test('round-trips all fields', () {
      const inputs = ReadinessInputs(
        sleepHours: 6.5,
        sleepConsistency: 0.8,
        soreness: 0.4,
        fatigue: 0.3,
        energy: 0.6,
        recentTrainingLoad: 0.5,
        painOrInjury: true,
      );

      final decoded = ReadinessInputs.fromJson(inputs.toJson());

      expect(decoded.sleepHours, inputs.sleepHours);
      expect(decoded.sleepConsistency, inputs.sleepConsistency);
      expect(decoded.soreness, inputs.soreness);
      expect(decoded.fatigue, inputs.fatigue);
      expect(decoded.energy, inputs.energy);
      expect(decoded.recentTrainingLoad, inputs.recentTrainingLoad);
      expect(decoded.painOrInjury, inputs.painOrInjury);
    });

    test('painOrInjury defaults to false', () {
      const inputs = ReadinessInputs(
        sleepHours: 8,
        sleepConsistency: 1,
        soreness: 0,
        fatigue: 0,
        energy: 1,
        recentTrainingLoad: 0,
      );
      expect(inputs.painOrInjury, isFalse);
    });

    test('rejects out-of-range fractional inputs', () {
      expect(
        () => ReadinessInputs(
          sleepHours: 8,
          sleepConsistency: 1.5,
          soreness: 0,
          fatigue: 0,
          energy: 1,
          recentTrainingLoad: 0,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ReadinessResult JSON round-trip', () {
    test('round-trips level, score, notes, and override flag', () {
      const result = ReadinessResult(
        level: ReadinessLevel.yellow,
        score: 0.55,
        notes: ['note one', 'note two'],
        safetyOverrideTriggered: false,
      );

      final decoded = ReadinessResult.fromJson(result.toJson());

      expect(decoded.level, ReadinessLevel.yellow);
      expect(decoded.score, 0.55);
      expect(decoded.notes, ['note one', 'note two']);
      expect(decoded.safetyOverrideTriggered, isFalse);
    });
  });

  group('ReadinessEntry JSON round-trip', () {
    test('round-trips inputs, result, and calculation version', () {
      final date = DateTime(2026, 9, 13);
      const inputs = ReadinessInputs(
        sleepHours: 7,
        sleepConsistency: 0.7,
        soreness: 0.2,
        fatigue: 0.2,
        energy: 0.8,
        recentTrainingLoad: 0.3,
      );
      const result = ReadinessResult(
        level: ReadinessLevel.green,
        score: 0.8,
        notes: ['looks good'],
        safetyOverrideTriggered: false,
      );
      final entry = ReadinessEntry(date: date, inputs: inputs, result: result);

      final decoded = ReadinessEntry.fromJson(date, entry.toJson());

      expect(decoded.date, date);
      expect(decoded.calculationVersion, readinessCalculationVersion);
      expect(decoded.inputs.sleepHours, inputs.sleepHours);
      expect(decoded.result.level, ReadinessLevel.green);
    });
  });

  test('readinessDocId formats as yyyy-MM-dd', () {
    expect(readinessDocId(DateTime(2026, 1, 5)), '2026-01-05');
    expect(readinessDocId(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
