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
  String? _durationError;

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

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

  void _save() {
    final durationMinutes = int.tryParse(_durationController.text.trim());
    if (durationMinutes == null || durationMinutes <= 0) {
      setState(() => _durationError = 'Enter a duration in whole minutes.');
      return;
    }

    setState(() => _durationError = null);

    final messenger = ScaffoldMessenger.of(context);

    final exercises = [
      for (final draft in _exercises)
        ExerciseEntry(
          exerciseName: draft.exerciseName,
          sets: draft.sets
              .map((s) => SetEntry(reps: s.reps, weightKg: s.weightKg))
              .toList(),
        ),
    ];

    // Deliberately not awaited: Firestore applies the write to its local
    // cache immediately, but the returned Future only completes once the
    // server acknowledges it — which never happens while offline. Blocking
    // the UI on it would leave the user on a permanent spinner even though
    // the data is safely queued. Failures are reported asynchronously.
    widget.workoutRepository
        .createStrengthWorkout(
          uid: widget.uid,
          date: DateTime.now(),
          durationMinutes: durationMinutes,
          exercises: exercises,
        )
        .then<void>((_) {}, onError: (Object error) {
      debugPrint('Failed to save strength workout: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save workout. Please try again.')),
      );
    });

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
              decoration: InputDecoration(
                labelText: 'Duration (minutes)',
                errorText: _durationError,
              ),
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
            PrimaryButton(
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
