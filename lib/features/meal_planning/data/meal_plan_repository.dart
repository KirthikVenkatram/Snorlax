import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/meal_plan_calculator.dart';
import '../domain/meal_plan.dart';

/// Owner-scoped CRUD for `users/{uid}/mealPlans/{planId}`.
///
/// [createFromTemplates] is the deterministic, client-side counterpart to
/// the server's `handleCommand.ts` `mealPlanChange` write path: both always
/// compute totals via a pure calculator (`MealPlanCalculator` here,
/// `mealPlanCost.ts` there) rather than accepting a pre-computed total from
/// a caller — a plan document's totals are never anything other than what
/// the calculator produced from its `items`.
class MealPlanRepository {
  MealPlanRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _plans(String uid) =>
      _firestore.collection('users').doc(uid).collection('mealPlans');

  Future<List<MealPlan>> list(String uid) async {
    final snapshot = await _plans(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => MealPlan.fromJson(doc.id, doc.data())).toList();
  }

  Future<MealPlan?> get(String uid, String planId) async {
    final doc = await _plans(uid).doc(planId).get();
    if (!doc.exists || doc.data() == null) return null;
    return MealPlan.fromJson(doc.id, doc.data()!);
  }

  /// Computes totals from [lines] via [MealPlanCalculator] and persists a
  /// new manually-created plan. This is the only supported way to create a
  /// [MealPlan] from the client — there is no path that accepts a
  /// caller-supplied total.
  Future<MealPlan> createFromTemplates({
    required String uid,
    required String name,
    required MealPlanPeriodType periodType,
    required List<MealPlanLineInput> lines,
    required String currency,
  }) async {
    final aggregated = MealPlanCalculator.aggregate(lines);
    final now = DateTime.now();
    final doc = await _plans(uid).add({
      'name': name,
      'periodType': periodType.name,
      'items': aggregated.items.map((i) => i.toJson()).toList(),
      'totalCost': aggregated.totalCost,
      'totalCalories': aggregated.totalCalories,
      'totalProteinG': aggregated.totalProteinG,
      'proteinPerCurrencyUnit': aggregated.proteinPerCurrencyUnit,
      'currency': currency,
      'source': MealPlanSource.manual.name,
      'createdAt': now.toIso8601String(),
    });
    return MealPlan(
      id: doc.id,
      name: name,
      periodType: periodType,
      items: aggregated.items,
      totalCost: aggregated.totalCost,
      totalCalories: aggregated.totalCalories,
      totalProteinG: aggregated.totalProteinG,
      proteinPerCurrencyUnit: aggregated.proteinPerCurrencyUnit,
      currency: currency,
      source: MealPlanSource.manual,
      createdAt: now,
    );
  }

  Future<void> delete(String uid, String planId) async {
    await _plans(uid).doc(planId).delete();
  }
}
