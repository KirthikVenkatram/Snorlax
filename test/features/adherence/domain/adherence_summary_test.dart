import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/adherence_calculator.dart';
import 'package:fitness_tracker/features/adherence/domain/adherence_summary.dart';

void main() {
  group('DailyAdherenceSummary', () {
    test('round-trips through JSON, including excluded components', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.scored(0.8),
          AdherenceComponent.training: const ComponentInput.excluded(),
          AdherenceComponent.habits: const ComponentInput.scored(1.0),
          AdherenceComponent.recovery: const ComponentInput.excluded(),
        },
      );
      final summary = DailyAdherenceSummary.fromResult(result, calculatedAt: DateTime(2026, 9, 10, 20));

      final decoded = DailyAdherenceSummary.fromJson(DateTime(2026, 9, 10), summary.toJson());

      expect(decoded.overallScore, closeTo(summary.overallScore!, 1e-9));
      expect(decoded.componentScores[AdherenceComponent.nutrition], 0.8);
      expect(decoded.excludedComponents, {AdherenceComponent.training, AdherenceComponent.recovery});
    });

    test('a fully excluded day round-trips a null overall score', () {
      final result = AdherenceCalculator.calculateDaily(
        date: DateTime(2026, 9, 10),
        inputs: {
          AdherenceComponent.nutrition: const ComponentInput.excluded(),
          AdherenceComponent.training: const ComponentInput.excluded(),
          AdherenceComponent.habits: const ComponentInput.excluded(),
          AdherenceComponent.recovery: const ComponentInput.excluded(),
        },
      );
      final summary = DailyAdherenceSummary.fromResult(result);

      final decoded = DailyAdherenceSummary.fromJson(DateTime(2026, 9, 10), summary.toJson());

      expect(decoded.overallScore, isNull);
    });
  });

  group('WeeklyAdherenceSummary', () {
    test('round-trips through JSON, preserving null entries for unscored days', () {
      final result = AdherenceCalculator.calculateWeekly(
        weekId: '2026-W37',
        dailyScores: [1.0, null, 0.5],
      );
      final summary = WeeklyAdherenceSummary.fromResult(result);

      final decoded = WeeklyAdherenceSummary.fromJson('2026-W37', summary.toJson());

      expect(decoded.overallScore, closeTo(summary.overallScore!, 1e-9));
      expect(decoded.dailyScores, [1.0, null, 0.5]);
    });
  });
}
