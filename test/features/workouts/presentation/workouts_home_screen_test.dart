import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/workouts_home_screen.dart';

void main() {
  testWidgets('lists previously logged workouts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);

    await workoutRepository.createGeneralWorkout(
      uid: 'uid-1',
      date: DateTime(2026, 8, 1),
      durationMinutes: 30,
      notes: 'Morning mobility',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsHomeScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning mobility'), findsOneWidget);
  });

  testWidgets('shows an empty state with no workouts', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);

    await tester.pumpWidget(
      MaterialApp(
        home: WorkoutsHomeScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No workouts logged yet.'), findsOneWidget);
  });
}
