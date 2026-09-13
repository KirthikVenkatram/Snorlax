import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/habits/domain/habit.dart';

void main() {
  group('Habit', () {
    test('round-trips through JSON for a daily habit', () {
      final habit = Habit(
        id: 'h1',
        name: 'Drink water',
        cadence: HabitCadence.daily,
        createdAt: DateTime(2026, 9, 1),
      );

      final json = habit.toJson();
      final decoded = Habit.fromJson('h1', json);

      expect(decoded.id, 'h1');
      expect(decoded.name, 'Drink water');
      expect(decoded.cadence, HabitCadence.daily);
      expect(decoded.timesPerWeek, isNull);
      expect(decoded.archived, isFalse);
    });

    test('round-trips through JSON for a weekly habit with timesPerWeek', () {
      final habit = Habit(
        id: 'h2',
        name: 'Gym session',
        cadence: HabitCadence.weekly,
        timesPerWeek: 3,
        createdAt: DateTime(2026, 9, 1),
      );

      final decoded = Habit.fromJson('h2', habit.toJson());

      expect(decoded.cadence, HabitCadence.weekly);
      expect(decoded.timesPerWeek, 3);
    });

    test('constructing a weekly habit without timesPerWeek throws', () {
      expect(
        () => Habit(
          id: 'h3',
          name: 'Bad',
          cadence: HabitCadence.weekly,
          createdAt: DateTime(2026, 9, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('validate rejects timesPerWeek outside 1-7 for weekly habits', () {
      expect(
        () => Habit.validate(cadence: HabitCadence.weekly, timesPerWeek: 0),
        throwsArgumentError,
      );
      expect(
        () => Habit.validate(cadence: HabitCadence.weekly, timesPerWeek: 8),
        throwsArgumentError,
      );
      expect(
        () => Habit.validate(cadence: HabitCadence.weekly, timesPerWeek: null),
        throwsArgumentError,
      );
    });

    test('validate ignores timesPerWeek for daily habits', () {
      expect(
        () => Habit.validate(cadence: HabitCadence.daily, timesPerWeek: null),
        returnsNormally,
      );
    });

    test('copyWith archives a habit while preserving other fields', () {
      final habit = Habit(
        id: 'h4',
        name: 'Stretch',
        cadence: HabitCadence.daily,
        createdAt: DateTime(2026, 9, 1),
      );

      final archived = habit.copyWith(archived: true);

      expect(archived.archived, isTrue);
      expect(archived.name, 'Stretch');
      expect(archived.id, 'h4');
    });
  });
}
