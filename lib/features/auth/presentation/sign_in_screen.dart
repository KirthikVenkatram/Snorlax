// lib/features/auth/presentation/sign_in_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/primary_button.dart';
import 'auth_providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _signingIn = false;

  Future<void> _signIn(Future<Object?> Function() signInMethod) async {
    setState(() => _signingIn = true);

    try {
      await signInMethod();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = ref.read(authRepositoryProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Fitness Tracker', style: Theme.of(context).textTheme.displayLarge),
            const SizedBox(height: 48),
            PrimaryButton(
              label: 'Sign in with Google',
              onPressed: _signingIn ? null : () => _signIn(authRepository.signInWithGoogle),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Sign in with Apple',
              onPressed: _signingIn ? null : () => _signIn(authRepository.signInWithApple),
            ),
            if (_signingIn) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
