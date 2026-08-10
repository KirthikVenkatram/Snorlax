import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';
import 'exercise_progress_screen.dart';

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

  bool get _isEditable => widget.workout.source == WorkoutSource.manual;

  Future<void> _save() async {
    final durationMinutes = int.parse(_durationController.text);
    if (widget.workout.type == WorkoutType.general) {
      await widget.workoutRepository.updateGeneralWorkout(
        uid: widget.uid,
        workoutId: widget.workout.id,
        durationMinutes: durationMinutes,
        notes: _notesController.text,
      );
    } else if (widget.workout.type == WorkoutType.strength) {
      await widget.workoutRepository.updateStrengthWorkout(
        uid: widget.uid,
        workoutId: widget.workout.id,
        durationMinutes: durationMinutes,
      );
    }
    if (!mounted) return;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.workoutRepository.deleteWorkout(widget.uid, widget.workout.id);
    if (!mounted) return;
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
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
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
                          '${exercise.exerciseName}: ${exercise.sets.map((s) => '${s.reps}x${s.weightKg}kg').join(', ')}',
                        ),
                      ),
                    ),
                if (workout.type == WorkoutType.cardio) ...[
                  const SizedBox(height: 12),
                  Text('Distance: ${workout.distanceKm ?? '-'} km'),
                  Text('Pace: ${workout.paceMinPerKm ?? '-'} min/km'),
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
