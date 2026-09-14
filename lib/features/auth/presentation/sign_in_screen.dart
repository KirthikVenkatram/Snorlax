import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
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
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text('Sign-in failed: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = ref.read(authRepositoryProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                // Mark + title sit vertically centred in the top two-thirds;
                // the sign-in pills are bottom-anchored below.
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            gradient: const LinearGradient(
                              colors: [AppColors.accentGreen, AppColors.accentViolet],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'S',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  fontSize: 44,
                                  color: Colors.white,
                                ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Snorlax',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 44),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Training, food and sleep in one place.\nConsistency beats intensity.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GoogleSignInButton(
                      enabled: !_signingIn,
                      onPressed: () => _signIn(authRepository.signInWithGoogle),
                    ),
                    const SizedBox(height: 12),
                    SignInWithAppleButton(
                      height: 52,
                      style: SignInWithAppleButtonStyle.white,
                      borderRadius: BorderRadius.circular(999),
                      onPressed: _signingIn ? () {} : () => _signIn(authRepository.signInWithApple),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Google and Apple only. No passwords to forget.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                    SizedBox(
                      height: 40,
                      child: _signingIn
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _GoogleMark(),
                SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A minimal, license-free approximation of Google's multi-color "G" mark
/// (four quarter-arcs in brand colors) so the button reads as
/// Google-affiliated without embedding Google's actual logo asset.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * 0.22;
    final radius = (size.width - strokeWidth) / 2;
    final center = rect.center;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    void arc(double startDegrees, double sweepDegrees, Color color) {
      paint.color = color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startDegrees * 3.1415926535 / 180,
        sweepDegrees * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(-45, 90, const Color(0xFF4285F4));
    arc(45, 90, const Color(0xFF34A853));
    arc(135, 90, const Color(0xFFFBBC05));
    arc(225, 90, const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
