// test/features/workouts/presentation/exercise_picker_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';
import 'package:fitness_tracker/features/workouts/domain/exercise.dart';
import 'package:fitness_tracker/features/workouts/presentation/exercise_picker.dart';

void main() {
  testWidgets('ExercisePicker shows search results and calls onSelected on tap', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    Exercise? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: ExercisePicker(
          uid: 'uid-1',
          repository: repository,
          onSelected: (e) => selected = e,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'bench');
    await tester.pumpAndSettle();

    expect(find.textContaining('Bench Press'), findsWidgets);

    await tester.tap(find.text('Bench Press').first);
    await tester.pumpAndSettle();

    expect(selected?.name, 'Bench Press');
  });

  testWidgets('ExercisePicker offers to add a custom exercise when search has no match', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = ExerciseLibraryRepository(firestore: firestore);
    await repository.seedDefaultsIfEmpty('uid-1');

    Exercise? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: ExercisePicker(
          uid: 'uid-1',
          repository: repository,
          onSelected: (e) => selected = e,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Nordic Curl');
    await tester.pumpAndSettle();

    expect(find.textContaining('Add "Nordic Curl"'), findsOneWidget);

    await tester.tap(find.textContaining('Add "Nordic Curl"'));
    await tester.pumpAndSettle();

    expect(selected?.name, 'Nordic Curl');
    expect(selected?.isCustom, isTrue);
  });
}
