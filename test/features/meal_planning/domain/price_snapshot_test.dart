import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

void main() {
  group('PriceSnapshot JSON round-trip', () {
    test('round-trips a manual snapshot', () {
      final snapshot = PriceSnapshot(
        id: 'p1',
        itemName: 'Chicken breast',
        price: 8.5,
        currency: 'USD',
        unit: 'kg',
        quantity: 1,
        source: PriceSource.manual,
        timestamp: DateTime(2026, 9, 13, 10, 30),
      );

      final decoded = PriceSnapshot.fromJson('p1', snapshot.toJson());

      expect(decoded.itemName, 'Chicken breast');
      expect(decoded.price, 8.5);
      expect(decoded.source, PriceSource.manual);
      expect(decoded.timestamp, DateTime(2026, 9, 13, 10, 30));
    });

    test('an unavailable snapshot has a null price, never 0', () {
      final snapshot = PriceSnapshot(
        id: 'p2',
        itemName: 'Saffron',
        price: null,
        currency: 'USD',
        unit: 'g',
        quantity: 1,
        source: PriceSource.unavailable,
        timestamp: DateTime(2026, 9, 13),
      );

      final decoded = PriceSnapshot.fromJson('p2', snapshot.toJson());

      expect(decoded.price, isNull);
      expect(decoded.source, PriceSource.unavailable);
    });

    test('rejects non-positive quantity', () {
      expect(
        () => PriceSnapshot(
          id: 'p3',
          itemName: 'x',
          price: 1,
          currency: 'USD',
          unit: 'each',
          quantity: 0,
          source: PriceSource.manual,
          timestamp: DateTime(2026, 1, 1),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
