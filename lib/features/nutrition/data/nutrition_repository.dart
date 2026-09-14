import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/food_entry.dart';

class NutritionRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  NutritionRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _foodLog(String uid) =>
      _firestore.collection('users').doc(uid).collection('foodLog');

  DocumentReference<Map<String, dynamic>> _goalsDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('nutritionGoals').doc('goals');

  DocumentReference<Map<String, dynamic>> _waterDoc(String uid, DateTime date) => _firestore
      .collection('users')
      .doc(uid)
      .collection('waterLog')
      .doc(_dateKey(date));

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<String> logFood({
    required String uid,
    required DateTime date,
    required MealType mealType,
    required String foodName,
    required double quantityGrams,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required FoodSource source,
  }) async {
    final doc = _foodLog(uid).doc();
    await doc.set({
      'date': Timestamp.fromDate(date),
      'mealType': mealType.name,
      'foodName': foodName,
      'quantityGrams': quantityGrams,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
      'source': source.name,
    });
    return doc.id;
  }

  Future<List<FoodEntry>> listFoodLog(String uid) async {
    final snapshot = await _foodLog(uid).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  Future<void> updateFoodEntry({
    required String uid,
    required String entryId,
    required MealType mealType,
    required double quantityGrams,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    await _foodLog(uid).doc(entryId).update({
      'mealType': mealType.name,
      'quantityGrams': quantityGrams,
      'calories': calories,
      'proteinG': proteinG,
      'carbsG': carbsG,
      'fatG': fatG,
    });
  }

  Future<void> deleteFoodEntry(String uid, String entryId) async {
    await _foodLog(uid).doc(entryId).delete();
  }

  Future<void> setGoals(String uid, NutritionGoals goals) async {
    await _goalsDoc(uid).set(goals.toJson());
  }

  Future<NutritionGoals?> getGoals(String uid) async {
    final doc = await _goalsDoc(uid).get();
    if (!doc.exists) return null;
    return NutritionGoals.fromJson(doc.data()!);
  }

  /// Adds [deltaMl] to the day's logged water (can be negative to undo a
  /// tap), clamped so the stored total never goes below zero.
  Future<void> addWater(String uid, DateTime date, int deltaMl) async {
    final doc = _waterDoc(uid, date);
    final current = await getWaterMl(uid, date);
    final next = (current + deltaMl).clamp(0, 1 << 30);
    await doc.set({'ml': next});
  }

  Future<int> getWaterMl(String uid, DateTime date) async {
    final doc = await _waterDoc(uid, date).get();
    if (!doc.exists) return 0;
    return (doc.data()!['ml'] as num).toInt();
  }

  FoodEntry _fromDoc(String id, Map<String, dynamic> json) {
    return FoodEntry(
      id: id,
      date: (json['date'] as Timestamp).toDate(),
      mealType: MealType.values.byName(json['mealType'] as String),
      foodName: json['foodName'] as String,
      quantityGrams: (json['quantityGrams'] as num).toDouble(),
      calories: (json['calories'] as num).toDouble(),
      proteinG: (json['proteinG'] as num).toDouble(),
      carbsG: (json['carbsG'] as num).toDouble(),
      fatG: (json['fatG'] as num).toDouble(),
      source: FoodSource.values.byName(json['source'] as String),
    );
  }
}
