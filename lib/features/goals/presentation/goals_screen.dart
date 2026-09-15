import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/glass_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_label.dart';
import '../../../core/widgets/segmented_pill.dart';
import '../data/goal_repository.dart';
import '../domain/fitness_goal.dart';

/// Glass-UI rebuild of the Goals screen per handoff screen 16: a list of
/// current goals above a glass "New goal" form. Every goal shown comes from
/// [GoalRepository] — the category pills reuse [FitnessGoal.category]'s
/// real enum values rather than the mockup's placeholder labels.
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

  Future<void> _archive(FitnessGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive goal?'),
        content: Text(
          '"${goal.name}" will be archived and no longer count toward your active goals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _goals = [
        for (final existing in _goals)
          if (existing.id == goal.id)
            FitnessGoal(
              id: existing.id,
              name: existing.name,
              category: existing.category,
              status: GoalStatus.archived,
              priority: existing.priority,
              targetValue: existing.targetValue,
              unit: existing.unit,
              baselineValue: existing.baselineValue,
              currentValue: existing.currentValue,
              targetDate: existing.targetDate,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
              metadata: existing.metadata,
            )
          else
            existing,
      ];
    });

    await widget.repository.archiveGoal(widget.uid, goal.id);
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  children: [
                    Text(
                      'Goals',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 28),
                    ),
                    const SizedBox(height: 20),
                    if (_goals.isNotEmpty) ...[
                      SectionLabel('Your goals'),
                      const SizedBox(height: 12),
                      for (final goal in _goals) _GoalListItem(goal: goal, onArchive: () => _archive(goal)),
                      const SizedBox(height: 12),
                    ],
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'New goal',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 14),
                          GlassTextField(
                            fieldKey: const Key('goalNameField'),
                            label: 'Goal name',
                            controller: _nameController,
                          ),
                          const SizedBox(height: 14),
                          const Text('Category', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 6),
                          SegmentedPill<GoalCategory>(
                            key: const Key('goalCategoryPill'),
                            options: GoalCategory.values,
                            value: _category,
                            labelBuilder: (c) => _categoryLabel(c),
                            onChanged: (value) => setState(() => _category = value),
                          ),
                          if (_category == GoalCategory.primary) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Making this primary goal active archives the previous primary goal.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('goalTargetValueField'),
                                  label: 'Target value',
                                  controller: _targetValueController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GlassTextField(
                                  fieldKey: const Key('goalUnitField'),
                                  label: 'Unit',
                                  controller: _unitController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          GlassTextField(
                            fieldKey: const Key('goalPriorityField'),
                            label: 'Priority',
                            controller: _priorityController,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _targetDate == null
                                      ? 'No target date set'
                                      : 'Target date: ${_targetDate!.toIso8601String().split('T').first}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                ),
                              ),
                              TextButton(
                                onPressed: _pickTargetDate,
                                child: const Text('Pick date'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          PrimaryButton(label: 'Save goal', onPressed: _save),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _categoryLabel(GoalCategory category) => switch (category) {
      GoalCategory.primary => 'Primary',
      GoalCategory.physique => 'Physique',
      GoalCategory.performance => 'Performance',
      GoalCategory.lifestyle => 'Lifestyle',
    };

class _GoalListItem extends StatelessWidget {
  const _GoalListItem({required this.goal, required this.onArchive});

  final FitnessGoal goal;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final isArchived = goal.status == GoalStatus.archived;
    final target = goal.targetValue != null
        ? '${goal.targetValue!.toStringAsFixed(goal.targetValue! % 1 == 0 ? 0 : 1)}${goal.unit != null ? ' ${goal.unit}' : ''}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isArchived ? 0.5 : 1.0,
        child: GlassCard(
          glowColor: _StatusDot._colorFor(goal.status),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_categoryLabel(goal.category)} · ${goal.status.name}'
                      '${target != null ? ' · $target' : ''}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusDot(status: goal.status),
              if (!isArchived) ...[
                const SizedBox(width: 8),
                _ArchiveButton(
                  key: Key('goalArchiveButton_${goal.id}'),
                  onTap: onArchive,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final GoalStatus status;

  static Color _colorFor(GoalStatus status) => switch (status) {
        GoalStatus.active => AppColors.accentGreen,
        GoalStatus.paused => AppColors.accentViolet,
        GoalStatus.completed => AppColors.accentBlue,
        GoalStatus.archived => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
      ),
    );
  }
}

/// Small round glass icon button used for the archive control per the
/// handoff's list-item affordance.
class _ArchiveButton extends StatelessWidget {
  const _ArchiveButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      shape: const CircleBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.archive_outlined, size: 16, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
