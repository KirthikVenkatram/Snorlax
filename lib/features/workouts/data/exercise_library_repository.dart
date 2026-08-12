import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/exercise.dart';

const _defaultExerciseNames = [
  'Bench Press',
  'Incline Bench Press',
  'Squat',
  'Front Squat',
  'Deadlift',
  'Romanian Deadlift',
  'Overhead Press',
  'Barbell Row',
  'Pull-up',
  'Chin-up',
  'Lat Pulldown',
  'Bicep Curl',
  'Tricep Pushdown',
  'Leg Press',
  'Leg Curl',
  'Calf Raise',
  'Dumbbell Shoulder Press',
  'Dumbbell Lateral Raise',
  'Plank',
  'Hip Thrust',
];

class ExerciseLibraryRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  ExerciseLibraryRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('exerciseLibrary');

  Future<void> seedDefaultsIfEmpty(String uid) async {
    final existing = await _collection(uid).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final name in _defaultExerciseNames) {
      final doc = _collection(uid).doc();
      batch.set(doc, Exercise(id: doc.id, name: name, isCustom: false).toJson());
    }
    await batch.commit();
  }

  Future<Exercise> addCustom(String uid, String name) async {
    final doc = _collection(uid).doc();
    final exercise = Exercise(id: doc.id, name: name, isCustom: true);
    await doc.set(exercise.toJson());
    return exercise;
  }

  Future<List<Exercise>> search(String uid, String query) async {
    final all = await watchAll(uid).first;
    final normalizedQuery = query.toLowerCase();
    return all.where((e) => e.name.toLowerCase().contains(normalizedQuery)).toList();
  }

  Stream<List<Exercise>> watchAll(String uid) {
    return _collection(uid).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Exercise.fromJson(doc.id, doc.data()))
              .toList(),
        );
  }
}
