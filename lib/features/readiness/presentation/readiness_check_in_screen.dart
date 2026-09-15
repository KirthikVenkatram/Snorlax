import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/readiness_repository.dart';
import '../domain/readiness_entry.dart';

/// Daily readiness check-in form and result display — handoff Screen 15.
///
/// IMPORTANT: the result shown here is a deterministic, non-medical
/// heuristic — not a diagnosis or a medically validated assessment. The
/// disclaimer copy below must stay visible verbatim whenever a result is
/// shown, and the "Pain or injury today" toggle's hard-override behaviour
/// (forces red) lives entirely in `ReadinessCalculator` — untouched here.
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
        ReadinessLevel.yellow => AppColors.warningYellow,
        ReadinessLevel.red => AppColors.accentBlue,
      };

  String _levelLabel(ReadinessLevel level) => switch (level) {
        ReadinessLevel.green => 'Green — train normally',
        ReadinessLevel.yellow => 'Yellow — reduce volume or intensity',
        ReadinessLevel.red => 'Red — recovery / rest',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Readiness'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_todayEntry != null) ...[
                      GlassCard(
                        hero: true,
                        glowColor: _levelColor(_todayEntry!.result.level),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TODAY\'S RESULT',
                              style: AppTypography.mono(color: _levelColor(_todayEntry!.result.level)),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  key: const Key('readinessLevelDot'),
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: _levelColor(_todayEntry!.result.level),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: _levelColor(_todayEntry!.result.level).withValues(alpha: 0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _levelLabel(_todayEntry!.result.level),
                                    key: const Key('readinessLevelLabel'),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (_todayEntry!.result.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final note in _todayEntry!.result.notes)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    note,
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'This is not medical advice or a diagnosis — it is a simple, '
                              'self-reported wellness heuristic to help you decide how hard '
                              'to train today.',
                              key: const Key('readinessDisclaimer'),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                          Text('Daily check-in', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20)),
                          const SizedBox(height: 6),
                          const Text(
                            'Answers are self-reported and used only to compute a supportive, '
                            'non-medical readiness suggestion — not a diagnosis.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 18),
                          _StepperRow(
                            keyPrefix: 'sleepHours',
                            label: 'Sleep hours',
                            value: _sleepHours,
                            min: 0,
                            max: 12,
                            step: 0.5,
                            display: _sleepHours.toStringAsFixed(1),
                            onChanged: (v) => setState(() => _sleepHours = v),
                          ),
                          _fractionStepper(
                            keyPrefix: 'sleepConsistency',
                            label: 'Sleep consistency',
                            value: _sleepConsistency,
                            onChanged: (v) => setState(() => _sleepConsistency = v),
                          ),
                          _fractionStepper(
                            keyPrefix: 'soreness',
                            label: 'Soreness',
                            value: _soreness,
                            onChanged: (v) => setState(() => _soreness = v),
                          ),
                          _fractionStepper(
                            keyPrefix: 'fatigue',
                            label: 'Fatigue',
                            value: _fatigue,
                            onChanged: (v) => setState(() => _fatigue = v),
                          ),
                          _fractionStepper(
                            keyPrefix: 'energy',
                            label: 'Energy',
                            value: _energy,
                            onChanged: (v) => setState(() => _energy = v),
                          ),
                          _fractionStepper(
                            keyPrefix: 'recentTrainingLoad',
                            label: 'Recent training load',
                            value: _recentTrainingLoad,
                            onChanged: (v) => setState(() => _recentTrainingLoad = v),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Pain or injury today',
                                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Always forces a recovery/rest result.',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  key: const Key('painOrInjurySwitch'),
                                  value: _painOrInjury,
                                  activeThumbColor: AppColors.accentBlue,
                                  onChanged: (v) => setState(() => _painOrInjury = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _fractionStepper({
    required String keyPrefix,
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return _StepperRow(
      keyPrefix: keyPrefix,
      label: label,
      value: value,
      min: 0,
      max: 1,
      step: 0.1,
      display: '${(value * 100).round()}%',
      onChanged: onChanged,
    );
  }
}

/// A labelled progress-bar stepper with −/+ buttons — the mobile-friendly
/// stand-in for a `Slider` per the handoff spec, reshaping the same
/// state/validation the original `Slider` rows used (clamped `onChanged`
/// double in `[min, max]`), just restyled to match the glass mockup.
class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.display,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
              ),
              Text(
                display,
                key: Key('${keyPrefix}Value'),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stepButton(
                key: Key('${keyPrefix}Minus'),
                icon: Icons.remove,
                onTap: () => onChanged((value - step).clamp(min, max)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: Key('${keyPrefix}Bar'),
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _stepButton(
                key: Key('${keyPrefix}Plus'),
                icon: Icons.add,
                onTap: () => onChanged((value + step).clamp(min, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepButton({required Key key, required IconData icon, required VoidCallback onTap}) {
    return Material(
      key: key,
      color: AppColors.glassFill,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
