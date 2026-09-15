import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/user_profile_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/adherence/presentation/adherence_providers.dart';
import '../../features/adherence/presentation/adherence_screen.dart';
import '../../features/body_composition/presentation/body_composition_providers.dart';
import '../../features/body_composition/presentation/body_composition_screen.dart';
import '../../features/coach/presentation/coach_providers.dart';
import '../../features/coach/presentation/coach_recommendations_screen.dart';
import '../../features/dashboard/presentation/app_shell.dart';
import '../../features/dashboard/presentation/home_tab.dart';
import '../../features/dashboard/presentation/more_tab.dart';
import '../../features/goals/presentation/goal_providers.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/habits/presentation/habit_providers.dart';
import '../../features/habits/presentation/habits_screen.dart';
import '../../features/habits/presentation/streaks_screen.dart';
import '../../features/meal_planning/presentation/meal_planning_providers.dart';
import '../../features/meal_planning/presentation/meal_planning_screen.dart';
import '../../features/nutrition/presentation/nutrition_home_screen.dart';
import '../../features/nutrition/presentation/nutrition_providers.dart';
import '../../features/nutrition/presentation/recipe_builder_screen.dart';
import '../../features/readiness/presentation/readiness_check_in_screen.dart';
import '../../features/readiness/presentation/readiness_providers.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/sleep/presentation/sleep_check_in_screen.dart';
import '../../features/sleep/presentation/sleep_providers.dart';
import '../../features/sleep/presentation/sleep_screen.dart';
import '../../features/strava/presentation/strava_providers.dart';
import '../../features/trends/presentation/trends_screen.dart';
import '../../features/workouts/presentation/exercise_library_screen.dart';
import '../../features/workouts/presentation/workout_providers.dart';
import '../../features/workouts/presentation/workouts_home_screen.dart';

/// Turns a [Stream] into a [Listenable] so `go_router`'s `redirect`
/// callback re-runs whenever the stream emits, not just on navigation.
///
/// go_router shipped a built-in `GoRouterRefreshStream` for this purpose in
/// early versions, but it was removed in a later breaking change and never
/// reintroduced, so this project provides its own minimal equivalent.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final profileRepository = ref.watch(userProfileRepositoryProvider);

  final refreshListenable = GoRouterRefreshStream(authRepository.authStateChanges());
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/sign-in',
    refreshListenable: refreshListenable,
    redirect: (context, state) async {
      // Prefer the cached authStateProvider value so most redirects don't
      // re-subscribe to the auth stream. Only fall back to a fresh read
      // when the provider hasn't resolved its first value yet.
      final cachedAuthState = ref.read(authStateProvider);
      final user = cachedAuthState is AsyncData<AppUser?>
          ? cachedAuthState.value
          : await authRepository.authStateChanges().first;
      final signingIn = state.matchedLocation == '/sign-in';

      if (user == null) return signingIn ? null : '/sign-in';

      final profile = await profileRepository.getProfile(user.uid);
      final onboarding = state.matchedLocation == '/onboarding';

      if (profile == null) return onboarding ? null : '/onboarding';
      if (signingIn || onboarding) return '/dashboard';

      return null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (context, state) => const SignInScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) {
          // Captured `ref` (from the enclosing Provider) rather than
          // route `extra`, since redirects don't carry `extra` through.
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return OnboardingScreen(
            uid: uid,
            profileRepository: profileRepository,
            onComplete: () => GoRouter.of(context).go('/dashboard'),
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return AppShell(
            homeBuilder: (onNavigateToTab) => HomeTab(
              uid: uid,
              displayName: ref.read(firebaseAuthProvider).currentUser?.displayName,
              nutritionRepository: ref.read(nutritionRepositoryProvider),
              adherenceRepository: ref.read(adherenceRepositoryProvider),
              workoutRepository: ref.read(workoutRepositoryProvider),
              sleepRepository: ref.read(sleepRepositoryProvider),
              habitRepository: ref.read(habitRepositoryProvider),
              onNavigateToTab: onNavigateToTab,
            ),
            nutrition: NutritionHomeScreen(
              uid: uid,
              nutritionRepository: ref.read(nutritionRepositoryProvider),
              searchService: ref.read(foodSearchServiceProvider),
              recipeRepository: ref.read(recipeRepositoryProvider),
              userProfileRepository: ref.read(userProfileRepositoryProvider),
            ),
            train: WorkoutsHomeScreen(
              uid: uid,
              workoutRepository: ref.read(workoutRepositoryProvider),
              exerciseRepository: ref.read(exerciseLibraryRepositoryProvider),
              stravaRepository: ref.read(stravaConnectionRepositoryProvider),
            ),
            coach: CoachRecommendationsScreen(
              uid: uid,
              service: ref.read(coachServiceProvider),
            ),
            more: const MoreTab(),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) {
          final user = ref.read(firebaseAuthProvider).currentUser!;
          return SettingsScreen(
            uid: user.uid,
            email: user.email,
            adherenceRepository: ref.read(adherenceRepositoryProvider),
            authRepository: authRepository,
          );
        },
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) {
          final user = ref.read(firebaseAuthProvider).currentUser!;
          return ProfileScreen(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            profileRepository: profileRepository,
            adherenceRepository: ref.read(adherenceRepositoryProvider),
            authRepository: authRepository,
          );
        },
      ),
      GoRoute(
        path: '/workouts',
        builder: (context, state) {
          // Same pattern as /onboarding: the signed-in uid comes from the
          // captured `ref`, since the redirect above guarantees a user here.
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return WorkoutsHomeScreen(
            uid: uid,
            workoutRepository: ref.read(workoutRepositoryProvider),
            exerciseRepository: ref.read(exerciseLibraryRepositoryProvider),
            stravaRepository: ref.read(stravaConnectionRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/workouts/exercise-library',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return ExerciseLibraryScreen(
            uid: uid,
            repository: ref.read(exerciseLibraryRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/nutrition',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return NutritionHomeScreen(
            uid: uid,
            nutritionRepository: ref.read(nutritionRepositoryProvider),
            searchService: ref.read(foodSearchServiceProvider),
            recipeRepository: ref.read(recipeRepositoryProvider),
            userProfileRepository: ref.read(userProfileRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/goals',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return GoalsScreen(
            uid: uid,
            repository: ref.read(goalRepositoryProvider),
            onChanged: () {},
          );
        },
      ),
      GoRoute(
        path: '/body',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          // BodyCompositionScreen needs the current profile for sex/height.
          // The router's redirect above already guarantees onboarding is
          // complete (and thus a profile exists) before reaching an
          // authenticated route like this one, so a missing profile here
          // should be unreachable in practice — but fetch defensively and
          // show a clear fallback instead of crashing if it somehow occurs.
          return FutureBuilder<UserProfile?>(
            future: profileRepository.getProfile(uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              final profile = snapshot.data;
              if (profile == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Body composition')),
                  body: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'We could not find your profile. Please complete onboarding '
                        'before tracking body composition.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }
              return BodyCompositionScreen(
                uid: uid,
                profile: profile,
                repository: ref.read(bodyCompositionRepositoryProvider),
                onChanged: () {},
              );
            },
          );
        },
      ),
      GoRoute(
        path: '/habits',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return HabitsScreen(
            uid: uid,
            repository: ref.read(habitRepositoryProvider),
            onChanged: () {},
          );
        },
      ),
      GoRoute(
        path: '/adherence',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return AdherenceScreen(
            uid: uid,
            repository: ref.read(adherenceRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/readiness',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return ReadinessCheckInScreen(
            uid: uid,
            repository: ref.read(readinessRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/coach',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return CoachRecommendationsScreen(
            uid: uid,
            service: ref.read(coachServiceProvider),
          );
        },
      ),
      GoRoute(
        path: '/meal-planning',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return MealPlanningScreen(
            uid: uid,
            budgetRepository: ref.read(budgetRepositoryProvider),
            templateRepository: ref.read(mealTemplateRepositoryProvider),
            planRepository: ref.read(mealPlanRepositoryProvider),
            priceRepository: ref.read(priceRepositoryProvider),
            coachService: ref.read(coachServiceProvider),
          );
        },
      ),
      GoRoute(
        path: '/nutrition/recipe',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return RecipeBuilderScreen(
            uid: uid,
            date: DateTime.now(),
            searchService: ref.read(foodSearchServiceProvider),
            recipeRepository: ref.read(recipeRepositoryProvider),
            nutritionRepository: ref.read(nutritionRepositoryProvider),
            onSaved: () => Navigator.of(context).pop(),
          );
        },
      ),
      GoRoute(
        path: '/sleep',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return SleepScreen(uid: uid, repository: ref.read(sleepRepositoryProvider));
        },
      ),
      GoRoute(
        path: '/sleep/check-in',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return SleepCheckInScreen(uid: uid, repository: ref.read(sleepRepositoryProvider));
        },
      ),
      GoRoute(
        path: '/trends',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return TrendsScreen(
            uid: uid,
            bodyCompositionRepository: ref.read(bodyCompositionRepositoryProvider),
            adherenceRepository: ref.read(adherenceRepositoryProvider),
            nutritionRepository: ref.read(nutritionRepositoryProvider),
            workoutRepository: ref.read(workoutRepositoryProvider),
          );
        },
      ),
      GoRoute(
        path: '/streaks',
        builder: (context, state) {
          final uid = ref.read(firebaseAuthProvider).currentUser!.uid;
          return StreaksScreen(
            uid: uid,
            habitRepository: ref.read(habitRepositoryProvider),
            adherenceRepository: ref.read(adherenceRepositoryProvider),
            onBack: () => GoRouter.of(context).go('/dashboard'),
          );
        },
      ),
    ],
  );
});
