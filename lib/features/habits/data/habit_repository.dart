import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/habit.dart';
import '../domain/habit_completion.dart';

class HabitRepository {
  HabitRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _habits(String uid) =>
      _firestore.collection('users').doc(uid).collection('habits');

  CollectionReference<Map<String, dynamic>> _completions(String uid) =>
      _firestore.collection('users').doc(uid).collection('habitCompletions');

  Future<String> createHabit(String uid, Habit habit) async {
    Habit.validate(cadence: habit.cadence, timesPerWeek: habit.timesPerWeek);
    final doc = _habits(uid).doc(habit.id);
    await doc.set(habit.toJson());
    return doc.id;
  }

  /// Lists habits. Archived habits are excluded unless
  /// [includeArchived] is set, so callers building "today's habit list"
  /// get active habits only by default.
  Future<List<Habit>> listHabits(String uid, {bool includeArchived = false}) async {
    final snapshot = await _habits(uid).orderBy('createdAt', descending: true).get();
    final habits = snapshot.docs.map((doc) => Habit.fromJson(doc.id, doc.data())).toList();
    if (includeArchived) return habits;
    return habits.where((habit) => !habit.archived).toList();
  }

  Future<void> archiveHabit(String uid, String habitId) async {
    await _habits(uid).doc(habitId).update({'archived': true});
  }

  Future<HabitCompletion?> getCompletion(String uid, DateTime date) async {
    final docId = habitCompletionDocId(date);
    final doc = await _completions(uid).doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return HabitCompletion.fromJson(date, doc.data()!);
  }

  /// Marks [habitId] as completed (or excluded, with [reason]) for [date].
  /// Merges into the existing per-date document rather than overwriting
  /// other habits' entries for that day.
  Future<void> completeHabit(
    String uid,
    DateTime date,
    String habitId, {
    bool completed = true,
    bool excluded = false,
    ExclusionReason? reason,
  }) async {
    final docId = habitCompletionDocId(date);
    final status = HabitEntryStatus(completed: completed, excluded: excluded, reason: reason);
    await _completions(uid).doc(docId).set({habitId: status.toJson()}, SetOptions(merge: true));
  }
}
