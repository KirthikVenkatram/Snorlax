import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/calculations/nutrition_goal_calculator.dart';
import 'package:fitness_tracker/features/adherence/data/adherence_repository.dart';
import 'package:fitness_tracker/features/auth/data/auth_repository.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';
import 'package:fitness_tracker/features/auth/presentation/profile_screen.dart';
import 'package:fitness_tracker/features/habits/data/habit_repository.dart';
import 'package:fitness_tracker/features/nutrition/data/nutrition_repository.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';

void main() {
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  Future<UserProfile> seedProfile(UserProfileRepository repo, String uid) async {
    final targets = NutritionGoalCalculator.calculate(
      weightKg: 92,
      heightCm: 178,
      age: 27,
      sex: Sex.male,
      activityLevel: ActivityLevel.light,
      goal: Goal.lose,
    );
    final profile = UserProfile(
      age: 27,
      weightKg: 92,
      heightCm: 178,
      sex: Sex.male,
      activityLevel: ActivityLevel.light,
      goal: Goal.lose,
      targets: targets,
    );
    await repo.saveProfile(uid, profile);
    return profile;
  }

  testWidgets('renders name, summary line, and daily targets from the saved profile', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final profileRepository = UserProfileRepository(firestore: firestore);
    await seedProfile(profileRepository, 'u1');
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      ProfileScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        displayName: 'Kirthik',
        profileRepository: profileRepository,
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    expect(find.text('Kirthik'), findsOneWidget);
    expect(find.byKey(const Key('profileSummaryLine')), findsOneWidget);
    expect(find.text('27 · 92 kg · 178 cm · light'), findsOneWidget);
    expect(find.byKey(const Key('profileTargetCalories')), findsOneWidget);
    expect(find.byKey(const Key('profileSignOutButton')), findsOneWidget);
    expect(find.byKey(const Key('profileReplayOnboardingButton')), findsOneWidget);
  });

  testWidgets('sign-out button invokes AuthRepository.signOut', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final profileRepository = UserProfileRepository(firestore: firestore);
    await seedProfile(profileRepository, 'u1');
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      ProfileScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        profileRepository: profileRepository,
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    expect(mockAuth.currentUser, isNotNull);
    await tester.tap(find.byKey(const Key('profileSignOutButton')));
    await tester.pumpAndSettle();

    expect(mockAuth.currentUser, isNull);
  });

  testWidgets('editing weight and saving recomputes and persists new targets', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final profileRepository = UserProfileRepository(firestore: firestore);
    await seedProfile(profileRepository, 'u1');
    final adherenceRepository = AdherenceRepository(
      firestore: firestore,
      nutritionRepository: NutritionRepository(firestore: firestore),
      workoutRepository: WorkoutRepository(firestore: firestore),
      habitRepository: HabitRepository(firestore: firestore),
      readinessRepository: ReadinessRepository(firestore: firestore),
    );
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));

    await pumpTallSurface(
      tester,
      ProfileScreen(
        uid: 'u1',
        email: 'athlete@example.com',
        profileRepository: profileRepository,
        adherenceRepository: adherenceRepository,
        authRepository: AuthRepository(firebaseAuth: mockAuth),
      ),
    );

    await tester.enterText(find.byKey(const Key('profileWeightField')), '100');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await profileRepository.getProfile('u1');
    expect(saved!.weightKg, 100);
  });
}
