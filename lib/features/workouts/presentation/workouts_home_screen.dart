import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pressable.dart';
import '../../strava/data/strava_connection_repository.dart';
import '../../strava/presentation/strava_connect_banner.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'exercise_library_screen.dart';
import 'log_general_screen.dart';
import 'log_strength_screen.dart';
import 'quick_start_screen.dart';
import 'workout_detail_screen.dart';

/// Workouts tab — handoff Screen 3. The mockup shows a fixed weekly program
/// ("Push Day A" / "Pull Day B" / "Leg Day"); this app has no such concept,
/// so the row STYLING is matched exactly (type chip + duration, bold name,
/// detail line, gradient pill) but every row is populated from real
/// `WorkoutRepository.listWorkouts` history, newest first, plus a real
/// "Quick start" entry point at the top. See plan doc, Group C item 1, and
/// the reconciliation note logged in ISSUES.md for the calls made below.
class WorkoutsHomeScreen extends StatefulWidget {
  const WorkoutsHomeScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
    required this.stravaRepository,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;
  final StravaConnectionRepository stravaRepository;

  @override
  State<WorkoutsHomeScreen> createState() => _WorkoutsHomeScreenState();
}

class _WorkoutsHomeScreenState extends State<WorkoutsHomeScreen> {
  late Future<List<Workout>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget, but never unhandled: a failure here only means the
    // default exercise library isn't pre-populated, which the picker's
    // add-custom flow works around.
    widget.exerciseRepository.seedDefaultsIfEmpty(widget.uid).catchError((Object error) {
      debugPrint('Failed to seed default exercises: $error');
    });
    _refresh();
  }

  void _refresh() {
    setState(() {
      _workoutsFuture = widget.workoutRepository.listWorkouts(widget.uid);
    });
  }

  Future<void> _openLogStrength() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogStrengthScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          exerciseRepository: widget.exerciseRepository,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  void _openExerciseLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseLibraryScreen(
          uid: widget.uid,
          repository: widget.exerciseRepository,
        ),
      ),
    );
  }

  Future<void> _openLogGeneral() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogGeneralScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          onSaved: () {
            Navigator.of(context).pop();
            _refresh();
          },
        ),
      ),
    );
  }

  Future<void> _openQuickStart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickStartScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          exerciseRepository: widget.exerciseRepository,
        ),
      ),
    );
    // The pushed flow (QuickStart -> ActiveSession -> SessionComplete) uses
    // pushReplacement throughout and may have written a new workout before
    // returning here — refresh regardless of how the user got back.
    if (mounted) _refresh();
  }

  Future<void> _openWorkout(Workout workout) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          uid: widget.uid,
          workout: workout,
          workoutRepository: widget.workoutRepository,
          onChanged: _refresh,
        ),
      ),
    );
  }

  Future<void> _showLogOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Quick start'),
              subtitle: const Text('Run a timed session with set-completion tracking'),
              onTap: () => Navigator.of(sheetContext).pop('quick-start'),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text('Log strength workout'),
              onTap: () => Navigator.of(sheetContext).pop('strength'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Log general workout'),
              onTap: () => Navigator.of(sheetContext).pop('general'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'quick-start') await _openQuickStart();
    if (choice == 'strength') await _openLogStrength();
    if (choice == 'general') await _openLogGeneral();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showLogOptions,
        tooltip: 'Log a workout',
        child: const Icon(Icons.add),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Workouts',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Everything you’ve logged, plus a quick way to start.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.list_alt, color: AppColors.textSecondary),
                          tooltip: 'Exercise library',
                          onPressed: _openExerciseLibrary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StravaConnectBanner(uid: widget.uid, repository: widget.stravaRepository),
                    const SizedBox(height: 12),
                    _QuickStartRow(onTap: _openQuickStart),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Workout>>(
                      future: _workoutsFuture,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final workouts = snapshot.data!;
                        if (workouts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('No workouts logged yet.'),
                          );
                        }
                        return Column(
                          children: [
                            for (final workout in workouts) ...[
                              _WorkoutRow(workout: workout, onTap: () => _openWorkout(workout)),
                              const SizedBox(height: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The real entry point standing in for the mockup's fixed program — starts
/// the same `QuickStartScreen` flow the FAB's "Quick start" option does.
class _QuickStartRow extends StatelessWidget {
  const _QuickStartRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick start',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Build a session on the fly and start the timer.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StartPill(label: 'Start', onTap: onTap),
          ],
        ),
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.workout, required this.onTap});

  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detail = _detailFor(workout);
    return Pressable(
      onTap: onTap,
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _TypeChip(type: workout.type),
                      const SizedBox(width: 8),
                      Text(
                        '${workout.durationMinutes} min',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nameFor(workout),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 17),
                  ),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // "Start" in the mockup starts an upcoming program entry; these
            // rows are already-completed logs, so the pill opens the entry
            // for viewing/editing instead — same gradient-pill visual,
            // honest label. See ISSUES.md.
            _StartPill(label: 'View', onTap: onTap),
          ],
        ),
      ),
    );
  }

  static String _nameFor(Workout workout) {
    switch (workout.type) {
      case WorkoutType.strength:
        return 'Strength session';
      case WorkoutType.cardio:
        return 'Cardio session';
      case WorkoutType.general:
        return (workout.notes?.trim().isNotEmpty ?? false) ? workout.notes!.trim() : 'Workout';
    }
  }

  static String? _detailFor(Workout workout) {
    switch (workout.type) {
      case WorkoutType.strength:
        final names = workout.exercises?.map((e) => e.exerciseName).toList() ?? const [];
        return names.isEmpty ? null : names.join(' · ');
      case WorkoutType.cardio:
        final distance = workout.distanceKm;
        final pace = workout.paceMinPerKm;
        if (distance == null && pace == null) return null;
        final parts = <String>[
          if (distance != null) '${distance.toStringAsFixed(1)} km',
          if (pace != null) '${pace.toStringAsFixed(1)} min/km',
        ];
        return parts.join(' · ');
      case WorkoutType.general:
        return null;
    }
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});

  final WorkoutType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentGreen.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: AppTypography.mono(fontSize: 10, color: AppColors.accentGreen),
      ),
    );
  }
}

class _StartPill extends StatelessWidget {
  const _StartPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: AppColors.accentGradient,
            boxShadow: [
              BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.35), blurRadius: 14),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
