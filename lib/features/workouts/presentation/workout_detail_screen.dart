import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'exercise_progress_screen.dart';

/// Formats a double for display, dropping the decimal part when it adds
/// nothing (`5.0` -> `5`, `4.75` -> `4.75`) and rendering `-` for nulls.
String _formatNumber(double? value, {int decimals = 1}) {
  if (value == null) return '-';
  final fixed = value.toStringAsFixed(decimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.uid,
    required this.workout,
    required this.workoutRepository,
    required this.onChanged,
  });

  final String uid;
  final Workout workout;
  final WorkoutRepository workoutRepository;
  final VoidCallback onChanged;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late final _durationController =
      TextEditingController(text: widget.workout.durationMinutes.toString());
  late final _notesController = TextEditingController(text: widget.workout.notes ?? '');

  String? _durationError;

  bool get _isEditable => widget.workout.source == WorkoutSource.manual;

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Captured before popping, so a failure that surfaces after this screen is
  /// gone can still be reported (the app-level messenger outlives the route).
  ScaffoldMessengerState? _messenger;

  /// Reports a failed write once it eventually fails, without blocking the UI
  /// flow on the write completing (see [_save]).
  void _reportFailure(Future<void> write, String action) {
    write.then<void>((_) {}, onError: (Object error) {
      debugPrint('Failed to $action workout: $error');
      _messenger?.showSnackBar(
        SnackBar(content: Text('Could not $action workout. Please try again.')),
      );
    });
  }

  void _save() {
    final durationMinutes = int.tryParse(_durationController.text.trim());
    if (durationMinutes == null || durationMinutes <= 0) {
      setState(() => _durationError = 'Enter a duration in whole minutes.');
      return;
    }
    setState(() => _durationError = null);

    _messenger = ScaffoldMessenger.of(context);

    // Deliberately not awaited: Firestore's write Future doesn't complete
    // until the server acknowledges it, so awaiting would hang the screen
    // while offline even though the local cache is already updated.
    if (widget.workout.type == WorkoutType.general) {
      _reportFailure(
        widget.workoutRepository.updateGeneralWorkout(
          uid: widget.uid,
          workoutId: widget.workout.id,
          durationMinutes: durationMinutes,
          notes: _notesController.text,
        ),
        'save',
      );
    } else if (widget.workout.type == WorkoutType.strength) {
      _reportFailure(
        widget.workoutRepository.updateStrengthWorkout(
          uid: widget.uid,
          workoutId: widget.workout.id,
          durationMinutes: durationMinutes,
        ),
        'save',
      );
    }

    widget.onChanged();
    Navigator.of(context).pop();
  }

  void _delete() {
    _messenger = ScaffoldMessenger.of(context);
    _reportFailure(
      widget.workoutRepository.deleteWorkout(widget.uid, widget.workout.id),
      'delete',
    );
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout detail'),
        actions: [
          if (_isEditable)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${workout.type.name} · ${workout.source.name}'),
                const SizedBox(height: 12),
                TextField(
                  controller: _durationController,
                  enabled: _isEditable,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Duration (minutes)',
                    errorText: _durationError,
                  ),
                ),
                if (workout.type == WorkoutType.general) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    enabled: _isEditable,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
                if (workout.type == WorkoutType.strength)
                  for (final exercise in workout.exercises ?? [])
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExerciseProgressScreen(
                                uid: widget.uid,
                                exerciseName: exercise.exerciseName,
                                workoutRepository: widget.workoutRepository,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          '${exercise.exerciseName}: '
                          '${exercise.sets.map((s) => '${s.reps}x${_formatNumber(s.weightKg)}kg').join(', ')}',
                        ),
                      ),
                    ),
                if (workout.type == WorkoutType.cardio) ...[
                  const SizedBox(height: 12),
                  Text('Distance: ${_formatNumber(workout.distanceKm, decimals: 2)} km'),
                  Text('Pace: ${_formatNumber(workout.paceMinPerKm, decimals: 2)} min/km'),
                ],
                if (_isEditable) ...[
                  const SizedBox(height: 24),
                  PrimaryButton(label: 'Save changes', onPressed: _save),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
