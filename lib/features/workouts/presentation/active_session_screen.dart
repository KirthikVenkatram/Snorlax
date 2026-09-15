import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'session_complete_screen.dart';

/// Formats [seconds] as `mm:ss`, tabular — shared by the ticking header
/// timer here and the "Time" stat tile on [SessionCompleteScreen].
String formatSessionDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final secs = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// The active workout runner: a real ticking timer, per-set completion
/// chips, and — on finish — real persistence via the existing
/// [WorkoutRepository.createStrengthWorkout] (not prototype-only state).
///
/// [plan] is the set of exercises + target reps/weight the session started
/// with (built by `QuickStartScreen`, reusing the same exercise-picking
/// flow `LogStrengthScreen` already has). Only sets actually tapped as done
/// are written to the log on finish — an honest record of what happened,
/// not what was planned.
class ActiveSessionScreen extends StatefulWidget {
  const ActiveSessionScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.plan,
    this.sessionName = 'Quick session',
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final List<ExerciseEntry> plan;
  final String sessionName;

  @override
  State<ActiveSessionScreen> createState() => _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends State<ActiveSessionScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  final Set<String> _completed = {};
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int get _totalSets => widget.plan.fold(0, (sum, e) => sum + e.sets.length);

  void _toggleSet(int exerciseIndex, int setIndex) {
    final key = '$exerciseIndex:$setIndex';
    setState(() {
      if (!_completed.add(key)) _completed.remove(key);
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit workout?'),
        content: const Text('Progress in this session will be lost — nothing has been saved yet.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (exit == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    final completedExercises = <ExerciseEntry>[];
    for (var i = 0; i < widget.plan.length; i++) {
      final exercise = widget.plan[i];
      final doneSets = <SetEntry>[
        for (var j = 0; j < exercise.sets.length; j++)
          if (_completed.contains('$i:$j')) exercise.sets[j],
      ];
      if (doneSets.isNotEmpty) {
        completedExercises.add(ExerciseEntry(exerciseName: exercise.exerciseName, sets: doneSets));
      }
    }

    final durationMinutes = (_elapsedSeconds / 60).round().clamp(1, 1 << 30);
    final volumeKg = completedExercises
        .expand((e) => e.sets)
        .fold<double>(0, (sum, s) => sum + s.reps * s.weightKg);

    try {
      await widget.workoutRepository.createStrengthWorkout(
        uid: widget.uid,
        date: DateTime.now(),
        durationMinutes: durationMinutes,
        exercises: completedExercises,
      );
    } catch (error) {
      debugPrint('Failed to save session: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save workout. Please try again.')),
      );
      setState(() => _finishing = false);
      return;
    }

    _timer?.cancel();
    if (!mounted) return;

    final elapsedSeconds = _elapsedSeconds;
    final setsCompleted = _completed.length;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionCompleteScreen(
          sessionName: widget.sessionName,
          exerciseCount: completedExercises.length,
          elapsedSeconds: elapsedSeconds,
          setsCompleted: setsCompleted,
          volumeKg: volumeKg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalSets;
    final done = _completed.length;
    final progress = total == 0 ? 0.0 : done / total;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                sessionName: widget.sessionName,
                done: done,
                total: total,
                elapsedSeconds: _elapsedSeconds,
                progress: progress,
                onExit: _confirmExit,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  itemCount: widget.plan.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, exerciseIndex) {
                    final exercise = widget.plan[exerciseIndex];
                    return GlassCard(
                      child: _ExerciseCard(
                        exercise: exercise,
                        completed: _completed,
                        exerciseIndex: exerciseIndex,
                        onToggle: _toggleSet,
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: PrimaryButton(
                  label: _finishing ? 'Saving…' : 'Finish workout',
                  onPressed: _finishing ? null : _finish,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sessionName,
    required this.done,
    required this.total,
    required this.elapsedSeconds,
    required this.progress,
    required this.onExit,
  });

  final String sessionName;
  final int done;
  final int total;
  final int elapsedSeconds;
  final double progress;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    // Sticky translucent header per the handoff: blur 22, a near-black
    // gradient scrim fading from 92% to 55% opacity, and a hairline bottom
    // border — reads as glass floating over the scrolling content beneath.
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.background.withValues(alpha: 0.92),
                AppColors.background.withValues(alpha: 0.55),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: const Border(bottom: BorderSide(color: AppColors.glassStroke)),
          ),
          child: _headerContent(context),
        ),
      ),
    );
  }

  Widget _headerContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onExit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.glassStroke),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Exit',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$done/$total sets',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(sessionName.toUpperCase(), style: AppTypography.mono()),
          const SizedBox(height: 4),
          Text(
            formatSessionDuration(elapsedSeconds),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 56,
                  color: AppColors.accentGreen,
                  shadows: [
                    Shadow(color: AppColors.accentGreen.withValues(alpha: 0.55), blurRadius: 28),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.glassFill,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.completed,
    required this.exerciseIndex,
    required this.onToggle,
  });

  final ExerciseEntry exercise;
  final Set<String> completed;
  final int exerciseIndex;
  final void Function(int exerciseIndex, int setIndex) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                exercise.exerciseName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 16),
              ),
            ),
            Text(_prescription(exercise), style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var setIndex = 0; setIndex < exercise.sets.length; setIndex++)
              _SetChip(
                set: exercise.sets[setIndex],
                done: completed.contains('$exerciseIndex:$setIndex'),
                onTap: () => onToggle(exerciseIndex, setIndex),
              ),
          ],
        ),
      ],
    );
  }

  // Derives the prescription line ("4 × 8 @ 60 kg") from the exercise's own
  // planned sets rather than any fixed program — this app has none (see
  // reconciliation decision 4 in the plan doc).
  static String _prescription(ExerciseEntry exercise) {
    if (exercise.sets.isEmpty) return '';
    final first = exercise.sets.first;
    final uniform = exercise.sets
        .every((s) => s.weightKg == first.weightKg && s.reps == first.reps);
    if (uniform) {
      return '${exercise.sets.length} × ${first.reps} @ ${_fmtWeight(first.weightKg)} kg';
    }
    return '${exercise.sets.length} sets';
  }

  static String _fmtWeight(double kg) =>
      kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
}

class _SetChip extends StatelessWidget {
  const _SetChip({required this.set, required this.done, required this.onTap});

  final SetEntry set;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${_fmtWeight(set.weightKg)}×${set.reps}';
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: done ? AppColors.accentGradient : null,
          color: done ? null : AppColors.glassFill,
          boxShadow: done
              ? [BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.45), blurRadius: 20)]
              : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: done ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }

  static String _fmtWeight(double kg) =>
      kg == kg.roundToDouble() ? kg.round().toString() : kg.toString();
}
