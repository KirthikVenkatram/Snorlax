import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/auth/data/user_profile_repository.dart';
import 'package:fitness_tracker/features/auth/presentation/onboarding_screen.dart';

void main() {
  Future<void> pumpTallSurface(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: widget));
    await tester.pumpAndSettle();
  }

  testWidgets('renders step 1 with the kicker, title, and name/age fields', (tester) async {
    final repository = UserProfileRepository(firestore: FakeFirebaseFirestore());

    await pumpTallSurface(
      tester,
      OnboardingScreen(uid: 'u1', profileRepository: repository, onComplete: () {}),
    );

    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text("Who's training?"), findsOneWidget);
    expect(find.byKey(const Key('onboardingNameField')), findsOneWidget);
    expect(find.byKey(const Key('onboardingAgeField')), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('walking all 3 steps saves a profile and calls onComplete', (tester) async {
    final repository = UserProfileRepository(firestore: FakeFirebaseFirestore());
    var completed = false;

    await pumpTallSurface(
      tester,
      OnboardingScreen(
        uid: 'u1',
        profileRepository: repository,
        onComplete: () => completed = true,
      ),
    );

    await tester.enterText(find.byKey(const Key('onboardingAgeField')), '27');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('onboardingWeightField')), '92');
    await tester.enterText(find.byKey(const Key('onboardingHeightField')), '178');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('STEP 3 OF 3'), findsOneWidget);
    expect(find.byKey(const Key('onboardingTargetCalories')), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);

    await tester.tap(find.text('Start tracking'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    final saved = await repository.getProfile('u1');
    expect(saved, isNotNull);
    expect(saved!.age, 27);
    expect(saved.weightKg, 92);
    expect(saved.heightCm, 178);
  });
}
