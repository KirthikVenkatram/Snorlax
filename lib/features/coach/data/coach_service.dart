import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/coach_event.dart';
import '../domain/coach_recommendation.dart';

/// Client access to the coach feature: reads `coachRecommendations`/
/// `coachEvents` directly from Firestore (both are server-written,
/// client-read-only per `firestore.rules`), and calls the two callable
/// Cloud Functions that are the only way to trigger a new recommendation or
/// act on one.
class CoachService {
  CoachService({
    required FirebaseFirestore firestore,
    required FirebaseFunctions functions,
    // ignore: prefer_initializing_formals
  })  : _firestore = firestore,
        // ignore: prefer_initializing_formals
        _functions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> _recommendations(String uid) =>
      _firestore.collection('users').doc(uid).collection('coachRecommendations');

  CollectionReference<Map<String, dynamic>> _events(String uid) =>
      _firestore.collection('users').doc(uid).collection('coachEvents');

  Future<List<CoachRecommendation>> listRecommendations(String uid) async {
    final snapshot = await _recommendations(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => CoachRecommendation.fromJson(doc.id, doc.data())).toList();
  }

  Future<List<CoachEvent>> listEvents(String uid) async {
    final snapshot = await _events(uid).orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => CoachEvent.fromJson(doc.id, doc.data())).toList();
  }

  /// Calls the `generateRecommendation` callable, which builds a fresh
  /// server-side context, asks the AI provider for a recommendation,
  /// schema-validates it, and writes it. Returns the new recommendation id.
  Future<String> generateRecommendation() async {
    final callable = _functions.httpsCallable('generateRecommendation');
    final response = await callable.call<Map<String, dynamic>>();
    return response.data['id'] as String;
  }

  /// Calls the `handleCommand` callable with the user's decision. The
  /// server re-validates the proposed command from scratch before applying
  /// anything — this call never mutates protected data directly itself.
  Future<void> submitDecision(String recommendationId, {required bool approve}) async {
    final callable = _functions.httpsCallable('handleCommand');
    await callable.call<Map<String, dynamic>>({
      'recommendationId': recommendationId,
      'decision': approve ? 'approve' : 'reject',
    });
  }
}
