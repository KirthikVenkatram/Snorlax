import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _AmbientGlow(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 88,
                        height: 88,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Snorlax',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 40),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your personal fitness operating system.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 56),
                    _GoogleSignInButton(
                      enabled: !_signingIn,
                      onPressed: () => _signIn(authRepository.signInWithGoogle),
                    ),
                    const SizedBox(height: 12),
                    SignInWithAppleButton(
                      height: 52,
                      style: SignInWithAppleButtonStyle.white,
                      borderRadius: BorderRadius.circular(14),
                      onPressed: _signingIn ? () {} : () => _signIn(authRepository.signInWithApple),
                    ),
                    if (_signingIn) ...[
                      const SizedBox(height: 28),
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
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

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -80,
              child: _glowBlob(AppColors.accentViolet),
            ),
            Positioned(
              bottom: -140,
              right: -100,
              child: _glowBlob(AppColors.accentGreen),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowBlob(Color color) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
