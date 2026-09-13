import 'package:flutter/material.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_completion.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({
    super.key,
    required this.uid,
    required this.repository,
    required this.onChanged,
  });

  final String uid;
  final HabitRepository repository;
  final VoidCallback onChanged;

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _nameController = TextEditingController();
  HabitCadence _cadence = HabitCadence.daily;
  int _timesPerWeek = 3;

  List<Habit> _habits = [];
  HabitCompletion? _todayCompletion;
  bool _loading = true;

  /// True while a create is in flight. Guards against two rapid Save-button
  /// taps racing each other — without this, a second tap before the first
  /// `createHabit` awaits could (previously) also collide on a
  /// timestamp-derived id; now that ids come from Firestore's own auto-ID
  /// generator that specific collision can't happen, but disabling the
  /// button while a write is in flight is still the correct UX and a cheap
  /// extra safeguard against duplicate submissions in general.
  bool _creatingHabit = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final habits = await widget.repository.listHabits(widget.uid);
    final completion = await widget.repository.getCompletion(widget.uid, _today);
    if (!mounted) return;
    setState(() {
      _habits = habits;
      _todayCompletion = completion;
      _loading = false;
    });
  }

  Future<void> _createHabit() async {
    if (_creatingHabit) return; // debounce: a create is already in flight.
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creatingHabit = true);

    final habit = Habit(
      id: widget.repository.newHabitId(widget.uid),
      name: name,
      cadence: _cadence,
      timesPerWeek: _cadence == HabitCadence.weekly ? _timesPerWeek : null,
      createdAt: DateTime.now(),
    );

    setState(() {
      _habits = [habit, ..._habits];
      _nameController.clear();
    });

    try {
      await widget.repository.createHabit(widget.uid, habit);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _creatingHabit = false);
    }
  }

  Future<void> _setStatus(
    Habit habit, {
    required bool completed,
    bool excluded = false,
    ExclusionReason? reason,
  }) async {
    setState(() {
      final status = HabitEntryStatus(completed: completed, excluded: excluded, reason: reason);
      final base = _todayCompletion ?? HabitCompletion(date: _today, entries: const {});
      _todayCompletion = base.withEntry(habit.id, status);
    });
    await widget.repository.completeHabit(
      widget.uid,
      _today,
      habit.id,
      completed: completed,
      excluded: excluded,
      reason: reason,
    );
    widget.onChanged();
  }

  Future<void> _archive(Habit habit) async {
    setState(() {
      _habits = _habits.where((h) => h.id != habit.id).toList();
    });
    await widget.repository.archiveHabit(widget.uid, habit.id);
    widget.onChanged();
  }

  Future<void> _pickExclusionReason(Habit habit) async {
    final reason = await showModalBottomSheet<ExclusionReason>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reason in ExclusionReason.values)
              ListTile(
                title: Text(_reasonLabel(reason)),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );
    if (reason == null) return;
    await _setStatus(habit, completed: false, excluded: true, reason: reason);
  }

  String _reasonLabel(ExclusionReason reason) => switch (reason) {
        ExclusionReason.illness => 'Illness',
        ExclusionReason.injury => 'Injury',
        ExclusionReason.plannedRest => 'Planned rest',
        ExclusionReason.travel => 'Travel',
        ExclusionReason.scheduleChange => 'Schedule change',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text('Today', style: textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  if (_habits.isEmpty)
                    const Text('No habits yet. Add one below to start tracking.')
                  else
                    for (final habit in _habits)
                      _HabitListItem(
                        habit: habit,
                        status: _todayCompletion?.entries[habit.id],
                        onComplete: () => _setStatus(habit, completed: true),
                        onUncomplete: () => _setStatus(habit, completed: false),
                        onExclude: () => _pickExclusionReason(habit),
                        onArchive: () => _archive(habit),
                      ),
                  const SizedBox(height: 24),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('New habit', style: textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('habitNameField'),
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Habit name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<HabitCadence>(
                          key: const Key('habitCadenceDropdown'),
                          initialValue: _cadence,
                          decoration: const InputDecoration(labelText: 'Cadence'),
                          items: [
                            for (final cadence in HabitCadence.values)
                              DropdownMenuItem(value: cadence, child: Text(cadence.name)),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _cadence = value);
                          },
                        ),
                        if (_cadence == HabitCadence.weekly) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: const Key('habitTimesPerWeekDropdown'),
                            initialValue: _timesPerWeek,
                            decoration: const InputDecoration(labelText: 'Times per week'),
                            items: [
                              for (var i = 1; i <= 7; i++)
                                DropdownMenuItem(value: i, child: Text('$i')),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _timesPerWeek = value);
                            },
                          ),
                        ],
                        const SizedBox(height: 24),
                        PrimaryButton(
                          label: 'Save habit',
                          onPressed: _creatingHabit ? null : _createHabit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  const _HabitListItem({
    required this.habit,
    required this.status,
    required this.onComplete,
    required this.onUncomplete,
    required this.onExclude,
    required this.onArchive,
  });

  final Habit habit;
  final HabitEntryStatus? status;
  final VoidCallback onComplete;
  final VoidCallback onUncomplete;
  final VoidCallback onExclude;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final completed = status?.completed ?? false;
    final excluded = status?.excluded ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    excluded ? 'Excluded today' : (completed ? 'Completed today' : 'Not yet today'),
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('habitCompleteButton_${habit.id}'),
              icon: Icon(completed ? Icons.check_circle : Icons.check_circle_outline),
              onPressed: completed ? onUncomplete : onComplete,
            ),
            IconButton(
              key: Key('habitExcludeButton_${habit.id}'),
              icon: const Icon(Icons.event_busy_outlined),
              onPressed: onExclude,
            ),
            IconButton(
              key: Key('habitArchiveButton_${habit.id}'),
              icon: const Icon(Icons.archive_outlined),
              onPressed: onArchive,
            ),
          ],
        ),
      ),
    );
  }
}
