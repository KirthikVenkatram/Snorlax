// lib/features/workouts/presentation/log_general_screen.dart
import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/workout_repository.dart';

class LogGeneralScreen extends StatefulWidget {
  const LogGeneralScreen({
    super.key,
    required this.uid,
    required this.workoutRepository,
    required this.onSaved,
  });

  final String uid;
  final WorkoutRepository workoutRepository;
  final VoidCallback onSaved;

  @override
  State<LogGeneralScreen> createState() => _LogGeneralScreenState();
}

class _LogGeneralScreenState extends State<LogGeneralScreen> {
  final _durationController = TextEditingController(text: '30');
  final _notesController = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);

    await widget.workoutRepository.createGeneralWorkout(
      uid: widget.uid,
      date: DateTime.now(),
      durationMinutes: int.parse(_durationController.text),
      notes: _notesController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log workout')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 24),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : PrimaryButton(label: 'Save workout', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
