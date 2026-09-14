import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/food_entry.dart';
import '../domain/food_search_result.dart';
import 'custom_food_repository.dart';

class FoodSearchService {
  // (kept as regular assignments, not initializing formals, so the public
  // parameter names stay `functions`/`customFoodRepository` while the
  // backing fields stay private, matching CustomFoodRepository's style)
  FoodSearchService({
    required FirebaseFunctions functions,
    required CustomFoodRepository customFoodRepository,
    // ignore: prefer_initializing_formals
  })  : _functions = functions,
        // ignore: prefer_initializing_formals
        _customFoodRepository = customFoodRepository;

  final FirebaseFunctions _functions;
  final CustomFoodRepository _customFoodRepository;

  // Exposes the underlying repository so presentation-layer widgets (e.g.
  // the add-custom-food form) can add entries without threading a second
  // repository instance through every constructor.
  CustomFoodRepository get customFoodRepository => _customFoodRepository;

  Future<List<FoodSearchResult>> search(String uid, String query) async {
    final callable = _functions.httpsCallable('searchFood');
    final response = await callable.call<Map<String, dynamic>>({'query': query});
    final externalResults = (response.data['results'] as List)
        .map((r) => FoodSearchResult.fromCloudFunctionJson(r as Map<String, dynamic>))
        .toList();

    final customFoods = await _customFoodRepository.search(uid, query);
    final customResults = customFoods.map((f) => FoodSearchResult(
          name: f.name,
          source: FoodSource.custom,
          caloriesPer100g: f.caloriesPer100g,
          proteinPer100g: f.proteinPer100g,
          carbsPer100g: f.carbsPer100g,
          fatPer100g: f.fatPer100g,
        ));

    return [...externalResults, ...customResults];
  }

  Future<List<ParsedFoodItem>> parseText(String text) async {
    final callable = _functions.httpsCallable('parseFoodText');
    final response = await callable.call<Map<String, dynamic>>({'text': text});
    return (response.data['items'] as List)
        .map((i) => ParsedFoodItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<List<ParsedFoodItem>> parseImage(Uint8List imageBytes, String mimeType) async {
    final callable = _functions.httpsCallable('parseFoodImage');
    final response = await callable.call<Map<String, dynamic>>({
      'imageBase64': base64Encode(imageBytes),
      'mimeType': mimeType,
    });
    return (response.data['items'] as List)
        .map((i) => ParsedFoodItem.fromJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<FoodSearchResult> estimateNutrition(String foodName) async {
    final callable = _functions.httpsCallable('estimateNutrition');
    final response = await callable.call<Map<String, dynamic>>({'foodName': foodName});
    final data = response.data;
    return FoodSearchResult(
      name: foodName,
      source: FoodSource.llmEstimated,
      caloriesPer100g: (data['caloriesPer100g'] as num).toDouble(),
      proteinPer100g: (data['proteinPer100g'] as num).toDouble(),
      carbsPer100g: (data['carbsPer100g'] as num).toDouble(),
      fatPer100g: (data['fatPer100g'] as num).toDouble(),
    );
  }
}
