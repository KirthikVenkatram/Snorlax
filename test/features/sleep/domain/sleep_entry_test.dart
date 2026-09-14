import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/sleep/domain/sleep_entry.dart';

void main() {
  group('SleepStageMinutes JSON round-trip', () {
    test('round-trips all fields', () {
      const stages = SleepStageMinutes(awake: 34, rem: 82, deep: 64, light: 252);

      final decoded = SleepStageMinutes.fromJson(stages.toJson());

      expect(decoded.awake, 34);
      expect(decoded.rem, 82);
      expect(decoded.deep, 64);
      expect(decoded.light, 252);
    });

    test('rejects negative minutes', () {
      expect(
        () => SleepStageMinutes(awake: -1, rem: 0, deep: 0, light: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('SleepEntry JSON round-trip', () {
    final date = DateTime(2026, 9, 13);
    final bedtime = DateTime(2026, 9, 12, 23, 48);
    final wakeTime = DateTime(2026, 9, 13, 8, 22);

    test('round-trips required fields with no optional data', () {
      final entry = SleepEntry(
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        awakeMinutes: 34,
        score: 82,
      );

      final decoded = SleepEntry.fromJson(date, entry.toJson());

      expect(decoded.date, date);
      expect(decoded.bedtime, bedtime);
      expect(decoded.wakeTime, wakeTime);
      expect(decoded.awakeMinutes, 34);
      expect(decoded.score, 82);
      expect(decoded.restingHeartRate, isNull);
      expect(decoded.hrv, isNull);
      expect(decoded.stages, isNull);
    });

    test('round-trips optional fields when present', () {
      final entry = SleepEntry(
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        awakeMinutes: 34,
        score: 82,
        restingHeartRate: 62,
        hrv: 58.0,
        stages: const SleepStageMinutes(awake: 34, rem: 82, deep: 64, light: 252),
      );

      final decoded = SleepEntry.fromJson(date, entry.toJson());

      expect(decoded.restingHeartRate, 62);
      expect(decoded.hrv, 58.0);
      expect(decoded.stages, isNotNull);
      expect(decoded.stages!.rem, 82);
    });

    test('rejects an out-of-range score', () {
      expect(
        () => SleepEntry(
          date: date,
          bedtime: bedtime,
          wakeTime: wakeTime,
          awakeMinutes: 0,
          score: 101,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('timeAsleep subtracts awake minutes from time in bed', () {
      final entry = SleepEntry(
        date: date,
        bedtime: bedtime,
        wakeTime: wakeTime,
        awakeMinutes: 34,
        score: 82,
      );

      // In bed: 23:48 -> 08:22 = 8h34m. Minus 34 min awake = 8h.
      expect(entry.timeAsleep, const Duration(hours: 8));
    });

    test('timeAsleep never goes negative', () {
      final entry = SleepEntry(
        date: date,
        bedtime: bedtime,
        wakeTime: bedtime.add(const Duration(minutes: 10)),
        awakeMinutes: 60,
        score: 50,
      );

      expect(entry.timeAsleep, Duration.zero);
    });
  });

  test('sleepDocId formats as yyyy-MM-dd', () {
    expect(sleepDocId(DateTime(2026, 1, 5)), '2026-01-05');
    expect(sleepDocId(DateTime(2026, 12, 31)), '2026-12-31');
  });
}
