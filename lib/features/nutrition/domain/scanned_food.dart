/// A product looked up from Open Food Facts by barcode — see
/// [OpenFoodFactsClient.lookupBarcode].
class ScannedFood {
  const ScannedFood({
    required this.name,
    required this.barcode,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.servingLabel,
  });

  final String name;
  final String barcode;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  /// e.g. "per 100g serving" or the product's own serving_size string, if
  /// Open Food Facts provided one. Purely informational.
  final String? servingLabel;
}
