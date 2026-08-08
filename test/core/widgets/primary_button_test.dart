import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton shows its label and calls onPressed when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Log Workout',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Log Workout'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton with null onPressed does not call anything when tapped', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Log Workout',
            onPressed: null,
          ),
        ),
      ),
    );

    expect(find.text('Log Workout'), findsOneWidget);

    // Should not throw when tapped while disabled.
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
  });
}
