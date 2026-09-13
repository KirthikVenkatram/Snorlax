import '../domain/price_snapshot.dart';

/// The result of asking a [PriceProvider] for an item's price. Deliberately
/// distinct from [PriceSnapshot] — a quote hasn't been persisted yet; a
/// caller decides whether/where to store it (typically via
/// `price_repository.dart`).
class PriceQuoteResult {
  const PriceQuoteResult({
    required this.itemName,
    required this.price,
    required this.currency,
    required this.unit,
    required this.quantity,
    required this.source,
    required this.timestamp,
  });

  final String itemName;

  /// Null when [source] is [PriceSource.unavailable] — callers must render
  /// this as "price unavailable, source: <label>", never as 0 or blank.
  final double? price;
  final String currency;
  final String unit;
  final double quantity;
  final PriceSource source;
  final DateTime timestamp;

  PriceSnapshot toSnapshot(String id) => PriceSnapshot(
        id: id,
        itemName: itemName,
        price: price,
        currency: currency,
        unit: unit,
        quantity: quantity,
        source: source,
        timestamp: timestamp,
      );
}

/// Abstraction over "how do we find out what an item costs". Prices are
/// never hardcoded in this codebase — every implementation of this
/// interface must either ask the user (manual) or a real external source
/// (live), and must return a clearly-labelled [PriceQuoteResult] even when
/// no price could be obtained.
abstract class PriceProvider {
  Future<PriceQuoteResult> getPrice({
    required String itemName,
    required String unit,
    required double quantity,
    required String currency,
  });
}

/// The only price path that actually ships working in Phase 8: the user
/// types in a price they observed, and it is recorded as [PriceSource.manual]
/// with the current timestamp. This never fabricates a number — the price
/// must be supplied by the caller (typically from a form field).
class ManualPriceProvider implements PriceProvider {
  ManualPriceProvider({required this.manualPrice});

  /// The user-entered price for this quote. Required — there is no
  /// "default"/hardcoded price to fall back to.
  final double manualPrice;

  @override
  Future<PriceQuoteResult> getPrice({
    required String itemName,
    required String unit,
    required double quantity,
    required String currency,
  }) async {
    return PriceQuoteResult(
      itemName: itemName,
      price: manualPrice,
      currency: currency,
      unit: unit,
      quantity: quantity,
      source: PriceSource.manual,
      timestamp: DateTime.now(),
    );
  }
}

/// Interface for a real live-price integration (e.g. Blinkit, Zepto, a
/// local store's API). No such integration exists yet — this phase's spec
/// explicitly scopes "manual first, then live providers" — so every
/// implementation of this must clearly return an "unavailable" quote rather
/// than pretend to have live data. See docs/superpowers/ISSUES.md, "Phase 8".
abstract class LivePriceProvider implements PriceProvider {}

/// A no-op [LivePriceProvider]: always reports the price as unavailable
/// rather than hardcoding a number or blocking on an unimplemented
/// integration. This is the only [LivePriceProvider] this phase ships;
/// swapping in a real one later is a drop-in replacement of this class,
/// not a change to any caller.
class UnavailableLivePriceProvider implements LivePriceProvider {
  @override
  Future<PriceQuoteResult> getPrice({
    required String itemName,
    required String unit,
    required double quantity,
    required String currency,
  }) async {
    return PriceQuoteResult(
      itemName: itemName,
      price: null,
      currency: currency,
      unit: unit,
      quantity: quantity,
      source: PriceSource.unavailable,
      timestamp: DateTime.now(),
    );
  }
}
