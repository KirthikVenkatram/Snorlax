import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/coach/data/coach_service.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  group('CoachService', () {
    late MockFirebaseFunctions functions;
    late FakeFirebaseFirestore firestore;
    late CoachService service;

    setUp(() {
      functions = MockFirebaseFunctions();
      firestore = FakeFirebaseFirestore();
      service = CoachService(firestore: firestore, functions: functions);
    });

    test('listRecommendations reads from coachRecommendations, newest first', () async {
      await firestore.collection('users').doc('u1').collection('coachRecommendations').doc('r1').set({
        'summary': 'Older',
        'rationale': 'r',
        'status': 'pending',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });
      await firestore.collection('users').doc('u1').collection('coachRecommendations').doc('r2').set({
        'summary': 'Newer',
        'rationale': 'r',
        'status': 'pending',
        'createdAt': '2026-01-02T00:00:00.000Z',
      });

      final result = await service.listRecommendations('u1');

      expect(result.map((r) => r.summary).toList(), ['Newer', 'Older']);
    });

    test('listEvents reads from coachEvents, newest first', () async {
      await firestore.collection('users').doc('u1').collection('coachEvents').doc('e1').set({
        'recommendationId': 'r1',
        'outcome': 'applied',
        'reason': 'ok',
        'decision': 'approve',
        'createdAt': '2026-01-01T00:00:00.000Z',
      });

      final result = await service.listEvents('u1');

      expect(result, hasLength(1));
      expect(result.first.outcome, 'applied');
    });

    test('generateRecommendation calls the callable and returns the new id', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('generateRecommendation')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>()).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({'id': 'new-id'});

      final id = await service.generateRecommendation();

      expect(id, 'new-id');
    });

    test(
        'generateMealPlanRecommendation calls the generateMealPlanRecommendation callable and returns the new id '
        '(review fix: this seam was previously unreachable from the app)', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('generateMealPlanRecommendation')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>()).thenAnswer((_) async => result);
      when(() => result.data).thenReturn({'id': 'meal-plan-rec-id'});

      final id = await service.generateMealPlanRecommendation();

      expect(id, 'meal-plan-rec-id');
    });

    test('submitDecision calls handleCommand with the recommendation id and decision', () async {
      final callable = MockHttpsCallable();
      final result = MockHttpsCallableResult<Map<String, dynamic>>();
      when(() => functions.httpsCallable('handleCommand')).thenReturn(callable);
      when(() => callable.call<Map<String, dynamic>>(any())).thenAnswer((_) async => result);

      await service.submitDecision('r1', approve: true);

      verify(() => callable.call<Map<String, dynamic>>({
            'recommendationId': 'r1',
            'decision': 'approve',
          })).called(1);
    });
  });
}
