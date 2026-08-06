import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/gradient_button.dart';

void main() {
  testWidgets('GradientButton shows its label and calls onPressed when tapped', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientButton(
            label: 'Log Workout',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Log Workout'), findsOneWidget);

    await tester.tap(find.byType(GradientButton));
    expect(tapped, isTrue);
  });
}
