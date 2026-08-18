import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/nutrition/presentation/nutrition_goals_screen.dart';

void main() {
  testWidgets('saving valid goals writes them and calls onSaved', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = NutritionRepository(firestore: firestore);

    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: NutritionGoalsScreen(
          uid: 'uid-1',
          nutritionRepository: repository,
          onSaved: () => saved = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('caloriesField')), '2000');
    await tester.enterText(find.byKey(const Key('proteinField')), '150');
    await tester.enterText(find.byKey(const Key('carbsField')), '200');
    await tester.enterText(find.byKey(const Key('fatField')), '60');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save goals'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    final goals = await repository.getGoals('uid-1');
    expect(goals!.dailyCalories, 2000);
    expect(goals.proteinG, 150);
  });
}
