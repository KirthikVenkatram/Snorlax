/// Neutral/excluded reasons that remove a habit from a day's denominator
/// instead of counting it as a miss. These intentionally mirror the
/// exclusion reasons used by the adherence calculator (see
/// `lib/core/calculations/adherence_calculator.dart`) so a single vocabulary
/// covers both habits and overall adherence exclusions.
enum ExclusionReason { illness, injury, plannedRest, travel, scheduleChange }

/// A single habit's completion state for one calendar date.
class HabitEntryStatus {
  const HabitEntryStatus({
    required this.completed,
    this.excluded = false,
    this.reason,
  }) : assert(
          !excluded || reason != null,
          'an excluded entry must carry a reason',
        ),
        assert(
          !(completed && excluded),
          'an entry cannot be both completed and excluded',
        );

  final bool completed;
  final bool excluded;
  final ExclusionReason? reason;

  Map<String, dynamic> toJson() => {
        'completed': completed,
        'excluded': excluded,
        if (reason != null) 'reason': reason!.name,
      };

  factory HabitEntryStatus.fromJson(Map<String, dynamic> json) => HabitEntryStatus(
        completed: json['completed'] as bool? ?? false,
        excluded: json['excluded'] as bool? ?? false,
        reason: json['reason'] != null ? ExclusionReason.values.byName(json['reason'] as String) : null,
      );
}

/// A date-keyed document mapping habitId -> [HabitEntryStatus], matching
/// the `users/{uid}/habitCompletions/{date}` document shape from the spec.
class HabitCompletion {
  const HabitCompletion({required this.date, required this.entries});

  final DateTime date;
  final Map<String, HabitEntryStatus> entries;

  HabitCompletion withEntry(String habitId, HabitEntryStatus status) => HabitCompletion(
        date: date,
        entries: {...entries, habitId: status},
      );

  Map<String, dynamic> toJson() => {
        for (final entry in entries.entries) entry.key: entry.value.toJson(),
      };

  factory HabitCompletion.fromJson(DateTime date, Map<String, dynamic> json) => HabitCompletion(
        date: date,
        entries: {
          for (final entry in json.entries)
            entry.key: HabitEntryStatus.fromJson(Map<String, dynamic>.from(entry.value as Map)),
        },
      );
}

/// Normalizes a [DateTime] to a date-only key (`yyyy-MM-dd`), matching the
/// document-id convention of `users/{uid}/habitCompletions/{date}`.
String habitCompletionDocId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
