import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import 'active_session_screen.dart' show formatSessionDuration;

/// The celebratory interstitial between an active session and Today — per
/// the handoff's screen 6, not in the repo before this slice. Shown via
/// `Navigator.pushReplacement` from [ActiveSessionScreen] so the finished
/// session isn't left in the back stack.
///
/// The handoff's headline references a streak count ("that's {n} days.");
/// that only makes sense once Slice D's real streak calculator exists, so
/// this shows a workout-summary line instead (logged as a documented
/// reconciliation, see plan doc item 2 under Slice B).
class SessionCompleteScreen extends StatefulWidget {
  const SessionCompleteScreen({
    super.key,
    required this.sessionName,
    required this.exerciseCount,
    required this.elapsedSeconds,
    required this.setsCompleted,
    required this.volumeKg,
  });

  final String sessionName;
  final int exerciseCount;
  final int elapsedSeconds;
  final int setsCompleted;
  final double volumeKg;

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // The "deliberate animated layer over the static base" the handoff
    // calls for — cheap, no new animation dependency needed for it.
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.exerciseCount == 0
        ? '${widget.sessionName} logged.'
        : '${widget.sessionName} logged — ${widget.exerciseCount} '
            'exercise${widget.exerciseCount == 1 ? '' : 's'}. Recovery starts now.';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.accentGreen, AppColors.accentViolet],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('SESSION COMPLETE', style: AppTypography.mono(color: Colors.white)),
                const SizedBox(height: 12),
                Text(
                  'Nice work.',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 46, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  summary,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        label: 'TIME',
                        value: formatSessionDuration(widget.elapsedSeconds),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(label: 'SETS', value: '${widget.setsCompleted}')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(label: 'VOLUME', value: '${widget.volumeKg.round()} kg'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _GlassPillButton(
                        label: 'Log a meal',
                        onPressed: () => GoRouter.of(context).push('/nutrition'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Back to today',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTypography.mono(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  const _GlassPillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            color: AppColors.glassFill,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }
}
