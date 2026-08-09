// lib/features/workouts/presentation/log_strength_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout.dart';
import 'exercise_picker.dart';

class LogStrengthScreen extends StatefulWidget {
  const LogStrengthScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.exerciseRepository,
    required this.onSaved,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final ExerciseLibraryRepository exerciseRepository;
  final VoidCallback onSaved;

  @override
  State<LogStrengthScreen> createState() => _LogStrengthScreenState();
}

class _LogStrengthScreenState extends State<LogStrengthScreen> {
  final _durationController = TextEditingController(text: '45');
  final List<_ExerciseDraft> _exercises = [];
  bool _saving = false;

  void _addExercise(Exercise exercise) {
    Navigator.of(context).pop();
    setState(() => _exercises.add(_ExerciseDraft(exerciseName: exercise.name)));
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

  Future<void> _save() async {
    setState(() => _saving = true);

    final exercises = [
      for (final draft in _exercises)
        ExerciseEntry(
          exerciseName: draft.exerciseName,
          sets: draft.sets
              .map((s) => SetEntry(reps: s.reps, weightKg: s.weightKg))
              .toList(),
        ),
    ];

    await widget.workoutRepository.createStrengthWorkout(
      uid: widget.uid,
      date: DateTime.now(),
      durationMinutes: int.parse(_durationController.text),
      exercises: exercises,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log strength workout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            ),
            const SizedBox(height: 16),
            for (final draft in _exercises)
              GlassCard(
                child: _ExerciseDraftEditor(
                  draft: draft,
                  onChanged: () => setState(() {}),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _openExercisePicker,
              child: const Text('Add exercise'),
            ),
            const SizedBox(height: 24),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : PrimaryButton(
                    label: 'Save workout',
                    onPressed: _exercises.isEmpty ? null : _save,
                  ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({required this.exerciseName});

  final String exerciseName;
  final List<_SetDraft> sets = [_SetDraft()];
}

class _SetDraft {
  int reps = 5;
  double weightKg = 20;
}

class _ExerciseDraftEditor extends StatelessWidget {
  const _ExerciseDraftEditor({required this.draft, required this.onChanged});

  final _ExerciseDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(draft.exerciseName, style: Theme.of(context).textTheme.headlineMedium),
        for (final set in draft.sets)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: set.reps.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Reps'),
                  onChanged: (v) {
                    set.reps = int.tryParse(v) ?? set.reps;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: set.weightKg.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Weight (kg)'),
                  onChanged: (v) {
                    set.weightKg = double.tryParse(v) ?? set.weightKg;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        TextButton(
          onPressed: () {
            draft.sets.add(_SetDraft());
            onChanged();
          },
          child: const Text('Add set'),
        ),
      ],
    );
  }
}
