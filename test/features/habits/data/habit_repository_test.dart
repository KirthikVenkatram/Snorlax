import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/habits/domain/habit.dart';
import 'package:fitness_tracker/features/habits/domain/habit_completion.dart';

Habit _habit(String id, {HabitCadence cadence = HabitCadence.daily, int? timesPerWeek}) => Habit(
      id: id,
      name: id,
      cadence: cadence,
      timesPerWeek: timesPerWeek,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  test('createHabit persists and listHabits returns it', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());

    await repository.createHabit('u', _habit('water'));

    final habits = await repository.listHabits('u');
    expect(habits, hasLength(1));
    expect(habits.single.id, 'water');
  });

  test('createHabit rejects a weekly habit with an out-of-range timesPerWeek', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());

    expect(
      () => repository.createHabit(
        'u',
        _habit('bad', cadence: HabitCadence.weekly, timesPerWeek: 9),
      ),
      throwsArgumentError,
    );
  });

  test('listHabits excludes archived habits by default but includes them on request', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    await repository.createHabit('u', _habit('water'));
    await repository.createHabit('u', _habit('stretch'));
    await repository.archiveHabit('u', 'stretch');

    final active = await repository.listHabits('u');
    expect(active.map((h) => h.id), ['water']);

    final all = await repository.listHabits('u', includeArchived: true);
    expect(all.map((h) => h.id).toSet(), {'water', 'stretch'});
  });

  test('completeHabit merges entries for the same date without clobbering other habits', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    final date = DateTime(2026, 9, 10);

    await repository.completeHabit('u', date, 'water', completed: true);
    await repository.completeHabit('u', date, 'stretch', completed: false);

    final completion = await repository.getCompletion('u', date);
    expect(completion, isNotNull);
    expect(completion!.entries['water']!.completed, isTrue);
    expect(completion.entries['stretch']!.completed, isFalse);
  });

  test('completeHabit supports excluded entries with a reason', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    final date = DateTime(2026, 9, 10);

    await repository.completeHabit(
      'u',
      date,
      'water',
      completed: false,
      excluded: true,
      reason: ExclusionReason.illness,
    );

    final completion = await repository.getCompletion('u', date);
    expect(completion!.entries['water']!.excluded, isTrue);
    expect(completion.entries['water']!.reason, ExclusionReason.illness);
  });

  test('getCompletion returns null when no completions exist for the date', () async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    final completion = await repository.getCompletion('u', DateTime(2026, 9, 10));
    expect(completion, isNull);
  });
}
