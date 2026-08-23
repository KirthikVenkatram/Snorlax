import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/goals/domain/fitness_goal.dart';

void main() {
  test('round-trips optional target values', () {
    final goal = FitnessGoal(
      id: 'g1',
      name: 'Reduce waist',
      category: GoalCategory.physique,
      status: GoalStatus.active,
      priority: 2,
      targetValue: 80,
      unit: 'cm',
      baselineValue: 92,
      currentValue: 90,
      targetDate: DateTime(2026, 12, 1),
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );

    final restored = FitnessGoal.fromJson(goal.id, goal.toJson());

    expect(restored.targetValue, 80);
    expect(restored.unit, 'cm');
    expect(restored.targetDate, DateTime(2026, 12, 1));
  });
}
