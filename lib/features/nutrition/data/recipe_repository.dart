import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/recipe.dart';

/// Owner-scoped CRUD at `users/{uid}/recipes/{recipeId}` — mirrors
/// [CustomFoodRepository]'s shape.
class RecipeRepository {
  RecipeRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('recipes');

  Future<Recipe> save(String uid, Recipe recipe) async {
    final doc = recipe.id.isEmpty ? _collection(uid).doc() : _collection(uid).doc(recipe.id);
    final saved = Recipe(
      id: doc.id,
      name: recipe.name,
      servings: recipe.servings,
      ingredientNames: recipe.ingredientNames,
      totalCalories: recipe.totalCalories,
      totalProteinG: recipe.totalProteinG,
      totalCarbsG: recipe.totalCarbsG,
      totalFatG: recipe.totalFatG,
    );
    await doc.set(saved.toJson());
    return saved;
  }

  Future<List<Recipe>> list(String uid) async {
    final snapshot = await _collection(uid).get();
    return snapshot.docs.map((doc) => Recipe.fromJson(doc.id, doc.data())).toList();
  }

  Future<List<Recipe>> search(String uid, String query) async {
    final all = await list(uid);
    final normalizedQuery = query.toLowerCase();
    return all.where((r) => r.name.toLowerCase().contains(normalizedQuery)).toList();
  }
}
