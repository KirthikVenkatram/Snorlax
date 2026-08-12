import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/primary_button.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/log_strength_screen.dart';

void main() {
  testWidgets('Save is disabled until an exercise is added, then saves the workout', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);
    await exerciseRepository.seedDefaultsIfEmpty('uid-1');

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LogStrengthScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButtonBefore = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(saveButtonBefore.onPressed, isNull);

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    final saveButtonAfter = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(saveButtonAfter.onPressed, isNotNull);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final workouts = await workoutRepository.listWorkouts('uid-1');
    expect(workouts, hasLength(1));
    expect(workouts.first.exercises!.first.exerciseName, 'Bench Press');
  });

  testWidgets('an invalid duration shows an error and does not save', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final workoutRepository = WorkoutRepository(firestore: firestore);
    final exerciseRepository = ExerciseLibraryRepository(firestore: firestore);
    await exerciseRepository.seedDefaultsIfEmpty('uid-1');

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LogStrengthScreen(
          uid: 'uid-1',
          workoutRepository: workoutRepository,
          exerciseRepository: exerciseRepository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    // Clear the duration field, then try to save.
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text('Enter a duration in whole minutes.'), findsOneWidget);
    expect(saved, isFalse);
    expect(await workoutRepository.listWorkouts('uid-1'), isEmpty);
    // The Save button is still enabled — _saving was reset, not stuck.
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed, isNotNull);
  });
}
