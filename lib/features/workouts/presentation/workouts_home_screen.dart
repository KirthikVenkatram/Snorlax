import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../strava/data/strava_connection_repository.dart';
import '../../strava/presentation/strava_connect_banner.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'exercise_library_screen.dart';
import 'log_general_screen.dart';
import 'log_strength_screen.dart';
import 'workout_detail_screen.dart';

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

  Future<void> _showLogOptions() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    if (choice == 'strength') await _openLogStrength();
    if (choice == 'general') await _openLogGeneral();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Exercise library',
            onPressed: _openExerciseLibrary,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLogOptions,
        tooltip: 'Log a workout',
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StravaConnectBanner(uid: widget.uid, repository: widget.stravaRepository),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Workout>>(
                  future: _workoutsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final workouts = snapshot.data!;
                    if (workouts.isEmpty) {
                      return const Center(child: Text('No workouts logged yet.'));
                    }
                    return ListView.separated(
                      itemCount: workouts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final workout = workouts[index];
                        return GlassCard(
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(_titleFor(workout)),
                              subtitle: Text(
                                '${workout.date.year}-${workout.date.month.toString().padLeft(2, '0')}-${workout.date.day.toString().padLeft(2, '0')} · ${workout.durationMinutes} min',
                              ),
                              onTap: () async {
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
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _titleFor(Workout workout) {
    switch (workout.type) {
      case WorkoutType.strength:
        return 'Strength · ${workout.exercises?.length ?? 0} exercises';
      case WorkoutType.cardio:
        return 'Cardio (Strava)';
      case WorkoutType.general:
        return workout.notes?.isNotEmpty == true ? workout.notes! : 'Workout';
    }
  }
}
