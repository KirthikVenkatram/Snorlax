// lib/features/auth/presentation/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/gradient_button.dart';
import 'auth_providers.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fitness Tracker', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 48),
            GradientButton(
              label: 'Sign in with Google',
              onPressed: () => ref.read(authRepositoryProvider).signInWithGoogle(),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Sign in with Apple',
              onPressed: () => ref.read(authRepositoryProvider).signInWithApple(),
            ),
          ],
        ),
      ),
    );
  }
}
