import 'package:cloud_firestore/cloud_firestore.dart';

/// How often a habit is expected to be performed.
///
/// `daily` habits are expected every day; `weekly` habits are expected a
/// target number of times per week (see [Habit.timesPerWeek]).
enum HabitCadence { daily, weekly }

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.cadence,
    required this.createdAt,
    this.timesPerWeek,
    this.archived = false,
  }) : assert(
          cadence != HabitCadence.weekly || timesPerWeek != null,
          'timesPerWeek is required for weekly-cadence habits',
        );

  final String id;
  final String name;
  final HabitCadence cadence;

  /// Required and validated to be in 1-7 for [HabitCadence.weekly] habits.
  /// Ignored for [HabitCadence.daily] habits.
  final int? timesPerWeek;
  final DateTime createdAt;
  final bool archived;

  Habit copyWith({String? name, bool? archived}) => Habit(
        id: id,
        name: name ?? this.name,
        cadence: cadence,
        timesPerWeek: timesPerWeek,
        createdAt: createdAt,
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'cadence': cadence.name,
        if (timesPerWeek != null) 'timesPerWeek': timesPerWeek,
        'createdAt': Timestamp.fromDate(createdAt),
        'archived': archived,
      };

  factory Habit.fromJson(String id, Map<String, dynamic> json) => Habit(
        id: id,
        name: json['name'] as String,
        cadence: HabitCadence.values.byName(json['cadence'] as String),
        timesPerWeek: (json['timesPerWeek'] as num?)?.toInt(),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        archived: json['archived'] as bool? ?? false,
      );

  /// Validates cadence-specific invariants. Throws [ArgumentError] if a
  /// weekly habit's [timesPerWeek] is missing or outside the valid 1-7
  /// range. Daily habits ignore [timesPerWeek] entirely.
  static void validate({required HabitCadence cadence, int? timesPerWeek}) {
    if (cadence != HabitCadence.weekly) return;
    if (timesPerWeek == null || timesPerWeek < 1 || timesPerWeek > 7) {
      throw ArgumentError.value(
        timesPerWeek,
        'timesPerWeek',
        'must be between 1 and 7 for a weekly-cadence habit',
      );
    }
  }
}
