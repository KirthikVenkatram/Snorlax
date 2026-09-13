import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/budget_settings.dart';

/// Owner-scoped CRUD for the single `users/{uid}/budgetSettings/current`
/// document.
class BudgetRepository {
  BudgetRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _firestore.collection('users').doc(uid).collection('budgetSettings').doc('current');

  /// Null if the user hasn't configured a budget yet — a brand-new user is
  /// an expected state, not an error.
  Future<BudgetSettings?> get(String uid) async {
    final snapshot = await _doc(uid).get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    return BudgetSettings.fromJson(snapshot.data()!);
  }

  Future<void> save(String uid, BudgetSettings settings) async {
    await _doc(uid).set(settings.toJson());
  }
}
