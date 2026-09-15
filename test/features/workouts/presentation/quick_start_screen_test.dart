import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/quick_start_screen.dart';

void main() {
  testWidgets('Start session is disabled until an exercise is added, then hands off to the session runner',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);
    await exerciseRepository.addCustom('uid-1', 'Bench Press');

    await tester.pumpWidget(
      MaterialApp(
        home: QuickStartScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start session'), findsOneWidget);

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Press').last);
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);

    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Handed off to the active session runner with the planned exercise.
    expect(find.text('Exit'), findsOneWidget);
    expect(find.textContaining('Bench Press'), findsWidgets);
  });
}
