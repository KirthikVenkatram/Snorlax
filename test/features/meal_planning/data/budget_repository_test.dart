import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/data/budget_repository.dart';
import 'package:fitness_tracker/features/meal_planning/domain/budget_settings.dart';

void main() {
  test('get returns null when no budget has been set yet', () async {
    final repository = BudgetRepository(firestore: FakeFirebaseFirestore());
    expect(await repository.get('u'), isNull);
  });

  test('save then get round-trips settings', () async {
    final repository = BudgetRepository(firestore: FakeFirebaseFirestore());
    const settings = BudgetSettings(currency: 'USD', dailyLimit: 20, weeklyLimit: 120);

    await repository.save('u', settings);
    final fetched = await repository.get('u');

    expect(fetched, isNotNull);
    expect(fetched!.dailyLimit, 20);
    expect(fetched.weeklyLimit, 120);
  });

  test('save overwrites the single current document', () async {
    final repository = BudgetRepository(firestore: FakeFirebaseFirestore());
    await repository.save('u', const BudgetSettings(currency: 'USD', dailyLimit: 10));
    await repository.save('u', const BudgetSettings(currency: 'USD', dailyLimit: 25));

    final fetched = await repository.get('u');
    expect(fetched!.dailyLimit, 25);
  });
}
