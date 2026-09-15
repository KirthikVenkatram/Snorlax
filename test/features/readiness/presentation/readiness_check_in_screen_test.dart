import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/readiness/presentation/readiness_check_in_screen.dart';

/// The check-in form is long (six steppers + toggle + button); give the
/// test surface enough height that everything is on-screen without
/// scrolling in every test.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('readiness screen renders the check-in form with no entry yet', (tester) async {
    _useTallSurface(tester);
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: ReadinessCheckInScreen(uid: 'u', repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily check-in'), findsOneWidget);
    expect(find.text('Sleep hours'), findsOneWidget);
    expect(find.byKey(const Key('painOrInjurySwitch')), findsOneWidget);
    // No result card yet — no check-in saved today.
    expect(find.byKey(const Key('readinessLevelLabel')), findsNothing);
  });

  testWidgets('adjusting a stepper and saving shows the result card with the verbatim disclaimer',
      (tester) async {
    _useTallSurface(tester);
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: ReadinessCheckInScreen(uid: 'u', repository: repository)),
    );
    await tester.pumpAndSettle();

    // Bump sleep hours up by one step via the "+" button.
    await tester.tap(find.byKey(const Key('sleepHoursPlus')));
    await tester.pump();
    expect(find.text('7.5'), findsOneWidget);

    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('readinessLevelDot')), findsOneWidget);
    expect(find.byKey(const Key('readinessLevelLabel')), findsOneWidget);
    expect(
      find.text(
        'This is not medical advice or a diagnosis — it is a simple, '
        'self-reported wellness heuristic to help you decide how hard '
        'to train today.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('pain or injury toggle forces a red result', (tester) async {
    _useTallSurface(tester);
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: ReadinessCheckInScreen(uid: 'u', repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('painOrInjurySwitch')));
    await tester.pump();
    await tester.tap(find.text('Save check-in'));
    await tester.pumpAndSettle();

    expect(find.text('Red — recovery / rest'), findsOneWidget);
  });
}
