import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/presentation/exercise_library_screen.dart';

void main() {
  testWidgets('ExerciseLibraryScreen shows exercises from the stream and updates live', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseLibraryScreen(uid: 'uid-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);

    // Filter down first so the new item (added last, and thus off the
    // bottom of the unfiltered list) is within the built/visible range.
    await tester.enterText(find.byType(TextField), 'Nordic');
    await tester.pumpAndSettle();
    expect(find.text('Nordic Curl'), findsNothing);

    // Write directly to the repository (as if from another device/flow)
    // without rebuilding the widget tree, then pump to let the existing
    // `watchAll` stream subscription deliver the update.
    await repository.addCustom('uid-1', 'Nordic Curl');
    await tester.pumpAndSettle();

    expect(find.text('Nordic Curl'), findsOneWidget);
  });

  testWidgets('ExerciseLibraryScreen filters the live-streamed list by search text', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseLibraryScreen(uid: 'uid-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Squat'), findsNothing);
  });

  testWidgets('ExerciseLibraryScreen offers to add a custom exercise when search has no match', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    await tester.pumpWidget(
      MaterialApp(
        home: ExerciseLibraryScreen(uid: 'uid-1', repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Sled Push');
    await tester.pumpAndSettle();

    expect(find.text('Add "Sled Push"'), findsOneWidget);

    await tester.tap(find.text('Add "Sled Push"'));
    await tester.pumpAndSettle();

    // The search field itself still shows "Sled Push" as typed text, so
    // scope the assertion to the result list rendering it as a ListTile.
    expect(find.widgetWithText(ListTile, 'Sled Push'), findsOneWidget);
  });
}
