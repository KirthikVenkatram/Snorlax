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
    if (goal.category == GoalCategory.primary && goal.status == GoalStatus.active) {
      final activePrimaryGoals = await _goals(uid)
          .where('category', isEqualTo: GoalCategory.primary.name)
          .where('status', isEqualTo: GoalStatus.active.name)
          .get();
      for (final activeGoal in activePrimaryGoals.docs) {
        if (activeGoal.id != doc.id) {
          batch.update(activeGoal.reference, {
            'status': GoalStatus.archived.name,
            'updatedAt': Timestamp.fromDate(goal.updatedAt),
          });
        }
      }
    }
    batch.set(doc, goal.toJson());
    await batch.commit();
    return doc.id;
  }

  Future<List<FitnessGoal>> listGoals(String uid) async {
    final snapshot = await _goals(uid).orderBy('updatedAt', descending: true).get();
    return snapshot.docs.map((doc) => FitnessGoal.fromJson(doc.id, doc.data())).toList();
  }

  Future<void> updateGoal(String uid, FitnessGoal goal) async {
    await _goals(uid).doc(goal.id).set(goal.toJson());
  }

  Future<void> archiveGoal(String uid, String goalId) async {
    await _goals(uid).doc(goalId).update({
      'status': GoalStatus.archived.name,
      'updatedAt': Timestamp.now(),
    });
  }
}
