/// Domain type for a single price observation, persisted at
/// `users/{uid}/priceSnapshots/{snapshotId}`.
///
/// Prices are never hardcoded anywhere in this feature — every price shown
/// to the user traces back to one of these snapshots, tagged with where it
/// came from and when, so the UI can always label a price as manual,
/// estimated, or live rather than silently showing a bare number. See
/// `price_provider.dart` for how snapshots get created.
library;

/// How a [PriceSnapshot]'s value was obtained. `unavailable` is a valid,
/// first-class state (not an error) — a live provider that couldn't fetch a
/// price returns a snapshot with this source type and a null [PriceSnapshot.price]
/// rather than a fabricated 0 or a silently blank field.
enum PriceSource { manual, live, estimated, unavailable }

class PriceSnapshot {
  const PriceSnapshot({
    required this.id,
    required this.itemName,
    required this.price,
    required this.currency,
    required this.unit,
    required this.quantity,
    required this.source,
    required this.timestamp,
  }) : assert(quantity > 0, 'quantity must be positive');

  final String id;
  final String itemName;

  /// Null only when [source] is [PriceSource.unavailable] — callers must
  /// render this as "price unavailable", never as 0 or a blank field.
  final double? price;
  final String currency;

  /// Unit the [price] is quoted for, e.g. 'kg', 'each', 'lb'.
  final String unit;

  /// Quantity of [unit] the [price] covers, e.g. 1.0 for "$3 per kg".
  final double quantity;
  final PriceSource source;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'itemName': itemName,
        'price': price,
        'currency': currency,
        'unit': unit,
        'quantity': quantity,
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PriceSnapshot.fromJson(String id, Map<String, dynamic> json) => PriceSnapshot(
        id: id,
        itemName: json['itemName'] as String? ?? '',
        price: (json['price'] as num?)?.toDouble(),
        currency: json['currency'] as String? ?? 'USD',
        unit: json['unit'] as String? ?? 'each',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        source: PriceSource.values.byName((json['source'] as String?) ?? 'manual'),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
