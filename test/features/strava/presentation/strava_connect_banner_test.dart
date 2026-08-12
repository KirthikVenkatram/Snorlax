import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/strava/data/strava_connection_repository.dart';
import 'package:fitness_tracker/features/strava/presentation/strava_connect_banner.dart';

Widget _wrap(StravaConnectionRepository repository) => MaterialApp(
      home: Scaffold(
        body: StravaConnectBanner(uid: 'uid-1', repository: repository),
      ),
    );

void main() {
  testWidgets('renders the not-connected state with a Connect button', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = StravaConnectionRepository(firestore: firestore);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Connect Strava to sync your runs and rides'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Disconnect'), findsNothing);
  });

  testWidgets('renders the connected state with a Disconnect button', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = StravaConnectionRepository(firestore: firestore);

    await firestore
        .collection('users')
        .doc('uid-1')
        .collection('meta')
        .doc('stravaConnection')
        .set({'athleteId': 12345});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Strava connected'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
  });

  testWidgets('tapping Disconnect deletes the connection', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final repository = StravaConnectionRepository(firestore: firestore);
    final doc = firestore
        .collection('users')
        .doc('uid-1')
        .collection('meta')
        .doc('stravaConnection');
    await doc.set({'athleteId': 12345});

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect((await doc.get()).exists, isFalse);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final firestore = FakeFirebaseFirestore();
    final repository = StravaConnectionRepository(firestore: firestore);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
