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

  test('ProgressRing clamps progress to 0.0-1.0', () {
    const ring = ProgressRing(progress: 1.5, color: AppColors.accentGreen);
    expect(ring.progress.clamp(0.0, 1.0), 1.0);
  });
}
