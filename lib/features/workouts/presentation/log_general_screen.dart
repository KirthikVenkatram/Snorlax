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
  String? _durationError;

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    final durationMinutes = int.tryParse(_durationController.text.trim());
    if (durationMinutes == null || durationMinutes <= 0) {
      setState(() => _durationError = 'Enter a duration in whole minutes.');
      return;
    }

    setState(() => _durationError = null);

    final messenger = ScaffoldMessenger.of(context);

    // Deliberately not awaited — see the note in LogStrengthScreen._save:
    // Firestore's write Future doesn't complete until the server acks, so
    // awaiting it strands offline users on a spinner.
    widget.workoutRepository
        .createGeneralWorkout(
          uid: widget.uid,
          date: DateTime.now(),
          durationMinutes: durationMinutes,
          notes: _notesController.text,
        )
        .then<void>((_) {}, onError: (Object error) {
      debugPrint('Failed to save general workout: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not save workout. Please try again.')),
      );
    });

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
                  decoration: InputDecoration(
                    labelText: 'Duration (minutes)',
                    errorText: _durationError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Save workout', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
