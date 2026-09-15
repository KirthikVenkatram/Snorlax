import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fitness_tracker/core/calculations/meal_plan_calculator.dart';
import 'package:fitness_tracker/features/coach/data/coach_service.dart';
import 'package:fitness_tracker/features/meal_planning/data/budget_repository.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_plan_repository.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_template_repository.dart';
import 'package:fitness_tracker/features/meal_planning/data/price_repository.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_plan.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_template.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';
import 'package:fitness_tracker/features/meal_planning/presentation/meal_planning_screen.dart';

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class MockHttpsCallable extends Mock implements HttpsCallable {}

class MockHttpsCallableResult<T> extends Mock implements HttpsCallableResult<T> {}

void main() {
  // The screen's ListView grew a "Prices" section, which pushes later
  // sections (meal plans, "Ask coach") past what a default-sized test
  // surface builds/renders lazily inside the Sliver — use a tall surface so
  // every section is actually built, matching the convention
  // `dashboard_screen_test.dart` uses for the same reason.
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

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
            priceRepository: PriceRepository(firestore: firestore),
            coachService: coachService,
          ),
        ),
        GoRoute(
          path: '/coach',
          builder: (context, state) => const Scaffold(body: Text('Coach screen')),
        ),
      ],
    );

    await pumpTallSurface(tester, MaterialApp.router(routerConfig: router));

    expect(find.text('Ask coach'), findsOneWidget);

    // The button may be below the fold in the test viewport's ListView.
    await tester.ensureVisible(find.text('Ask coach'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ask coach'));
    await tester.pumpAndSettle();

    verify(() => callable.call<Map<String, dynamic>>()).called(1);
    expect(find.text('Coach screen'), findsOneWidget);
  });

  // Regression tests for the "wire up dead Phase 8 code" pass: prior to this
  // fix, PriceRepository/ManualPriceProvider had no caller anywhere in the
  // Flutter app, and MealTemplateRepository.update/.delete and
  // MealPlanRepository.delete were implemented+tested but never called from
  // this screen. See docs/superpowers/ISSUES.md, "Post-audit wiring".

  Widget buildApp(MealPlanningScreen screen) {
    return MaterialApp(home: screen);
  }

  MealPlanningScreen buildScreen(FakeFirebaseFirestore firestore, CoachService coachService) {
    return MealPlanningScreen(
      uid: 'u',
      budgetRepository: BudgetRepository(firestore: firestore),
      templateRepository: MealTemplateRepository(firestore: firestore),
      planRepository: MealPlanRepository(firestore: firestore),
      priceRepository: PriceRepository(firestore: firestore),
      coachService: coachService,
    );
  }

  CoachService buildUnusedCoachService(FakeFirebaseFirestore firestore) {
    final functions = MockFirebaseFunctions();
    return CoachService(firestore: firestore, functions: functions);
  }

  testWidgets('recording a price snapshot persists it and shows in the list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final coachService = buildUnusedCoachService(firestore);

    await pumpTallSurface(tester, buildApp(buildScreen(firestore, coachService)));

    await tester.ensureVisible(find.text('Record a price'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record a price'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Chicken breast');
    await tester.enterText(fields.at(1), '12.50');
    await tester.enterText(fields.at(2), 'kg');
    await tester.enterText(fields.at(3), '1');
    await tester.enterText(fields.at(4), 'USD');

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Persisted in the repository directly.
    final stored = await PriceRepository(firestore: firestore).listAll('u');
    expect(stored, hasLength(1));
    expect(stored.single.itemName, 'Chicken breast');
    expect(stored.single.price, 12.5);
    expect(stored.single.source, PriceSource.manual);

    // And shown in the on-screen list.
    expect(find.textContaining('Chicken breast'), findsOneWidget);
    expect(find.textContaining('12.50 USD'), findsOneWidget);
  });

  testWidgets('editing a template persists the change', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final coachService = buildUnusedCoachService(firestore);
    final templateRepository = MealTemplateRepository(firestore: firestore);
    await templateRepository.create(
      'u',
      MealTemplate(
        id: '',
        name: 'Chicken bowl',
        servings: 1,
        caloriesPerServing: 500,
        proteinGPerServing: 40,
        carbsGPerServing: 50,
        fatGPerServing: 10,
        costPerServing: 5,
        currency: 'USD',
        costSource: PriceSource.manual,
        costTimestamp: DateTime(2024, 1, 1),
      ),
    );

    await pumpTallSurface(tester, buildApp(buildScreen(firestore, coachService)));

    expect(find.textContaining('Chicken bowl'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Edit Chicken bowl'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Chicken bowl'));
    await tester.pumpAndSettle();

    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Chicken rice bowl');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = await templateRepository.list('u');
    expect(stored, hasLength(1));
    expect(stored.single.name, 'Chicken rice bowl');

    expect(find.textContaining('Chicken rice bowl'), findsOneWidget);
    expect(find.textContaining('Chicken bowl —'), findsNothing);
  });

  testWidgets('deleting a template removes it from the list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final coachService = buildUnusedCoachService(firestore);
    final templateRepository = MealTemplateRepository(firestore: firestore);
    await templateRepository.create(
      'u',
      MealTemplate(
        id: '',
        name: 'Chicken bowl',
        servings: 1,
        caloriesPerServing: 500,
        proteinGPerServing: 40,
        carbsGPerServing: 50,
        fatGPerServing: 10,
        costPerServing: 5,
        currency: 'USD',
        costSource: PriceSource.manual,
        costTimestamp: DateTime(2024, 1, 1),
      ),
    );

    await pumpTallSurface(tester, buildApp(buildScreen(firestore, coachService)));

    expect(find.textContaining('Chicken bowl'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Delete Chicken bowl'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete Chicken bowl'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final stored = await templateRepository.list('u');
    expect(stored, isEmpty);
    expect(find.textContaining('Chicken bowl'), findsNothing);
    expect(find.text('No templates yet.'), findsOneWidget);
  });

  testWidgets('deleting a meal plan removes it from the list', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final coachService = buildUnusedCoachService(firestore);
    final planRepository = MealPlanRepository(firestore: firestore);
    final template = MealTemplate(
      id: 't1',
      name: 'Chicken bowl',
      servings: 1,
      caloriesPerServing: 500,
      proteinGPerServing: 40,
      carbsGPerServing: 50,
      fatGPerServing: 10,
      costPerServing: 5,
      currency: 'USD',
      costSource: PriceSource.manual,
      costTimestamp: DateTime(2024, 1, 1),
    );
    await planRepository.createFromTemplates(
      uid: 'u',
      name: 'My plan',
      periodType: MealPlanPeriodType.daily,
      lines: [MealPlanLineInput(template: template, servings: 2)],
      currency: 'USD',
    );

    await pumpTallSurface(tester, buildApp(buildScreen(firestore, coachService)));

    expect(find.text('My plan'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Delete My plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete My plan'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final stored = await planRepository.list('u');
    expect(stored, isEmpty);
    expect(find.text('My plan'), findsNothing);
    expect(find.text('No meal plans yet.'), findsOneWidget);
  });
}
