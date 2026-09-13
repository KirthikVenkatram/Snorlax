import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/coach/data/coach_service.dart';
import 'package:fitness_tracker/features/coach/presentation/coach_recommendations_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  testWidgets('lists a pending recommendation with accept/reject actions', (tester) async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('users').doc('u1').collection('coachRecommendations').doc('r1').set({
      'summary': 'Small deficit adjustment',
      'rationale': 'Progress has stalled for 3 weeks.',
      'status': 'pending',
      'createdAt': '2026-01-01T00:00:00.000Z',
    });
    final service = CoachService(firestore: firestore, functions: MockFirebaseFunctions());

    await tester.pumpWidget(
      MaterialApp(home: CoachRecommendationsScreen(uid: 'u1', service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Small deficit adjustment'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('shows an empty state with no recommendations', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = CoachService(firestore: firestore, functions: MockFirebaseFunctions());

    await tester.pumpWidget(
      MaterialApp(home: CoachRecommendationsScreen(uid: 'u1', service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No recommendations yet.'), findsOneWidget);
  });
}
