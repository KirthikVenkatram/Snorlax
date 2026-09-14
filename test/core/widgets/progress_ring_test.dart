import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/widgets/progress_ring.dart';
import 'package:fitness_tracker/core/theme/app_colors.dart';

void main() {
  testWidgets('ProgressRing renders its center widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProgressRing(
          progress: 0.5,
          color: AppColors.accentGreen,
          center: const Text('50%'),
        ),
      ),
    );

    expect(find.text('50%'), findsOneWidget);
  });

  testWidgets('ProgressRing clamps out-of-range progress before rendering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ProgressRing(progress: 1.5, color: AppColors.accentGreen),
      ),
    );
    // The ring animates toward its target value rather than jumping
    // instantly, so let that animation finish before asserting.
    await tester.pumpAndSettle();

    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );

    expect(indicator.value, 1.0);
  });
}
