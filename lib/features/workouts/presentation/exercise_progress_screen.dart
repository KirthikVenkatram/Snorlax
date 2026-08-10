import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_chart.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';

/// Extracts one [ProgressPoint] per workout session that includes [exerciseName],
/// using the heaviest set logged for that exercise in that session, sorted
/// oldest-first (chart reading order).
List<ProgressPoint> topSetProgressPoints(List<Workout> workouts, String exerciseName) {
  final sessions = workouts.where((w) => w.type == WorkoutType.strength).toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  final points = <ProgressPoint>[];
  for (final workout in sessions) {
    final entry = workout.exercises?.where((e) => e.exerciseName == exerciseName);
    if (entry == null || entry.isEmpty) continue;

    final topWeight = entry.first.sets.map((s) => s.weightKg).reduce((a, b) => a > b ? a : b);
    points.add(ProgressPoint(date: workout.date, value: topWeight));
  }
  return points;
}

class ExerciseProgressScreen extends StatelessWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.uid,
    required this.exerciseName,
    required this.workoutRepository,
  });

  final String uid;
  final String exerciseName;
  final WorkoutRepository workoutRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<List<Workout>>(
            future: workoutRepository.listWorkouts(uid),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final points = topSetProgressPoints(snapshot.data!, exerciseName);
              return GlassCard(
                child: SizedBox(height: 240, child: ProgressChart(points: points)),
              );
            },
          ),
        ),
      ),
    );
  }
}
