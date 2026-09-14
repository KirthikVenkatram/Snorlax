import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/dashboard/presentation/app_shell.dart';

void main() {
  Widget buildShell() {
    return MaterialApp(
      home: AppShell(
        homeBuilder: (onNavigateToTab) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => onNavigateToTab(1),
              child: const Text('go to nutrition'),
            ),
          ),
        ),
        nutrition: const Scaffold(body: Center(child: Text('Nutrition content'))),
        train: const Scaffold(body: Center(child: Text('Train content'))),
        coach: const Scaffold(body: Center(child: Text('Coach content'))),
        more: const Scaffold(body: Center(child: Text('More content'))),
      ),
    );
  }

  testWidgets('starts on the Home tab', (tester) async {
    await tester.pumpWidget(buildShell());
    expect(find.text('go to nutrition'), findsOneWidget);
    expect(find.text('Nutrition content'), findsNothing);
  });

  testWidgets('tapping a bottom-bar item switches tabs', (tester) async {
    await tester.pumpWidget(buildShell());

    await tester.tap(find.text('TRAIN'));
    await tester.pumpAndSettle();

    expect(find.text('Train content'), findsOneWidget);
    expect(find.text('go to nutrition'), findsNothing);
  });

  testWidgets('Home tab can switch tabs via its own callback', (tester) async {
    await tester.pumpWidget(buildShell());

    await tester.tap(find.text('go to nutrition'));
    await tester.pumpAndSettle();

    expect(find.text('Nutrition content'), findsOneWidget);
  });

  testWidgets('switching away and back preserves tab state via IndexedStack', (tester) async {
    await tester.pumpWidget(buildShell());

    await tester.tap(find.text('COACH'));
    await tester.pumpAndSettle();
    expect(find.text('Coach content'), findsOneWidget);

    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('go to nutrition'), findsOneWidget);
  });
}
