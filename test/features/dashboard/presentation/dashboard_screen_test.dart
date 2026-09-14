import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/dashboard/presentation/dashboard_screen.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  Widget buildDashboard() {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: nutritionRepository,
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );

    return MaterialApp(
      home: DashboardScreen(
        uid: 'u1',
        nutritionRepository: nutritionRepository,
        adherenceRepository: adherenceRepository,
      ),
    );
  }

  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard exposes body composition and goals navigation', (tester) async {
    await pumpTallSurface(tester, buildDashboard());

    expect(find.text('Body composition'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });

  testWidgets('dashboard has a settings entry point in the app bar', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final nutritionRepository = NutritionRepository(firestore: firestore);
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: nutritionRepository,
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => DashboardScreen(
            uid: 'u1',
            nutritionRepository: nutritionRepository,
            adherenceRepository: adherenceRepository,
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const Scaffold(body: Text('Settings screen')),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settingsButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Settings screen'), findsOneWidget);
  });

  testWidgets('shows a placeholder instead of a fake zero when no calorie goal is set', (tester) async {
    await pumpTallSurface(tester, buildDashboard());

    expect(find.text('Set a calorie goal'), findsOneWidget);
  });
}
