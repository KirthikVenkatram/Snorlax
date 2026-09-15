import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_tracker/features/workouts/presentation/session_complete_screen.dart';

void main() {
  Widget buildScreen() {
    final router = GoRouter(
      initialLocation: '/complete',
      routes: [
        GoRoute(
          path: '/complete',
          builder: (context, state) => const SessionCompleteScreen(
            sessionName: 'Push Day',
            exerciseCount: 2,
            elapsedSeconds: 605,
            setsCompleted: 6,
            volumeKg: 1240,
          ),
        ),
        GoRoute(
          path: '/nutrition',
          builder: (context, state) => const Scaffold(body: Text('Nutrition screen')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows the workout summary and real computed stats', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.textContaining('Push Day logged'), findsOneWidget);
    expect(find.text('10:05'), findsOneWidget); // 605s
    expect(find.text('6'), findsOneWidget);
    expect(find.text('1240 kg'), findsOneWidget);
  });

  testWidgets('"Log a meal" navigates to Nutrition', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log a meal'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrition screen'), findsOneWidget);
  });

  testWidgets('"Back to today" pops the screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SessionCompleteScreen(
                        sessionName: 'Push Day',
                        exerciseCount: 2,
                        elapsedSeconds: 605,
                        setsCompleted: 6,
                        volumeKg: 1240,
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();

    expect(find.text('SESSION COMPLETE'), findsNothing);
  });
}
