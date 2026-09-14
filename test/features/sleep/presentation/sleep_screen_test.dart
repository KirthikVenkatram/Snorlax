import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/sleep/data/sleep_repository.dart';
import 'package:fitness_tracker/features/sleep/domain/sleep_entry.dart';
import 'package:fitness_tracker/features/sleep/presentation/sleep_screen.dart';

void main() {
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  testWidgets('shows an empty state with no check-in yet', (tester) async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());

    await pumpTallSurface(
      tester,
      MaterialApp(home: SleepScreen(uid: 'u', repository: repository)),
    );

    expect(find.text('No check-in yet. Log last night\'s sleep to see it here.'), findsOneWidget);
    expect(find.byKey(const Key('sleepStagesCard')), findsNothing);
  });

  testWidgets('renders duration and score without a stages card when no stage data was entered',
      (tester) async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());
    await repository.recordCheckIn(
      'u',
      day,
      bedtime: DateTime(day.year, day.month, day.day - 1, 23, 48),
      wakeTime: DateTime(day.year, day.month, day.day, 8, 22),
      awakeMinutes: 34,
      score: 82,
    );

    await pumpTallSurface(
      tester,
      MaterialApp(home: SleepScreen(uid: 'u', repository: repository)),
    );

    expect(find.byKey(const Key('sleepDurationText')), findsOneWidget);
    expect(find.byKey(const Key('scoreTile')), findsOneWidget);
    expect(find.byKey(const Key('sleepStagesCard')), findsNothing);
    expect(find.byKey(const Key('restingHrTile')), findsNothing);
    expect(find.byKey(const Key('hrvTile')), findsNothing);
  });

  testWidgets('renders the stages card only when stage data was entered', (tester) async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());
    await repository.recordCheckIn(
      'u',
      day,
      bedtime: DateTime(day.year, day.month, day.day - 1, 23, 48),
      wakeTime: DateTime(day.year, day.month, day.day, 8, 22),
      awakeMinutes: 34,
      score: 82,
      restingHeartRate: 62,
      hrv: 58.0,
      stages: const SleepStageMinutes(awake: 34, rem: 82, deep: 64, light: 252),
    );

    await pumpTallSurface(
      tester,
      MaterialApp(home: SleepScreen(uid: 'u', repository: repository)),
    );

    expect(find.byKey(const Key('sleepStagesCard')), findsOneWidget);
    expect(find.byKey(const Key('restingHrTile')), findsOneWidget);
    expect(find.byKey(const Key('hrvTile')), findsOneWidget);
  });
}
