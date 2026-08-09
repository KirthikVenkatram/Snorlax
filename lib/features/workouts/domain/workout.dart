enum WorkoutType { strength, cardio, general }

enum WorkoutSource { manual, strava }

class SetEntry {
  const SetEntry({required this.reps, required this.weightKg});

  final int reps;
  final double weightKg;

  Map<String, dynamic> toJson() => {'reps': reps, 'weightKg': weightKg};

  factory SetEntry.fromJson(Map<String, dynamic> json) => SetEntry(
        reps: json['reps'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
      );
}

class ExerciseEntry {
  const ExerciseEntry({required this.exerciseName, required this.sets});

  final String exerciseName;
  final List<SetEntry> sets;

  Map<String, dynamic> toJson() => {
        'exerciseName': exerciseName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseEntry.fromJson(Map<String, dynamic> json) => ExerciseEntry(
        exerciseName: json['exerciseName'] as String,
        sets: (json['sets'] as List)
            .map((s) => SetEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class Workout {
  const Workout({
    required this.id,
    required this.type,
    required this.source,
    required this.date,
    required this.durationMinutes,
    this.exercises,
    this.distanceKm,
    this.paceMinPerKm,
    this.stravaActivityId,
    this.notes,
  });

  final String id;
  final WorkoutType type;
  final WorkoutSource source;
  final DateTime date;
  final int durationMinutes;

  /// Populated only for [WorkoutType.strength].
  final List<ExerciseEntry>? exercises;

  /// Populated only for [WorkoutType.cardio].
  final double? distanceKm;
  final double? paceMinPerKm;
  final String? stravaActivityId;

  /// Populated only for [WorkoutType.general].
  final String? notes;
}
