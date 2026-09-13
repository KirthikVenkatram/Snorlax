/// A reusable meal definition, persisted at
/// `users/{uid}/mealTemplates/{templateId}`.
///
/// This is intentionally NOT an ingredient/recipe builder (out of scope per
/// the Phase 8 plan) — nutrition and cost per serving are entered directly
/// (manually, for now), the same "trust the user's number, label its
/// source" approach `price_snapshot.dart` takes for individual item prices.
/// [costSource]/[costTimestamp] give the same manual/estimated/live
/// labelling for the template's cost that a raw price snapshot gets.
library;

import 'price_snapshot.dart';

class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    required this.servings,
    required this.caloriesPerServing,
    required this.proteinGPerServing,
    required this.carbsGPerServing,
    required this.fatGPerServing,
    required this.costPerServing,
    required this.currency,
    required this.costSource,
    required this.costTimestamp,
  })  : assert(servings > 0, 'servings must be positive'),
        assert(caloriesPerServing >= 0, 'caloriesPerServing must be non-negative'),
        assert(proteinGPerServing >= 0, 'proteinGPerServing must be non-negative'),
        assert(carbsGPerServing >= 0, 'carbsGPerServing must be non-negative'),
        assert(fatGPerServing >= 0, 'fatGPerServing must be non-negative'),
        assert(costPerServing == null || costPerServing >= 0, 'costPerServing must be non-negative when known');

  final String id;
  final String name;

  /// Number of servings this template's per-serving figures are based on.
  /// Kept for display/authoring context; all calculator inputs below are
  /// already normalized to a single serving.
  final int servings;

  final double caloriesPerServing;
  final double proteinGPerServing;
  final double carbsGPerServing;
  final double fatGPerServing;

  /// Null means "cost unknown" (e.g. the user hasn't priced this template
  /// yet) — the calculator and UI must treat this as "unpriced", never as a
  /// free (0-cost) meal.
  final double? costPerServing;
  final String currency;
  final PriceSource costSource;
  final DateTime costTimestamp;

  Map<String, dynamic> toJson() => {
        'name': name,
        'servings': servings,
        'caloriesPerServing': caloriesPerServing,
        'proteinGPerServing': proteinGPerServing,
        'carbsGPerServing': carbsGPerServing,
        'fatGPerServing': fatGPerServing,
        'costPerServing': costPerServing,
        'currency': currency,
        'costSource': costSource.name,
        'costTimestamp': costTimestamp.toIso8601String(),
      };

  factory MealTemplate.fromJson(String id, Map<String, dynamic> json) => MealTemplate(
        id: id,
        name: json['name'] as String? ?? '',
        servings: (json['servings'] as num?)?.toInt() ?? 1,
        caloriesPerServing: (json['caloriesPerServing'] as num?)?.toDouble() ?? 0,
        proteinGPerServing: (json['proteinGPerServing'] as num?)?.toDouble() ?? 0,
        carbsGPerServing: (json['carbsGPerServing'] as num?)?.toDouble() ?? 0,
        fatGPerServing: (json['fatGPerServing'] as num?)?.toDouble() ?? 0,
        costPerServing: (json['costPerServing'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        costSource: PriceSource.values.byName((json['costSource'] as String?) ?? 'manual'),
        costTimestamp: DateTime.tryParse(json['costTimestamp'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
}
