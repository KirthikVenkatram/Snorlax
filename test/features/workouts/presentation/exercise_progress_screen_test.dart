import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/domain/workout.dart';
import 'package:fitness_tracker/features/workouts/presentation/exercise_progress_screen.dart';

void main() {
  test('topSetProgressPoints extracts the heaviest set per session for the named exercise', () {
    final workouts = [
      Workout(
        id: 'w1',
        type: WorkoutType.strength,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 1),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Bench Press', sets: [
            SetEntry(reps: 5, weightKg: 70),
            SetEntry(reps: 5, weightKg: 75),
          ]),
        ],
      ),
      Workout(
        id: 'w2',
        type: WorkoutType.strength,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 8),
        durationMinutes: 45,
        exercises: [
          ExerciseEntry(exerciseName: 'Squat', sets: [SetEntry(reps: 5, weightKg: 100)]),
          ExerciseEntry(exerciseName: 'Bench Press', sets: [SetEntry(reps: 3, weightKg: 80)]),
        ],
      ),
      Workout(
        id: 'w3',
        type: WorkoutType.general,
        source: WorkoutSource.manual,
        date: DateTime(2026, 1, 10),
        durationMinutes: 20,
        notes: 'not a strength workout',
      ),
    ];

    final points = topSetProgressPoints(workouts, 'Bench Press');

    expect(points, hasLength(2));
    expect(points[0].date, DateTime(2026, 1, 1));
    expect(points[0].value, 75);
    expect(points[1].date, DateTime(2026, 1, 8));
    expect(points[1].value, 80);
  });
}
