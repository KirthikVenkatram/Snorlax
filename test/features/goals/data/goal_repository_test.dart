import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/goals/data/goal_repository.dart';
import 'package:fitness_tracker/features/goals/domain/fitness_goal.dart';

FitnessGoal _goal(String id, GoalCategory category, {GoalStatus status = GoalStatus.active}) => FitnessGoal(
      id: id,
      name: id,
      category: category,
      status: status,
      priority: 1,
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );

void main() {
  test('creating a primary goal archives the earlier active primary goal', () async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await repository.createGoal('u', _goal('fat-loss', GoalCategory.primary));
    await repository.createGoal('u', _goal('recomp', GoalCategory.primary));

    final goals = await repository.listGoals('u');
    expect(
      goals.where((goal) => goal.category == GoalCategory.primary && goal.status == GoalStatus.active),
      hasLength(1),
    );
    expect(goals.singleWhere((goal) => goal.id == 'fat-loss').status, GoalStatus.archived);
  });

  test('non-primary goals may remain active together', () async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await repository.createGoal('u', _goal('waist', GoalCategory.physique));
    await repository.createGoal('u', _goal('pushups', GoalCategory.performance));

    expect((await repository.listGoals('u')).where((goal) => goal.status == GoalStatus.active), hasLength(2));
  });

  test('reactivating a paused primary goal via updateGoal archives the other active primary goal', () async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await repository.createGoal('u', _goal('fat-loss', GoalCategory.primary));
    await repository.createGoal(
      'u',
      _goal('recomp', GoalCategory.primary, status: GoalStatus.paused),
    );

    // 'fat-loss' is the sole active primary goal at this point; reactivating
    // 'recomp' through updateGoal (not createGoal) must still uphold the
    // one-active-primary invariant.
    await repository.updateGoal(
      'u',
      _goal('recomp', GoalCategory.primary),
    );

    final goals = await repository.listGoals('u');
    expect(
      goals.where((goal) => goal.category == GoalCategory.primary && goal.status == GoalStatus.active),
      hasLength(1),
    );
    expect(goals.singleWhere((goal) => goal.id == 'fat-loss').status, GoalStatus.archived);
    expect(goals.singleWhere((goal) => goal.id == 'recomp').status, GoalStatus.active);
  });

  test('updateGoal on a non-primary goal does not touch other active goals', () async {
    final repository = GoalRepository(firestore: FakeFirebaseFirestore());

    await repository.createGoal('u', _goal('waist', GoalCategory.physique));
    await repository.createGoal('u', _goal('pushups', GoalCategory.performance));

    await repository.updateGoal('u', _goal('waist', GoalCategory.physique, status: GoalStatus.completed));

    final goals = await repository.listGoals('u');
    expect(goals.singleWhere((goal) => goal.id == 'waist').status, GoalStatus.completed);
    expect(goals.singleWhere((goal) => goal.id == 'pushups').status, GoalStatus.active);
  });
}
