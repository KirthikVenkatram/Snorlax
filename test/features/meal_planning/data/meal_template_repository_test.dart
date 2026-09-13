import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/data/meal_template_repository.dart';
import 'package:fitness_tracker/features/meal_planning/domain/meal_template.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

MealTemplate _template({String id = '', String name = 'Chicken and rice', double? cost = 3.5}) => MealTemplate(
      id: id,
      name: name,
      servings: 1,
      caloriesPerServing: 550,
      proteinGPerServing: 45,
      carbsGPerServing: 60,
      fatGPerServing: 12,
      costPerServing: cost,
      currency: 'USD',
      costSource: cost == null ? PriceSource.unavailable : PriceSource.manual,
      costTimestamp: DateTime(2026, 9, 13),
    );

void main() {
  test('list returns an empty list for a new user', () async {
    final repository = MealTemplateRepository(firestore: FakeFirebaseFirestore());
    expect(await repository.list('u'), isEmpty);
  });

  test('create then get round-trips a template', () async {
    final repository = MealTemplateRepository(firestore: FakeFirebaseFirestore());
    final created = await repository.create('u', _template());

    final fetched = await repository.get('u', created.id);
    expect(fetched, isNotNull);
    expect(fetched!.name, 'Chicken and rice');
    expect(fetched.costPerServing, 3.5);
  });

  test('an unpriced template round-trips with a null cost, not 0', () async {
    final repository = MealTemplateRepository(firestore: FakeFirebaseFirestore());
    final created = await repository.create('u', _template(name: 'Mystery smoothie', cost: null));

    final fetched = await repository.get('u', created.id);
    expect(fetched!.costPerServing, isNull);
    expect(fetched.costSource, PriceSource.unavailable);
  });

  test('update overwrites an existing template', () async {
    final repository = MealTemplateRepository(firestore: FakeFirebaseFirestore());
    final created = await repository.create('u', _template());

    await repository.update(
      'u',
      MealTemplate(
        id: created.id,
        name: 'Chicken and rice (updated)',
        servings: 1,
        caloriesPerServing: 560,
        proteinGPerServing: 46,
        carbsGPerServing: 60,
        fatGPerServing: 12,
        costPerServing: 4.0,
        currency: 'USD',
        costSource: PriceSource.manual,
        costTimestamp: DateTime(2026, 9, 14),
      ),
    );

    final fetched = await repository.get('u', created.id);
    expect(fetched!.name, 'Chicken and rice (updated)');
    expect(fetched.costPerServing, 4.0);
  });

  test('delete removes a template', () async {
    final repository = MealTemplateRepository(firestore: FakeFirebaseFirestore());
    final created = await repository.create('u', _template());

    await repository.delete('u', created.id);

    expect(await repository.get('u', created.id), isNull);
  });
}
