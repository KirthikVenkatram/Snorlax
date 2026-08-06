import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/glass_card.dart';

void main() {
  testWidgets('GlassCard renders its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GlassCard(child: Text('hello')),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });
}
