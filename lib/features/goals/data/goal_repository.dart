import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/fitness_goal.dart';

class GoalRepository {
  GoalRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _goals(String uid) =>
      _firestore.collection('users').doc(uid).collection('goals');

  Future<String> createGoal(String uid, FitnessGoal goal) async {
    final doc = _goals(uid).doc(goal.id);
    final batch = _firestore.batch();
    await _archiveOtherActivePrimaryGoals(uid, batch, goal, excludingId: doc.id);
    batch.set(doc, goal.toJson());
    await batch.commit();
    return doc.id;
  }

  Future<List<FitnessGoal>> listGoals(String uid) async {
    final snapshot = await _goals(uid).orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((doc) => FitnessGoal.fromJson(doc.id, doc.data())).toList();
  }

  Future<void> updateGoal(String uid, FitnessGoal goal) async {
    final batch = _firestore.batch();
    // Reactivating a paused/archived primary goal (or editing an
    // already-active one) must uphold the same "at most one active primary
    // goal" invariant createGoal enforces — otherwise a status transition
    // through this method could silently leave two goals active at once.
    await _archiveOtherActivePrimaryGoals(uid, batch, goal, excludingId: goal.id);
    batch.set(_goals(uid).doc(goal.id), goal.toJson());
    await batch.commit();
  }

  /// If [goal] is an active primary goal, archives every other active
  /// primary goal (excluding [excludingId], the goal being written) in the
  /// same batch, so the write this batch is building for never coexists
  /// with a second active primary goal.
  Future<void> _archiveOtherActivePrimaryGoals(
    String uid,
    WriteBatch batch,
    FitnessGoal goal, {
    required String excludingId,
  }) async {
    if (goal.category != GoalCategory.primary || goal.status != GoalStatus.active) return;

    final activePrimaryGoals = await _goals(uid)
        .where('category', isEqualTo: GoalCategory.primary.name)
        .where('status', isEqualTo: GoalStatus.active.name)
        .get();
    for (final activeGoal in activePrimaryGoals.docs) {
      if (activeGoal.id != excludingId) {
        batch.update(activeGoal.reference, {
          'status': GoalStatus.archived.name,
          'updatedAt': Timestamp.now(),
        });
      }
    }
  }

  Future<void> archiveGoal(String uid, String goalId) async {
    await _goals(uid).doc(goalId).update({
      'status': GoalStatus.archived.name,
      'updatedAt': Timestamp.now(),
    });
  }
}
