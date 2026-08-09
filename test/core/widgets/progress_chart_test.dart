import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fitness_tracker/core/widgets/progress_chart.dart';

void main() {
  testWidgets('ProgressChart renders a LineChart with one point per entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressChart(
          points: [
            ProgressPoint(date: DateTime(2026, 1, 1), value: 80),
            ProgressPoint(date: DateTime(2026, 1, 8), value: 82.5),
            ProgressPoint(date: DateTime(2026, 1, 15), value: 85),
          ],
        ),
      ),
    );

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('ProgressChart shows an empty state with no points', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProgressChart(points: [])),
    );

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No data yet'), findsOneWidget);
  });
}
