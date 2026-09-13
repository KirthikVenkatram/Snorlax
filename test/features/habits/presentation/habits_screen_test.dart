import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/habits/domain/habit.dart';
import 'package:fitness_tracker/features/habits/presentation/habits_screen.dart';

void main() {
  testWidgets('habits screen creates a daily habit', (tester) async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: HabitsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habitNameField')), 'Drink water');
    await tester.tap(find.text('Save habit'));
    await tester.pumpAndSettle();

    expect((await repository.listHabits('u')).single.name, 'Drink water');
    expect(find.text('Drink water'), findsOneWidget);
  });

  testWidgets('completing a habit updates its status label', (tester) async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    await repository.createHabit(
      'u',
      Habit(id: 'h1', name: 'Stretch', cadence: HabitCadence.daily, createdAt: DateTime(2026, 9, 1)),
    );

    await tester.pumpWidget(
      MaterialApp(home: HabitsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not yet today'), findsOneWidget);

    await tester.tap(find.byKey(const Key('habitCompleteButton_h1')));
    await tester.pumpAndSettle();

    expect(find.text('Completed today'), findsOneWidget);
  });

  testWidgets('archiving a habit removes it from the list', (tester) async {
    final repository = HabitRepository(firestore: FakeFirebaseFirestore());
    await repository.createHabit(
      'u',
      Habit(id: 'h1', name: 'Stretch', cadence: HabitCadence.daily, createdAt: DateTime(2026, 9, 1)),
    );

    await tester.pumpWidget(
      MaterialApp(home: HabitsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('habitArchiveButton_h1')));
    await tester.pumpAndSettle();

    expect(find.text('Stretch'), findsNothing);
    expect((await repository.listHabits('u')), isEmpty);
  });
}
