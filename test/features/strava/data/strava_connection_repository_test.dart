import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/strava/data/strava_connection_repository.dart';

void main() {
  group('StravaConnectionRepository', () {
    test('watchConnection emits null when not connected', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      final connection = await repository.watchConnection('uid-1').first;

      expect(connection, isNull);
    });

    test('watchConnection emits a StravaConnection once the doc exists', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .set({'athleteId': 12345, 'refreshToken': 'unused-by-client'});

      final connection = await repository.watchConnection('uid-1').first;

      expect(connection, isNotNull);
      expect(connection!.athleteId, 12345);
    });

    test('disconnect deletes the connection document', () async {
      final firestore = FakeFirebaseFirestore();
      final repository = StravaConnectionRepository(firestore: firestore);

      await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .set({'athleteId': 12345, 'refreshToken': 'x'});

      await repository.disconnect('uid-1');

      final doc = await firestore
          .collection('users')
          .doc('uid-1')
          .collection('meta')
          .doc('stravaConnection')
          .get();
      expect(doc.exists, isFalse);
    });
  });
}
