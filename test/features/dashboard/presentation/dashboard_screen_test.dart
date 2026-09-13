import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_tracker/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('dashboard exposes body and goals navigation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    expect(find.text('Body composition'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
  });

  testWidgets('dashboard has a settings entry point in the app bar', (tester) async {
    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
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
}
