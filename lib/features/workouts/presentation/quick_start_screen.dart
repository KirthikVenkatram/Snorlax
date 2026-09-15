import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';
import 'active_session_screen.dart';
import 'exercise_picker.dart';

/// Builds the set of exercises (+ target sets/reps/weight) for an ad-hoc
/// session, then hands off to [ActiveSessionScreen] to run it. Reuses
/// [ExercisePicker] — the same exercise-picking flow `LogStrengthScreen`
/// already has — rather than a second picker UI (plan doc, Slice B: "pick
/// whichever fits the existing screen's structure with the least new UI").
class QuickStartScreen extends StatefulWidget {
  const QuickStartScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;

  @override
  State<QuickStartScreen> createState() => _QuickStartScreenState();
}

class _QuickStartScreenState extends State<QuickStartScreen> {
  final List<_PlannedExercise> _exercises = [];

  void _addExercise(Exercise exercise) {
    Navigator.of(context).pop();
    setState(() => _exercises.add(_PlannedExercise(name: exercise.name)));
  }

  void _openExercisePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Add exercise')),
          body: ExercisePicker(
            uid: widget.uid,
            repository: widget.exerciseRepository,
            onSelected: _addExercise,
          ),
        ),
      ),
    );
  }

  void _start() {
    final plan = [
      for (final exercise in _exercises)
        ExerciseEntry(
          exerciseName: exercise.name,
          sets: List.generate(
            exercise.setCount,
            (_) => SetEntry(reps: exercise.reps, weightKg: exercise.weightKg),
          ),
        ),
    ];

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          uid: widget.uid,
          workoutRepository: widget.workoutRepository,
          plan: plan,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quick start')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Add exercises and their target sets — tap Start session when ready.'),
            const SizedBox(height: 16),
            for (final exercise in _exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: _PlannedExerciseEditor(
                    exercise: exercise,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
            OutlinedButton(
              onPressed: _openExercisePicker,
              child: const Text('Add exercise'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Start session',
              onPressed: _exercises.isEmpty ? null : _start,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlannedExercise {
  _PlannedExercise({required this.name});

  final String name;
  int setCount = 3;
  int reps = 8;
  double weightKg = 20;
}

class _PlannedExerciseEditor extends StatelessWidget {
  const _PlannedExerciseEditor({required this.exercise, required this.onChanged});

  final _PlannedExercise exercise;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exercise.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: exercise.setCount.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sets'),
                onChanged: (v) {
                  exercise.setCount = int.tryParse(v) ?? exercise.setCount;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: exercise.reps.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Reps'),
                onChanged: (v) {
                  exercise.reps = int.tryParse(v) ?? exercise.reps;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: exercise.weightKg.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                onChanged: (v) {
                  exercise.weightKg = double.tryParse(v) ?? exercise.weightKg;
                  onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
