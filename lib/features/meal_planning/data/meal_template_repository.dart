import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/meal_template.dart';

/// Owner-scoped CRUD for `users/{uid}/mealTemplates/{templateId}`.
class MealTemplateRepository {
  MealTemplateRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _templates(String uid) =>
      _firestore.collection('users').doc(uid).collection('mealTemplates');

  Future<List<MealTemplate>> list(String uid) async {
    final snapshot = await _templates(uid).orderBy('name').get();
    return snapshot.docs.map((doc) => MealTemplate.fromJson(doc.id, doc.data())).toList();
  }

  Future<MealTemplate?> get(String uid, String templateId) async {
    final doc = await _templates(uid).doc(templateId).get();
    if (!doc.exists || doc.data() == null) return null;
    return MealTemplate.fromJson(doc.id, doc.data()!);
  }

  /// Creates a new template, letting Firestore generate the id.
  Future<MealTemplate> create(String uid, MealTemplate template) async {
    final doc = await _templates(uid).add(template.toJson());
    return MealTemplate.fromJson(doc.id, template.toJson());
  }

  Future<void> update(String uid, MealTemplate template) async {
    await _templates(uid).doc(template.id).set(template.toJson());
  }

  Future<void> delete(String uid, String templateId) async {
    await _templates(uid).doc(templateId).delete();
  }
}
