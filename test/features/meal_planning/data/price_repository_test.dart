import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/data/price_repository.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

PriceSnapshot _snapshot({
  required String item,
  required double? price,
  required DateTime timestamp,
  PriceSource source = PriceSource.manual,
}) =>
    PriceSnapshot(
      id: 'ignored',
      itemName: item,
      price: price,
      currency: 'USD',
      unit: 'each',
      quantity: 1,
      source: source,
      timestamp: timestamp,
    );

void main() {
  test('latestForItem returns null when no snapshot exists', () async {
    final repository = PriceRepository(firestore: FakeFirebaseFirestore());
    expect(await repository.latestForItem('u', 'Eggs'), isNull);
  });

  test('record persists a snapshot with a generated id', () async {
    final repository = PriceRepository(firestore: FakeFirebaseFirestore());
    final recorded = await repository.record(
      'u',
      _snapshot(item: 'Eggs', price: 4.25, timestamp: DateTime(2026, 1, 1)),
    );

    expect(recorded.id, isNotEmpty);
    final latest = await repository.latestForItem('u', 'Eggs');
    expect(latest!.price, 4.25);
  });

  test('latestForItem returns the most recent snapshot by timestamp', () async {
    final repository = PriceRepository(firestore: FakeFirebaseFirestore());
    await repository.record('u', _snapshot(item: 'Eggs', price: 3.0, timestamp: DateTime(2026, 1, 1)));
    await repository.record('u', _snapshot(item: 'Eggs', price: 4.5, timestamp: DateTime(2026, 6, 1)));

    final latest = await repository.latestForItem('u', 'Eggs');
    expect(latest!.price, 4.5);
  });

  test('an unavailable snapshot is stored with a null price, never coerced to 0', () async {
    final repository = PriceRepository(firestore: FakeFirebaseFirestore());
    await repository.record(
      'u',
      _snapshot(item: 'Saffron', price: null, timestamp: DateTime(2026, 1, 1), source: PriceSource.unavailable),
    );

    final latest = await repository.latestForItem('u', 'Saffron');
    expect(latest!.price, isNull);
    expect(latest.source, PriceSource.unavailable);
  });

  test('listAll returns snapshots across all items, most recent first', () async {
    final repository = PriceRepository(firestore: FakeFirebaseFirestore());
    await repository.record('u', _snapshot(item: 'Eggs', price: 3.0, timestamp: DateTime(2026, 1, 1)));
    await repository.record('u', _snapshot(item: 'Milk', price: 2.0, timestamp: DateTime(2026, 6, 1)));

    final all = await repository.listAll('u');
    expect(all, hasLength(2));
    expect(all.first.itemName, 'Milk');
  });
}
