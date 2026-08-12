import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/exercise_library_repository.dart';

void main() {
  group('ExerciseLibraryRepository', () {
    test('seedDefaultsIfEmpty populates the curated list when empty', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      await repository.seedDefaultsIfEmpty('uid-1');

      final all = await repository.watchAll('uid-1').first;
      expect(all, isNotEmpty);
      expect(all.every((e) => !e.isCustom), isTrue);
    });

    test('seedDefaultsIfEmpty does nothing if exercises already exist', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      await repository.addCustom('uid-1', 'My Weird Exercise');
      await repository.seedDefaultsIfEmpty('uid-1');

      final all = await repository.watchAll('uid-1').first;
      expect(all.length, 1);
      expect(all.first.name, 'My Weird Exercise');
    });

    test('addCustom writes a custom exercise and search finds it by name', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);

      final added = await repository.addCustom('uid-1', 'Nordic Curl');

      expect(added.isCustom, isTrue);
      expect(added.name, 'Nordic Curl');

      final results = await repository.search('uid-1', 'nordic');
      expect(results.map((e) => e.name), contains('Nordic Curl'));
    });

    test('search is case-insensitive and matches substrings', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = ExerciseLibraryRepository(firestore: firestore);
      await repository.seedDefaultsIfEmpty('uid-1');

      final results = await repository.search('uid-1', 'bench');

      expect(results, isNotEmpty);
      expect(results.every((e) => e.name.toLowerCase().contains('bench')), isTrue);
    });
  });
}
