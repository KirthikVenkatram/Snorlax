import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('dashboard exposes body and goals navigation', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    expect(find.text('Body composition'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
  });
}
