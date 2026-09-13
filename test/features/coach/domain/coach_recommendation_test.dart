import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/coach/domain/coach_recommendation.dart';

void main() {
  group('CoachRecommendation.fromJson', () {
    test('parses a pending advice-only recommendation', () {
      final recommendation = CoachRecommendation.fromJson('r1', {
        'summary': 'Stay the course',
        'rationale': 'Adherence has been strong.',
        'proposedCommand': null,
        'status': 'pending',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'contextSchemaVersion': 1,
      });

      expect(recommendation.id, 'r1');
      expect(recommendation.status, RecommendationStatus.pending);
      expect(recommendation.proposedCommand, isNull);
      expect(recommendation.contextSchemaVersion, 1);
    });

    test('parses a proposedCommand payload', () {
      final recommendation = CoachRecommendation.fromJson('r2', {
        'summary': 'Adjust target',
        'rationale': 'Progress stalled.',
        'proposedCommand': {
          'type': 'nutritionTargetChange',
          'dailyCalories': 2000,
        },
        'status': 'accepted',
        'createdAt': '2026-01-02T00:00:00.000Z',
      });

      expect(recommendation.status, RecommendationStatus.accepted);
      expect(recommendation.proposedCommand?.type, 'nutritionTargetChange');
      expect(recommendation.proposedCommand?.raw['dailyCalories'], 2000);
    });

    test('defaults to pending status when missing', () {
      final recommendation = CoachRecommendation.fromJson('r3', {
        'summary': 's',
        'rationale': 'r',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      expect(recommendation.status, RecommendationStatus.pending);
    });
  });
}
