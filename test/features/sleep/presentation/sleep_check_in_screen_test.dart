import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/sleep/data/sleep_repository.dart';
import 'package:fitness_tracker/features/sleep/presentation/sleep_check_in_screen.dart';

void main() {
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  testWidgets('saving a check-in persists it via the repository', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = SleepRepository(firestore: firestore);

    await pumpTallSurface(
      tester,
      MaterialApp(home: SleepCheckInScreen(uid: 'u', repository: repository)),
    );

    expect(find.text('Last night'), findsOneWidget);

    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final entry = await repository.getByDate('u', DateTime(today.year, today.month, today.day));
    expect(entry, isNotNull);
  });

  testWidgets('entering sleep stages persists a stages breakdown', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = SleepRepository(firestore: firestore);

    await pumpTallSurface(
      tester,
      MaterialApp(home: SleepCheckInScreen(uid: 'u', repository: repository)),
    );

    await tester.tap(find.text('Add sleep stages'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('awakeStageField')), '20');
    await tester.enterText(find.byKey(const Key('remStageField')), '80');
    await tester.enterText(find.byKey(const Key('deepStageField')), '60');
    await tester.enterText(find.byKey(const Key('lightStageField')), '250');

    await tester.ensureVisible(find.text('Save check-in'));
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final entry = await repository.getByDate('u', DateTime(today.year, today.month, today.day));
    expect(entry!.stages, isNotNull);
    expect(entry.stages!.rem, 80);
  });
}
