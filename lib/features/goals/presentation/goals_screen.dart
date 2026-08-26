import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/goal_repository.dart';
import '../domain/fitness_goal.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.uid,
    required this.repository,
    required this.onChanged,
  });

  final String uid;
  final GoalRepository repository;
  final VoidCallback onChanged;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _nameController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _unitController = TextEditingController();
  final _priorityController = TextEditingController(text: '1');

  GoalCategory _category = GoalCategory.physique;
  DateTime? _targetDate;
  List<FitnessGoal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetValueController.dispose();
    _unitController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    final goals = await widget.repository.listGoals(widget.uid);
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _loading = false;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final now = DateTime.now();
    final goal = FitnessGoal(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      category: _category,
      status: GoalStatus.active,
      priority: int.tryParse(_priorityController.text.trim()) ?? 1,
      targetValue: double.tryParse(_targetValueController.text.trim()),
      unit: _unitController.text.trim().isEmpty ? null : _unitController.text.trim(),
      targetDate: _targetDate,
      createdAt: now,
      updatedAt: now,
    );

    // Optimistically reflect the new goal in the list right away, since the
    // write below is fire-and-forget (see note in _save's write below).
    setState(() {
      _goals = [goal, ..._goals];
      _nameController.clear();
      _targetValueController.clear();
      _unitController.clear();
      _priorityController.text = '1';
      _targetDate = null;
      _category = GoalCategory.physique;
    });

    // Deliberately not awaited: Firestore's offline persistence updates the
    // local cache immediately but the returned Future doesn't resolve until
    // the server acks, which never happens offline — awaiting it here would
    // leave this screen spinning indefinitely with no connectivity.
    widget.repository
        .createGoal(widget.uid, goal)
        .then((_) {}, onError: (Object error) => debugPrint('Failed to save goal: $error'));

    widget.onChanged();
  }

  Future<void> _pickTargetDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _targetDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_goals.isNotEmpty) ...[
                    Text('Your goals', style: textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    for (final goal in _goals) _GoalListItem(goal: goal),
                    const SizedBox(height: 24),
                  ],
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('New goal', style: textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('goalNameField'),
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Goal name'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<GoalCategory>(
                          key: const Key('goalCategoryDropdown'),
                          initialValue: _category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: [
                            for (final category in GoalCategory.values)
                              DropdownMenuItem(value: category, child: Text(category.name)),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _category = value);
                          },
                        ),
                        if (_category == GoalCategory.primary) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Making this primary goal active archives the previous primary goal.',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('goalTargetValueField'),
                          controller: _targetValueController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Target value (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('goalUnitField'),
                          controller: _unitController,
                          decoration: const InputDecoration(labelText: 'Unit (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('goalPriorityField'),
                          controller: _priorityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Priority'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _targetDate == null
                                    ? 'No target date set'
                                    : 'Target date: ${_targetDate!.toIso8601String().split('T').first}',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: _pickTargetDate,
                              child: const Text('Pick date'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(label: 'Save goal', onPressed: _save),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GoalListItem extends StatelessWidget {
  const _GoalListItem({required this.goal});

  final FitnessGoal goal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.name, style: textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    '${goal.category.name} • ${goal.status.name}',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _StatusDot(status: goal.status),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      GoalStatus.active => AppColors.accentGreen,
      GoalStatus.paused => AppColors.accentViolet,
      GoalStatus.completed => AppColors.accentBlue,
      GoalStatus.archived => AppColors.textSecondary,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
