import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fitness_tracker/core/calculations/adherence_calculator.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/auth/data/auth_repository.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_screen.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  setUpAll(() {
    // Widget-test-only fake platform channel for PackageInfo.fromPlatform(),
    // per package_info_plus's documented test setup — no real platform
    // channel or app bundle is touched.
    PackageInfo.setMockInitialValues(
      appName: 'Fitness Tracker',
      packageName: 'com.example.fitness_tracker',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
      installerStore: null,
    );
  });

  AdherenceRepository buildAdherenceRepository(FakeFirebaseFirestore firestore) {
    return AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );
  }

  // The settings screen's content is taller than a default test viewport, and
  // the ListView is Sliver-backed (only mounts enough children to fill the
  // viewport + cache extent). Rather than juggle scrolling in every test,
  // grow the test surface so every card mounts up front.
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  testWidgets('loads and displays current adherence weights from the repository', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final adherenceRepository = buildAdherenceRepository(firestore);
    await adherenceRepository.setWeights(
      'u1',
      const AdherenceWeights(nutrition: 0.5, training: 0.2, habits: 0.2, recovery: 0.1),
    );
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      SettingsScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    final nutritionField = tester.widget<TextFormField>(find.byKey(const Key('weightNutritionField')));
    expect(nutritionField.controller?.text, '0.5');
  });

  testWidgets('editing and saving adherence weights persists via the repository', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final adherenceRepository = buildAdherenceRepository(firestore);
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      SettingsScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    await tester.enterText(find.byKey(const Key('weightNutritionField')), '0.6');
    await tester.tap(find.text('Save weights'));
    await tester.pumpAndSettle();

    final saved = await adherenceRepository.getWeights('u1');
    expect(saved.nutrition, 0.6);
    expect(find.byKey(const Key('weightsSaveSuccess')), findsOneWidget);
  });

  testWidgets('rejects a negative weight instead of saving it', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final adherenceRepository = buildAdherenceRepository(firestore);
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      SettingsScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    await tester.enterText(find.byKey(const Key('weightNutritionField')), '-1');
    await tester.tap(find.text('Save weights'));
    await tester.pumpAndSettle();

    expect(find.text('Must be non-negative'), findsOneWidget);
    // Falls back to the default weights since nothing was ever saved.
    final saved = await adherenceRepository.getWeights('u1');
    expect(saved.nutrition, const AdherenceWeights().nutrition);
  });

  testWidgets('shows the signed-in email, app version, and disclaimer', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final adherenceRepository = buildAdherenceRepository(firestore);
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      SettingsScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    expect(find.text('athlete@example.com'), findsOneWidget);
    expect(find.text('v1.0.0 (1)'), findsOneWidget);
    expect(find.byKey(const Key('settingsDisclaimerText')), findsOneWidget);
  });

  testWidgets('sign-out button invokes AuthRepository.signOut', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final adherenceRepository = buildAdherenceRepository(firestore);
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      SettingsScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    expect(mockAuth.currentUser, isNotNull);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(mockAuth.currentUser, isNull);
  });
}
