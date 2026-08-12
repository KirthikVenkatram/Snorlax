import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/strava/presentation/strava_providers.dart';
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
      GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
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
    ],
  );
});
