import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/goals/data/goal_repository.dart';
import 'package:fitness_tracker/features/goals/domain/fitness_goal.dart';
import 'package:fitness_tracker/features/goals/presentation/goals_screen.dart';

void main() {
  testWidgets('goals screen saves a physique goal', (tester) async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: GoalsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('goalNameField')), 'Reduce waist');
    await tester.tap(find.text('Save goal'));
    await tester.pumpAndSettle();

    expect((await repository.listGoals('u')).single.name, 'Reduce waist');
  });

  testWidgets('choosing primary category shows the primary-replacement notice', (tester) async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await tester.pumpWidget(
      MaterialApp(home: GoalsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goalCategoryDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('primary').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Making this primary goal active archives the previous primary goal.'),
      findsOneWidget,
    );
  });

  testWidgets('lists existing goals with category/status indicators', (tester) async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());
    await repository.createGoal(
      'u',
      FitnessGoal(
        id: 'g1',
        name: 'Bench 100kg',
        category: GoalCategory.performance,
        status: GoalStatus.active,
        priority: 1,
        createdAt: DateTime(2026, 8, 1),
        updatedAt: DateTime(2026, 8, 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: GoalsScreen(uid: 'u', repository: repository, onChanged: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench 100kg'), findsOneWidget);
    expect(find.textContaining('performance'), findsOneWidget);
    expect(find.textContaining('active'), findsWidgets);
  });
}
