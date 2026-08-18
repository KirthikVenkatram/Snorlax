import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/custom_food_repository.dart';
import '../data/food_search_service.dart';
import '../data/nutrition_repository.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>((ref) {
  return NutritionRepository(firestore: ref.watch(firestoreProvider));
});

final customFoodRepositoryProvider = Provider<CustomFoodRepository>((ref) {
  return CustomFoodRepository(firestore: ref.watch(firestoreProvider));
});

final foodSearchServiceProvider = Provider<FoodSearchService>((ref) {
  return FoodSearchService(
    functions: FirebaseFunctions.instance,
    customFoodRepository: ref.watch(customFoodRepositoryProvider),
  );
});
