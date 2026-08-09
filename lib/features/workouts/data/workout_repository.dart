import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/workout.dart';

class WorkoutRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  WorkoutRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _workouts(String uid) =>
      _firestore.collection('users').doc(uid).collection('workouts');

  Future<String> createStrengthWorkout({
    required String uid,
    required DateTime date,
    required int durationMinutes,
    required List<ExerciseEntry> exercises,
  }) async {
    final doc = _workouts(uid).doc();
    await doc.set({
      'type': WorkoutType.strength.name,
      'source': WorkoutSource.manual.name,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    });
    return doc.id;
  }

  Future<String> createGeneralWorkout({
    required String uid,
    required DateTime date,
    required int durationMinutes,
    required String notes,
  }) async {
    final doc = _workouts(uid).doc();
    await doc.set({
      'type': WorkoutType.general.name,
      'source': WorkoutSource.manual.name,
      'date': Timestamp.fromDate(date),
      'durationMinutes': durationMinutes,
      'notes': notes,
    });
    return doc.id;
  }

  Future<List<Workout>> listWorkouts(String uid) async {
    final snapshot = await _workouts(uid).orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => _fromDoc(doc.id, doc.data())).toList();
  }

  Future<Workout?> getWorkout(String uid, String workoutId) async {
    final doc = await _workouts(uid).doc(workoutId).get();
    if (!doc.exists) return null;
    return _fromDoc(doc.id, doc.data()!);
  }

  Future<void> updateGeneralWorkout({
    required String uid,
    required String workoutId,
    required int durationMinutes,
    required String notes,
  }) async {
    await _workouts(uid).doc(workoutId).update({
      'durationMinutes': durationMinutes,
      'notes': notes,
    });
  }

  Future<void> deleteWorkout(String uid, String workoutId) async {
    await _workouts(uid).doc(workoutId).delete();
  }

  Workout _fromDoc(String id, Map<String, dynamic> json) {
    final exercisesJson = json['exercises'] as List?;
    return Workout(
      id: id,
      type: WorkoutType.values.byName(json['type'] as String),
      source: WorkoutSource.values.byName(json['source'] as String),
      date: (json['date'] as Timestamp).toDate(),
      durationMinutes: json['durationMinutes'] as int,
      exercises: exercisesJson
          ?.map((e) => ExerciseEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble(),
      paceMinPerKm: (json['paceMinPerKm'] as num?)?.toDouble(),
      stravaActivityId: json['stravaActivityId'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
