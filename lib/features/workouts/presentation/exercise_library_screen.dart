import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/exercise_library_repository.dart';
import '../domain/exercise.dart';

/// A live-updating browse view over the user's whole exercise library.
///
/// Unlike [ExercisePicker] (which resolves a one-off `Future` per keystroke
/// via [ExerciseLibraryRepository.search]), this screen subscribes to
/// [ExerciseLibraryRepository.watchAll] and filters the streamed list
/// client-side, so it reflects custom exercises added from another device
/// or flow without needing a manual refresh.
class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final ExerciseLibraryRepository repository;

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  final _controller = TextEditingController();
  String _query = '';
  late final Stream<List<Exercise>> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = widget.repository.watchAll(widget.uid);
    _controller.addListener(() {
      setState(() => _query = _controller.text.trim());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addCustom(String name) async {
    await widget.repository.addCustom(widget.uid, name);
    if (!mounted) return;
    // Deliberately leave the search text in place (rather than clearing it):
    // the live `watchAll` stream now includes the new exercise, so the
    // still-active filter narrows straight to the one just added.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added "$name" to your library.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(labelText: 'Search exercises'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Exercise>>(
                  stream: _exercises,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final normalizedQuery = _query.toLowerCase();
                    final filtered = snapshot.data!
                        .where((e) => e.name.toLowerCase().contains(normalizedQuery))
                        .toList();
                    final hasExactMatch = filtered
                        .any((e) => e.name.toLowerCase() == normalizedQuery);

                    if (filtered.isEmpty && _query.isEmpty) {
                      return const Center(child: Text('No exercises yet.'));
                    }

                    return ListView.separated(
                      itemCount: filtered.length + (_query.isNotEmpty && !hasExactMatch ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index >= filtered.length) {
                          return GlassCard(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                title: Text('Add "$_query"'),
                                leading: const Icon(Icons.add),
                                onTap: () => _addCustom(_query),
                              ),
                            ),
                          );
                        }
                        final exercise = filtered[index];
                        return GlassCard(
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              title: Text(exercise.name),
                              trailing: exercise.isCustom
                                  ? const Text('Custom', style: TextStyle(fontSize: 12))
                                  : null,
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
}
