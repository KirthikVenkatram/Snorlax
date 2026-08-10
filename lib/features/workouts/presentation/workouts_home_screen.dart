// lib/features/workouts/presentation/workouts_home_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'log_general_screen.dart';
import 'log_strength_screen.dart';
import 'workout_detail_screen.dart';

class WorkoutsHomeScreen extends StatefulWidget {
  const WorkoutsHomeScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;

  @override
  State<WorkoutsHomeScreen> createState() => _WorkoutsHomeScreenState();
}

class _WorkoutsHomeScreenState extends State<WorkoutsHomeScreen> {
  late Future<List<Workout>> _workoutsFuture;

  @override
  void initState() {
    super.initState();
    widget.exerciseRepository.seedDefaultsIfEmpty(widget.uid);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      floatingActionButton: PopupMenuButton<String>(
        icon: const Icon(Icons.add),
        onSelected: (value) {
          if (value == 'strength') _openLogStrength();
          if (value == 'general') _openLogGeneral();
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'strength', child: Text('Log strength workout')),
          PopupMenuItem(value: 'general', child: Text('Log general workout')),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Strava "Connect Strava" banner is inserted here by Task 11.
              const SizedBox.shrink(),
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
