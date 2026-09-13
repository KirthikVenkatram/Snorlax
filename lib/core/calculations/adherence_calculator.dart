/// Deterministic, pure calculation of daily and weekly adherence summaries
/// from per-component scores.
///
/// This module performs no I/O: callers (the adherence repository) are
/// responsible for gathering component scores from nutrition/workout/habit
/// data and calling into this calculator.
library;

/// The four components the spec defines: nutrition, training, habits, and
/// recovery.
enum AdherenceComponent { nutrition, training, habits, recovery }

/// The relative weight given to each [AdherenceComponent] when combining
/// them into an overall adherence score. Weights need not sum to 1.0 —
/// [AdherenceCalculator] renormalizes across only the components that are
/// not excluded for a given day.
class AdherenceWeights {
  const AdherenceWeights({
    this.nutrition = 0.40,
    this.training = 0.25,
    this.habits = 0.20,
    this.recovery = 0.15,
  });

  final double nutrition;
  final double training;
  final double habits;
  final double recovery;

  double forComponent(AdherenceComponent component) => switch (component) {
        AdherenceComponent.nutrition => nutrition,
        AdherenceComponent.training => training,
        AdherenceComponent.habits => habits,
        AdherenceComponent.recovery => recovery,
      };

  Map<String, dynamic> toJson() => {
        'nutrition': nutrition,
        'training': training,
        'habits': habits,
        'recovery': recovery,
      };

  factory AdherenceWeights.fromJson(Map<String, dynamic> json) => AdherenceWeights(
        nutrition: (json['nutrition'] as num?)?.toDouble() ?? 0.40,
        training: (json['training'] as num?)?.toDouble() ?? 0.25,
        habits: (json['habits'] as num?)?.toDouble() ?? 0.20,
        recovery: (json['recovery'] as num?)?.toDouble() ?? 0.15,
      );
}

/// A single component's contribution to a day's adherence: either a score
/// in `[0, 1]`, or excluded (a neutral/planned-rest style reason) in which
/// case it is omitted from both the numerator and the denominator rather
/// than counted as a 0.
class ComponentInput {
  const ComponentInput.scored(double score)
      : score = score,
        excluded = false,
        assert(score >= 0 && score <= 1, 'score must be in [0, 1]');

  const ComponentInput.excluded()
      : score = null,
        excluded = true;

  final double? score;
  final bool excluded;
}

/// The computed result for one day: an overall score in `[0, 1]` (or null
/// if every component was excluded that day) plus the per-component scores
/// that produced it, so UIs can show a breakdown.
class DailyAdherenceResult {
  const DailyAdherenceResult({
    required this.date,
    required this.overallScore,
    required this.componentScores,
    required this.excludedComponents,
  });

  final DateTime date;

  /// Null when every component was excluded for this day — there is
  /// nothing to score, and this should be presented neutrally (not as a
  /// zero or a miss).
  final double? overallScore;
  final Map<AdherenceComponent, double> componentScores;
  final Set<AdherenceComponent> excludedComponents;
}

class WeeklyAdherenceResult {
  const WeeklyAdherenceResult({
    required this.weekId,
    required this.overallScore,
    required this.dailyScores,
  });

  final String weekId;

  /// Null when every day in the week was excluded or had no data.
  final double? overallScore;
  final List<double?> dailyScores;
}

class AdherenceCalculator {
  AdherenceCalculator._();

  /// Combines per-component inputs for a single day into an overall score.
  ///
  /// Excluded components are removed from both the numerator and the
  /// denominator — i.e. the remaining weights are renormalized to sum to
  /// 1.0 — so a planned rest day or illness does not pull the score down
  /// (or up) relative to a normal day. If every component is excluded,
  /// [DailyAdherenceResult.overallScore] is null.
  static DailyAdherenceResult calculateDaily({
    required DateTime date,
    required Map<AdherenceComponent, ComponentInput> inputs,
    AdherenceWeights weights = const AdherenceWeights(),
  }) {
    final componentScores = <AdherenceComponent, double>{};
    final excluded = <AdherenceComponent>{};
    var weightedSum = 0.0;
    var totalWeight = 0.0;

    for (final component in AdherenceComponent.values) {
      final input = inputs[component];
      if (input == null || input.excluded) {
        excluded.add(component);
        continue;
      }
      final weight = weights.forComponent(component);
      componentScores[component] = input.score!;
      weightedSum += input.score! * weight;
      totalWeight += weight;
    }

    final overallScore = totalWeight > 0 ? weightedSum / totalWeight : null;

    return DailyAdherenceResult(
      date: date,
      overallScore: overallScore,
      componentScores: componentScores,
      excludedComponents: excluded,
    );
  }

  /// Rolls up a week's worth of [DailyAdherenceResult.overallScore] values
  /// into a single weekly score, ignoring days with no score (fully
  /// excluded or no data) — those days shrink the denominator rather than
  /// counting as zero.
  static WeeklyAdherenceResult calculateWeekly({
    required String weekId,
    required List<double?> dailyScores,
  }) {
    final scored = dailyScores.whereType<double>().toList();
    final overall = scored.isEmpty ? null : scored.reduce((a, b) => a + b) / scored.length;
    return WeeklyAdherenceResult(weekId: weekId, overallScore: overall, dailyScores: dailyScores);
  }

  /// Returns the ISO-week-based id (`yyyy-Www`) used as the
  /// `adherenceWeekly/{weekId}` document id for the week containing [date].
  static String weekIdFor(DateTime date) {
    // ISO 8601 week calculation: the week containing the year's first
    // Thursday is week 1.
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstDayOfYear = DateTime(thursday.year, 1, 1);
    final weekNumber = ((thursday.difference(firstDayOfYear).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Supportive, descriptive (never punitive) copy for an overall score.
  /// Returns a neutral message when [overallScore] is null (fully excluded
  /// day/week).
  static String supportiveSummary(double? overallScore) {
    if (overallScore == null) {
      return "No score today — today's excluded days don't count for or against you.";
    }
    if (overallScore >= 0.85) return "Great alignment with your plan today.";
    if (overallScore >= 0.6) return "Solid progress today, with some room to grow.";
    if (overallScore >= 0.35) return "A lighter day for your plan — every day is a fresh start.";
    return "Today didn't go as planned, and that's alright — tomorrow is a new chance.";
  }
}
