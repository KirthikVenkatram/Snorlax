import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/meal_planning/data/price_provider.dart';
import 'package:fitness_tracker/features/meal_planning/domain/price_snapshot.dart';

void main() {
  group('ManualPriceProvider', () {
    test('returns the user-supplied price labelled as manual', () async {
      final provider = ManualPriceProvider(manualPrice: 4.25);

      final quote = await provider.getPrice(itemName: 'Eggs', unit: 'dozen', quantity: 1, currency: 'USD');

      expect(quote.price, 4.25);
      expect(quote.source, PriceSource.manual);
      expect(quote.itemName, 'Eggs');
    });

    test('toSnapshot carries the quote fields through with the given id', () async {
      final provider = ManualPriceProvider(manualPrice: 2.0);
      final quote = await provider.getPrice(itemName: 'Milk', unit: 'L', quantity: 1, currency: 'USD');
      final snapshot = quote.toSnapshot('snap1');

      expect(snapshot.id, 'snap1');
      expect(snapshot.price, 2.0);
      expect(snapshot.source, PriceSource.manual);
    });
  });

  group('UnavailableLivePriceProvider', () {
    test('always returns a clearly-flagged unavailable quote, never a fabricated price', () async {
      final provider = UnavailableLivePriceProvider();

      final quote = await provider.getPrice(itemName: 'Saffron', unit: 'g', quantity: 1, currency: 'USD');

      expect(quote.price, isNull);
      expect(quote.source, PriceSource.unavailable);
    });
  });
}
