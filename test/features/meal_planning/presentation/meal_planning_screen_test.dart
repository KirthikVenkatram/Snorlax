import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/features/coach/data/coach_service.dart';
import 'package:fitness_tracker/features/meal_planning/data/budget_repository.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_plan_repository.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_template_repository.dart';
import 'package:fitness_tracker/features/meal_planning/presentation/meal_planning_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  // Regression test for the "Ask coach to propose a plan" wiring: prior to
  // this fix, `generateMealPlanRecommendation` had no caller anywhere in the
  // Flutter app (see docs/superpowers/ISSUES.md, consolidated review pass) —
  // this exercises the button end to end against a mocked callable boundary,
  // matching the convention `coach_service_test.dart` uses.
  testWidgets(
      'tapping "Ask coach to propose a plan" calls generateMealPlanRecommendation and navigates to /coach',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final functions = MockFirebaseFunctions();
    final callable = MockHttpsCallable();
    final result = MockHttpsCallableResult<Map<String, dynamic>>();
    when(() => functions.httpsCallable('generateMealPlanRecommendation')).thenReturn(callable);
    when(() => callable.call<Map<String, dynamic>>()).thenAnswer((_) async => result);
    when(() => result.data).thenReturn({'id': 'new-meal-plan-rec'});
    final coachService = CoachService(firestore: firestore, functions: functions);

    final router = GoRouter(
      initialLocation: '/meal-planning',
      routes: [
        GoRoute(
          path: '/meal-planning',
          builder: (context, state) => MealPlanningScreen(
            uid: 'u',
            budgetRepository: BudgetRepository(firestore: firestore),
            templateRepository: MealTemplateRepository(firestore: firestore),
            planRepository: MealPlanRepository(firestore: firestore),
            coachService: coachService,
          ),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) => const Scaffold(body: Text('Coach screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Ask coach to propose a plan'), findsOneWidget);

    // The button may be below the fold in the test viewport's ListView.
    await tester.ensureVisible(find.text('Ask coach to propose a plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask coach to propose a plan'));
    await tester.pumpAndSettle();

    verify(() => callable.call<Map<String, dynamic>>()).called(1);
    expect(find.text('Coach screen'), findsOneWidget);
  });
}
