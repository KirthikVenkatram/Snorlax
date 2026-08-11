import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../domain/strava_connection.dart';

class StravaConnectionRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  StravaConnectionRepository({
    required FirebaseFirestore firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore, // ignore: prefer_initializing_formals
        _explicitFunctions = functions;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions? _explicitFunctions;

  // Resolved lazily (rather than in the initializer list) so constructing a
  // repository in tests that never call connect() doesn't require a real
  // Firebase.initializeApp() call just to read FirebaseFunctions.instance.
  FirebaseFunctions get _functions => _explicitFunctions ?? FirebaseFunctions.instance;

  DocumentReference<Map<String, dynamic>> _connectionDoc(String uid) => _firestore
      .collection('users')
      .doc(uid)
      .collection('meta')
      .doc('stravaConnection');

  Stream<StravaConnection?> watchConnection(String uid) {
    return _connectionDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      final connectedAt = data['connectedAt'] as Timestamp?;
      return StravaConnection(
        athleteId: data['athleteId'] as int,
        connectedAt: connectedAt?.toDate(),
      );
    });
  }

  Future<void> connect(String authorizationCode) async {
    await _functions.httpsCallable('exchangeStravaToken').call({'code': authorizationCode});
  }

  Future<void> disconnect(String uid) async {
    await _connectionDoc(uid).delete();
  }
}
