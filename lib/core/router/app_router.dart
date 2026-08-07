// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_providers.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/sign_in_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final profileRepository = ref.watch(userProfileRepositoryProvider);

  return GoRouter(
    initialLocation: '/sign-in',
    redirect: (context, state) async {
      final user = await authRepository.authStateChanges().first;
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
    ],
  );
});
