// test/features/nutrition/data/custom_food_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/nutrition/data/custom_food_repository.dart';

void main() {
  group('CustomFoodRepository', () {
    test('addCustom writes a custom food and search finds it by name', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);

      final added = await repository.addCustom(
        'uid-1',
        name: 'Amma\'s Sambar',
        caloriesPer100g: 80,
        proteinPer100g: 4,
        carbsPer100g: 12,
        fatPer100g: 2,
      );

      expect(added.name, 'Amma\'s Sambar');
      expect(added.caloriesPer100g, 80);

      final results = await repository.search('uid-1', 'sambar');
      expect(results.map((f) => f.name), contains('Amma\'s Sambar'));
    });

    test('search is case-insensitive and matches substrings', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);
      await repository.addCustom(
        'uid-1', name: 'Homemade Dosa', caloriesPer100g: 150,
        proteinPer100g: 3, carbsPer100g: 25, fatPer100g: 4);

      final results = await repository.search('uid-1', 'DOSA');

      expect(results, isNotEmpty);
      expect(results.every((f) => f.name.toLowerCase().contains('dosa')), isTrue);
    });

    test('search returns nothing for an unrelated query', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = CustomFoodRepository(firestore: firestore);
      await repository.addCustom(
        'uid-1', name: 'Homemade Dosa', caloriesPer100g: 150,
        proteinPer100g: 3, carbsPer100g: 25, fatPer100g: 4);

      final results = await repository.search('uid-1', 'pizza');

      expect(results, isEmpty);
    });
  });
}
