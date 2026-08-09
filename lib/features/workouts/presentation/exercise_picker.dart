// lib/features/workouts/presentation/exercise_picker.dart
import 'package:flutter/material.dart';
import '../data/exercise_library_repository.dart';
import '../domain/exercise.dart';

class ExercisePicker extends StatefulWidget {
  const ExercisePicker({
    super.key,
    required this.uid,
    required this.repository,
    required this.onSelected,
  });

  final String uid;
  final ExerciseLibraryRepository repository;
  final ValueChanged<Exercise> onSelected;

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  final _controller = TextEditingController();
  List<Exercise> _results = [];

  Future<void> _search(String query) async {
    final results = await widget.repository.search(widget.uid, query);
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _addCustom(String name) async {
    final exercise = await widget.repository.addCustom(widget.uid, name);
    widget.onSelected(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim();
    final hasExactMatch =
        _results.any((e) => e.name.toLowerCase() == query.toLowerCase());

    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: 'Search exercises'),
            onChanged: _search,
          ),
          Expanded(
            child: ListView(
              children: [
                for (final exercise in _results)
                  ListTile(
                    title: Text(exercise.name),
                    onTap: () => widget.onSelected(exercise),
                  ),
                if (query.isNotEmpty && !hasExactMatch)
                  ListTile(
                    title: Text('Add "$query"'),
                    onTap: () => _addCustom(query),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
