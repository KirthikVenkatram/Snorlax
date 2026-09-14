import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/sleep_entry.dart';

/// Owner-scoped CRUD for `users/{uid}/sleep/{date}`.
///
/// Mirrors `ReadinessRepository`'s shape. Unlike readiness, a sleep
/// check-in has no derived calculation to run — [recordCheckIn] just
/// persists what the user entered.
class SleepRepository {
  SleepRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _sleep(String uid) =>
      _firestore.collection('users').doc(uid).collection('sleep');

  /// Persists a check-in for [date], overwriting any existing entry for
  /// that date.
  Future<SleepEntry> recordCheckIn(
    String uid,
    DateTime date, {
    required DateTime bedtime,
    required DateTime wakeTime,
    required int awakeMinutes,
    required int score,
    int? restingHeartRate,
    double? hrv,
    SleepStageMinutes? stages,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    final entry = SleepEntry(
      date: day,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakeMinutes: awakeMinutes,
      score: score,
      restingHeartRate: restingHeartRate,
      hrv: hrv,
      stages: stages,
    );
    await _sleep(uid).doc(sleepDocId(day)).set(entry.toJson());
    return entry;
  }

  /// Reads the sleep entry for [date], or null if the user has not checked
  /// in that night.
  Future<SleepEntry?> getByDate(String uid, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final doc = await _sleep(uid).doc(sleepDocId(day)).get();
    if (!doc.exists || doc.data() == null) return null;
    return SleepEntry.fromJson(day, doc.data()!);
  }

  /// The most recent [days] nights with a check-in, newest first, for the
  /// 7-night chart. Nights with no check-in are simply absent (not
  /// zero-filled) — callers plot only what exists.
  Future<List<SleepEntry>> listRecent(String uid, int days) async {
    final snapshot =
        await _sleep(uid).orderBy(FieldPath.documentId, descending: true).limit(days).get();
    return snapshot.docs
        .map((doc) => SleepEntry.fromJson(DateTime.parse(doc.id), doc.data()))
        .toList();
  }
}
