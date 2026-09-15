import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/streak_calculator.dart';
import 'package:fitness_tracker/features/adherence/domain/adherence_summary.dart';

DailyAdherenceSummary _day(DateTime date, double? score) => DailyAdherenceSummary(
      date: date,
      overallScore: score,
      componentScores: const {},
      excludedComponents: const {},
      calculatedAt: date,
    );

void main() {
  group('StreakCalculator.calculate', () {
    test('an unbroken run counts every qualifying day as both current and longest', () {
      final days = [
        _day(DateTime(2026, 9, 15), 0.9),
        _day(DateTime(2026, 9, 14), 0.7),
        _day(DateTime(2026, 9, 13), 0.6), // exactly at threshold: qualifies
        _day(DateTime(2026, 9, 12), 0.8),
      ];

      final result = StreakCalculator.calculate(days);

      expect(result.current, 4);
      expect(result.longest, 4);
    });

    test('a low-score day breaks the current streak', () {
      final days = [
        _day(DateTime(2026, 9, 15), 0.9),
        _day(DateTime(2026, 9, 14), 0.7),
        _day(DateTime(2026, 9, 13), 0.59), // just under threshold: breaks
        _day(DateTime(2026, 9, 12), 0.9),
        _day(DateTime(2026, 9, 11), 0.9),
      ];

      final result = StreakCalculator.calculate(days);

      expect(result.current, 2);
      // Longest run anywhere in the list is the two days after the break.
      expect(result.longest, 2);
    });

    test('a missing day (null overallScore) breaks the current streak, without zeroing prior days', () {
      final days = [
        _day(DateTime(2026, 9, 15), 0.9),
        _day(DateTime(2026, 9, 14), null), // fully-excluded day: no data to score
        _day(DateTime(2026, 9, 13), 0.9),
      ];

      final result = StreakCalculator.calculate(days);

      // Current streak is just today (1) — the missing day breaks it — but
      // that break doesn't retroactively erase the fact today qualified.
      expect(result.current, 1);
      expect(result.longest, 1);
    });

    test('a missing day deeper in the list still caps the longest run', () {
      final days = [
        _day(DateTime(2026, 9, 15), 0.9),
        _day(DateTime(2026, 9, 14), 0.9),
        _day(DateTime(2026, 9, 13), 0.9),
        _day(DateTime(2026, 9, 12), null),
        _day(DateTime(2026, 9, 11), 0.9),
        _day(DateTime(2026, 9, 10), 0.9),
      ];

      final result = StreakCalculator.calculate(days);

      expect(result.current, 3);
      expect(result.longest, 3);
    });

    test('an empty list yields a zero streak', () {
      final result = StreakCalculator.calculate(const []);

      expect(result.current, 0);
      expect(result.longest, 0);
    });

    test('a single qualifying day yields current = longest = 1', () {
      final result = StreakCalculator.calculate([_day(DateTime(2026, 9, 15), 0.75)]);

      expect(result.current, 1);
      expect(result.longest, 1);
    });

    test('a single non-qualifying day yields a zero streak', () {
      final result = StreakCalculator.calculate([_day(DateTime(2026, 9, 15), 0.1)]);

      expect(result.current, 0);
      expect(result.longest, 0);
    });

    test('a custom threshold is respected', () {
      final days = [_day(DateTime(2026, 9, 15), 0.5)];

      expect(StreakCalculator.calculate(days, threshold: 0.4).current, 1);
      expect(StreakCalculator.calculate(days, threshold: 0.6).current, 0);
    });
  });

  group('StreakCalculator.fromQualifyingDays', () {
    test('reuses the same run-counting rule over plain booleans (e.g. per-habit completion)', () {
      final result = StreakCalculator.fromQualifyingDays([true, true, false, true]);

      expect(result.current, 2);
      expect(result.longest, 2);
    });

    test('empty input yields a zero streak', () {
      final result = StreakCalculator.fromQualifyingDays(const []);

      expect(result.current, 0);
      expect(result.longest, 0);
    });
  });
}
