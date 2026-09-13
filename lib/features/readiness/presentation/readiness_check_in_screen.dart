import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/readiness_repository.dart';
import '../domain/readiness_entry.dart';

/// Daily readiness check-in form and result display.
///
/// IMPORTANT: the result shown here is a deterministic, non-medical
/// heuristic — not a diagnosis or a medically validated assessment. The
/// disclaimer copy below must stay visible whenever a result is shown.
class ReadinessCheckInScreen extends StatefulWidget {
  const ReadinessCheckInScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final ReadinessRepository repository;

  @override
  State<ReadinessCheckInScreen> createState() => _ReadinessCheckInScreenState();
}

class _ReadinessCheckInScreenState extends State<ReadinessCheckInScreen> {
  double _sleepHours = 7;
  double _sleepConsistency = 0.7;
  double _soreness = 0.3;
  double _fatigue = 0.3;
  double _energy = 0.7;
  double _recentTrainingLoad = 0.4;
  bool _painOrInjury = false;

  ReadinessEntry? _todayEntry;
  bool _loading = true;
  bool _saving = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = await widget.repository.getByDate(widget.uid, _today);
    if (!mounted) return;
    setState(() {
      _todayEntry = entry;
      if (entry != null) {
        _sleepHours = entry.inputs.sleepHours;
        _sleepConsistency = entry.inputs.sleepConsistency;
        _soreness = entry.inputs.soreness;
        _fatigue = entry.inputs.fatigue;
        _energy = entry.inputs.energy;
        _recentTrainingLoad = entry.inputs.recentTrainingLoad;
        _painOrInjury = entry.inputs.painOrInjury;
      }
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final inputs = ReadinessInputs(
      sleepHours: _sleepHours,
      sleepConsistency: _sleepConsistency,
      soreness: _soreness,
      fatigue: _fatigue,
      energy: _energy,
      recentTrainingLoad: _recentTrainingLoad,
      painOrInjury: _painOrInjury,
    );
    final entry = await widget.repository.recordCheckIn(widget.uid, _today, inputs);
    if (!mounted) return;
    setState(() {
      _todayEntry = entry;
      _saving = false;
    });
  }

  Color _levelColor(ReadinessLevel level) => switch (level) {
        ReadinessLevel.green => AppColors.accentGreen,
        ReadinessLevel.yellow => AppColors.accentAmber,
        ReadinessLevel.red => AppColors.error,
      };

  String _levelLabel(ReadinessLevel level) => switch (level) {
        ReadinessLevel.green => 'Green — train normally',
        ReadinessLevel.yellow => 'Yellow — reduce volume or intensity',
        ReadinessLevel.red => 'Red — recovery / rest',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Readiness')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (_todayEntry != null) ...[
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Today\'s result', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _levelColor(_todayEntry!.result.level),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _levelLabel(_todayEntry!.result.level),
                                  style: textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (final note in _todayEntry!.result.notes)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(note, style: textTheme.bodyMedium),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            'This is not medical advice or a diagnosis — it is a simple, '
                            'self-reported wellness heuristic to help you decide how hard '
                            'to train today.',
                            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Daily check-in', style: textTheme.headlineMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Answers are self-reported and used only to compute a supportive, '
                          'non-medical readiness suggestion — not a diagnosis.',
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        _slider(
                          key: const Key('sleepHoursSlider'),
                          label: 'Sleep hours',
                          value: _sleepHours,
                          min: 0,
                          max: 12,
                          display: _sleepHours.toStringAsFixed(1),
                          onChanged: (v) => setState(() => _sleepHours = v),
                        ),
                        _fractionSlider(
                          key: const Key('sleepConsistencySlider'),
                          label: 'Sleep consistency',
                          value: _sleepConsistency,
                          onChanged: (v) => setState(() => _sleepConsistency = v),
                        ),
                        _fractionSlider(
                          key: const Key('sorenessSlider'),
                          label: 'Soreness',
                          value: _soreness,
                          onChanged: (v) => setState(() => _soreness = v),
                        ),
                        _fractionSlider(
                          key: const Key('fatigueSlider'),
                          label: 'Fatigue',
                          value: _fatigue,
                          onChanged: (v) => setState(() => _fatigue = v),
                        ),
                        _fractionSlider(
                          key: const Key('energySlider'),
                          label: 'Energy',
                          value: _energy,
                          onChanged: (v) => setState(() => _energy = v),
                        ),
                        _fractionSlider(
                          key: const Key('recentTrainingLoadSlider'),
                          label: 'Recent training load',
                          value: _recentTrainingLoad,
                          onChanged: (v) => setState(() => _recentTrainingLoad = v),
                        ),
                        SwitchListTile(
                          key: const Key('painOrInjurySwitch'),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pain or injury today'),
                          subtitle: const Text('Always forces a recovery/rest result.'),
                          value: _painOrInjury,
                          onChanged: (v) => setState(() => _painOrInjury = v),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: _saving ? 'Saving...' : 'Save check-in',
                          onPressed: _saving ? null : _submit,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _fractionSlider({
    required Key key,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return _slider(
      key: key,
      label: label,
      value: value,
      min: 0,
      max: 1,
      display: '${(value * 100).round()}%',
      onChanged: onChanged,
    );
  }

  Widget _slider({
    required Key key,
    required String label,
    required double value,
    required double min,
    required double max,
    required String display,
    required ValueChanged<double> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $display', style: textTheme.bodyMedium),
          Slider(key: key, value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}
