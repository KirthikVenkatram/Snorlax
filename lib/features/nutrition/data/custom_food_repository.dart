import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/custom_food.dart';

class CustomFoodRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  CustomFoodRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('customFoods');

  Future<CustomFood> addCustom(
    String uid, {
    required String name,
    required double caloriesPer100g,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
  }) async {
    final doc = _collection(uid).doc();
    final food = CustomFood(
      id: doc.id,
      name: name,
      caloriesPer100g: caloriesPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
    await doc.set(food.toJson());
    return food;
  }

  Future<List<CustomFood>> search(String uid, String query) async {
    final snapshot = await _collection(uid).get();
    final normalizedQuery = query.toLowerCase();
    return snapshot.docs
        .map((doc) => CustomFood.fromJson(doc.id, doc.data()))
        .where((f) => f.name.toLowerCase().contains(normalizedQuery))
        .toList();
  }
}
