import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/readiness_calculator.dart';
import '../domain/readiness_entry.dart';

/// Owner-scoped CRUD for `users/{uid}/readiness/{date}`.
///
/// [recordCheckIn] both computes the deterministic result (via
/// [ReadinessCalculator]) and persists the entry, so a check-in is always
/// stored alongside the result it produced — never just the raw inputs.
class ReadinessRepository {
  ReadinessRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _readiness(String uid) =>
      _firestore.collection('users').doc(uid).collection('readiness');

  /// Computes the deterministic result for [inputs] and persists the entry
  /// at `readiness/{date}`, overwriting any existing entry for that date.
  Future<ReadinessEntry> recordCheckIn(String uid, DateTime date, ReadinessInputs inputs) async {
    final day = DateTime(date.year, date.month, date.day);
    final result = ReadinessCalculator.calculate(inputs);
    final entry = ReadinessEntry(date: day, inputs: inputs, result: result);
    await _readiness(uid).doc(readinessDocId(day)).set(entry.toJson());
    return entry;
  }

  /// Reads the readiness entry for [date], or null if the user has not
  /// checked in that day. Callers (e.g. the adherence repository's
  /// recovery component) must treat a null result as "excluded", not as a
  /// score of 0 — missing data is not the same as bad readiness.
  Future<ReadinessEntry?> getByDate(String uid, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final doc = await _readiness(uid).doc(readinessDocId(day)).get();
    if (!doc.exists || doc.data() == null) return null;
    return ReadinessEntry.fromJson(day, doc.data()!);
  }
}
