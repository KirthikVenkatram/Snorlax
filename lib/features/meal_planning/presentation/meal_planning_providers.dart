import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/budget_repository.dart';
import '../data/meal_plan_repository.dart';
import '../data/meal_template_repository.dart';
import '../data/price_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(firestore: ref.watch(firestoreProvider));
});

final priceRepositoryProvider = Provider<PriceRepository>((ref) {
  return PriceRepository(firestore: ref.watch(firestoreProvider));
});

final mealTemplateRepositoryProvider = Provider<MealTemplateRepository>((ref) {
  return MealTemplateRepository(firestore: ref.watch(firestoreProvider));
});

final mealPlanRepositoryProvider = Provider<MealPlanRepository>((ref) {
  return MealPlanRepository(firestore: ref.watch(firestoreProvider));
});
