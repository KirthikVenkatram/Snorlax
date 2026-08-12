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

  /// Incremented per search; a response is only applied if it belongs to the
  /// most recent request, so a slow early query can't clobber a newer one.
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    // Show the whole library up front rather than an empty list.
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final token = ++_searchToken;
    try {
      final results = await widget.repository.search(widget.uid, query);
      if (!mounted || token != _searchToken) return;
      setState(() => _results = results);
    } catch (error) {
      debugPrint('Exercise search failed: $error');
    }
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
