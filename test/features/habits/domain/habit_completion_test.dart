import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/habits/domain/habit_completion.dart';

void main() {
  group('HabitEntryStatus', () {
    test('round-trips a completed entry through JSON', () {
      const status = HabitEntryStatus(completed: true);
      final decoded = HabitEntryStatus.fromJson(status.toJson());

      expect(decoded.completed, isTrue);
      expect(decoded.excluded, isFalse);
      expect(decoded.reason, isNull);
    });

    test('round-trips an excluded entry with a reason through JSON', () {
      const status = HabitEntryStatus(
        completed: false,
        excluded: true,
        reason: ExclusionReason.illness,
      );
      final decoded = HabitEntryStatus.fromJson(status.toJson());

      expect(decoded.excluded, isTrue);
      expect(decoded.reason, ExclusionReason.illness);
    });

    test('an excluded entry without a reason is invalid', () {
      expect(
        () => HabitEntryStatus(completed: false, excluded: true),
        throwsA(isA<AssertionError>()),
      );
    });

    test('an entry cannot be both completed and excluded', () {
      expect(
        () => HabitEntryStatus(completed: true, excluded: true, reason: ExclusionReason.travel),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('HabitCompletion', () {
    test('withEntry adds/replaces a single habit entry without disturbing others', () {
      final date = DateTime(2026, 9, 10);
      final base = HabitCompletion(date: date, entries: const {
        'h1': HabitEntryStatus(completed: true),
        'h2': HabitEntryStatus(completed: false),
      });

      final updated = base.withEntry('h1', const HabitEntryStatus(completed: false));

      expect(updated.entries['h1']!.completed, isFalse);
      expect(updated.entries['h2']!.completed, isFalse);
    });

    test('round-trips through JSON for multiple habits', () {
      final date = DateTime(2026, 9, 10);
      final completion = HabitCompletion(date: date, entries: {
        'h1': const HabitEntryStatus(completed: true),
        'h2': const HabitEntryStatus(
          completed: false,
          excluded: true,
          reason: ExclusionReason.plannedRest,
        ),
      });

      final decoded = HabitCompletion.fromJson(date, completion.toJson());

      expect(decoded.entries['h1']!.completed, isTrue);
      expect(decoded.entries['h2']!.excluded, isTrue);
      expect(decoded.entries['h2']!.reason, ExclusionReason.plannedRest);
    });
  });

  group('habitCompletionDocId', () {
    test('formats a date as zero-padded yyyy-MM-dd', () {
      expect(habitCompletionDocId(DateTime(2026, 1, 5)), '2026-01-05');
      expect(habitCompletionDocId(DateTime(2026, 12, 31)), '2026-12-31');
    });
  });
}
