import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/adherence_calculator.dart';

/// A persisted daily adherence summary at `users/{uid}/adherenceDaily/{date}`.
class DailyAdherenceSummary {
  const DailyAdherenceSummary({
    required this.date,
    required this.overallScore,
    required this.componentScores,
    required this.excludedComponents,
    required this.calculatedAt,
  });

  final DateTime date;
  final double? overallScore;
  final Map<AdherenceComponent, double> componentScores;
  final Set<AdherenceComponent> excludedComponents;
  final DateTime calculatedAt;

  factory DailyAdherenceSummary.fromResult(DailyAdherenceResult result, {DateTime? calculatedAt}) =>
      DailyAdherenceSummary(
        date: result.date,
        overallScore: result.overallScore,
        componentScores: result.componentScores,
        excludedComponents: result.excludedComponents,
        calculatedAt: calculatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        if (overallScore != null) 'overallScore': overallScore,
        'componentScores': {for (final e in componentScores.entries) e.key.name: e.value},
        'excludedComponents': excludedComponents.map((c) => c.name).toList(),
        'calculatedAt': Timestamp.fromDate(calculatedAt),
      };

  factory DailyAdherenceSummary.fromJson(DateTime date, Map<String, dynamic> json) => DailyAdherenceSummary(
        date: date,
        overallScore: (json['overallScore'] as num?)?.toDouble(),
        componentScores: {
          for (final e in (json['componentScores'] as Map? ?? const {}).entries)
            AdherenceComponent.values.byName(e.key as String): (e.value as num).toDouble(),
        },
        excludedComponents: {
          for (final name in (json['excludedComponents'] as List? ?? const []))
            AdherenceComponent.values.byName(name as String),
        },
        calculatedAt: (json['calculatedAt'] as Timestamp).toDate(),
      );
}

/// A persisted weekly adherence summary at
/// `users/{uid}/adherenceWeekly/{weekId}`.
class WeeklyAdherenceSummary {
  const WeeklyAdherenceSummary({
    required this.weekId,
    required this.overallScore,
    required this.dailyScores,
    required this.calculatedAt,
  });

  final String weekId;
  final double? overallScore;
  final List<double?> dailyScores;
  final DateTime calculatedAt;

  factory WeeklyAdherenceSummary.fromResult(WeeklyAdherenceResult result, {DateTime? calculatedAt}) =>
      WeeklyAdherenceSummary(
        weekId: result.weekId,
        overallScore: result.overallScore,
        dailyScores: result.dailyScores,
        calculatedAt: calculatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        if (overallScore != null) 'overallScore': overallScore,
        'dailyScores': dailyScores,
        'calculatedAt': Timestamp.fromDate(calculatedAt),
      };

  factory WeeklyAdherenceSummary.fromJson(String weekId, Map<String, dynamic> json) => WeeklyAdherenceSummary(
        weekId: weekId,
        overallScore: (json['overallScore'] as num?)?.toDouble(),
        dailyScores: (json['dailyScores'] as List? ?? const [])
            .map((v) => (v as num?)?.toDouble())
            .toList(),
        calculatedAt: (json['calculatedAt'] as Timestamp).toDate(),
      );
}
