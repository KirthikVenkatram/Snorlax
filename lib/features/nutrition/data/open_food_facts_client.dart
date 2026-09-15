import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/scanned_food.dart';

/// Direct client-side lookup against the public, unauthenticated Open Food
/// Facts product API — no Cloud Function needed (see Slice A of
/// `docs/superpowers/plans/2026-09-15-glass-handoff-new-features.md`).
/// Field mapping mirrors `functions/src/foodSources.ts`'s
/// `searchOpenFoodFacts` for consistency with the text-search path.
class OpenFoodFactsClient {
  OpenFoodFactsClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Returns null if the barcode has no match, the product is missing
  /// nutriment data, or the request fails — callers treat all of these the
  /// same way (fall back to "build it from ingredients").
  Future<ScannedFood?> lookupBarcode(String barcode) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    late final http.Response response;
    try {
      response = await _client.get(uri);
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    if (data['status'] != 1) return null;

    final product = data['product'] as Map<String, dynamic>?;
    final name = product?['product_name'] as String?;
    final nutriments = product?['nutriments'] as Map<String, dynamic>?;
    if (product == null || name == null || name.isEmpty || nutriments == null) return null;

    final calories = (nutriments['energy-kcal_100g'] as num?)?.toDouble();
    final protein = (nutriments['proteins_100g'] as num?)?.toDouble();
    final carbs = (nutriments['carbohydrates_100g'] as num?)?.toDouble();
    final fat = (nutriments['fat_100g'] as num?)?.toDouble();
    if (calories == null || protein == null || carbs == null || fat == null) return null;

    return ScannedFood(
      name: name,
      barcode: barcode,
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      servingLabel: product['serving_size'] as String?,
    );
  }
}
