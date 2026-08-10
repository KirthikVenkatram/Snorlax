import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/domain/workout.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  group('WorkoutRepository', () {
    test('createStrengthWorkout writes the workout and its exercises subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createStrengthWorkout(
        uid: 'uid-1',
        date: DateTime(2026, 8, 1),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Bench Press', sets: [
            SetEntry(reps: 5, weightKg: 80),
            SetEntry(reps: 5, weightKg: 80),
          ]),
        ],
      );

      final workout = await repository.getWorkout('uid-1', id);

      expect(workout, isNotNull);
      expect(workout!.type, WorkoutType.strength);
      expect(workout.source, WorkoutSource.manual);
      expect(workout.durationMinutes, 45);
      expect(workout.exercises, hasLength(1));
      expect(workout.exercises!.first.exerciseName, 'Bench Press');
      expect(workout.exercises!.first.sets, hasLength(2));
      expect(workout.exercises!.first.sets.first.weightKg, 80);
    });

    test('createGeneralWorkout writes notes inline with no exercises subcollection', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1',
        date: DateTime(2026, 8, 2),
        durationMinutes: 30,
        notes: 'Easy mobility session',
      );

      final workout = await repository.getWorkout('uid-1', id);

      expect(workout!.type, WorkoutType.general);
      expect(workout.notes, 'Easy mobility session');
      expect(workout.exercises, isNull);
    });

    test('listWorkouts returns workouts newest-first', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'first');
      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 3), durationMinutes: 10, notes: 'third');
      await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 2), durationMinutes: 10, notes: 'second');

      final workouts = await repository.listWorkouts('uid-1');

      expect(workouts.map((w) => w.notes), ['third', 'second', 'first']);
    });

    test('updateGeneralWorkout modifies an existing manual workout', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'original');

      await repository.updateGeneralWorkout(
        uid: 'uid-1', workoutId: id, durationMinutes: 20, notes: 'updated');

      final workout = await repository.getWorkout('uid-1', id);
      expect(workout!.durationMinutes, 20);
      expect(workout.notes, 'updated');
    });

    test('updateStrengthWorkout modifies duration of an existing strength workout', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createStrengthWorkout(
        uid: 'uid-1',
        date: DateTime(2026, 8, 1),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Bench Press', sets: [
            SetEntry(reps: 5, weightKg: 80),
          ]),
        ],
      );

      await repository.updateStrengthWorkout(
        uid: 'uid-1', workoutId: id, durationMinutes: 60);

      final workout = await repository.getWorkout('uid-1', id);
      expect(workout!.durationMinutes, 60);
      expect(workout.exercises, hasLength(1));
      expect(workout.exercises!.first.exerciseName, 'Bench Press');
    });

    test('deleteWorkout removes the workout document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = WorkoutRepository(firestore: firestore);

      final id = await repository.createGeneralWorkout(
        uid: 'uid-1', date: DateTime(2026, 8, 1), durationMinutes: 10, notes: 'to delete');

      await repository.deleteWorkout('uid-1', id);

      final workout = await repository.getWorkout('uid-1', id);
      expect(workout, isNull);
    });
  });
}
