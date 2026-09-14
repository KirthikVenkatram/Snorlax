import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/sleep_repository.dart';
import '../domain/sleep_entry.dart';

/// Manual sleep check-in form. Mirrors `ReadinessCheckInScreen`'s
/// load-existing/edit/save shape.
class SleepCheckInScreen extends StatefulWidget {
  const SleepCheckInScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final SleepRepository repository;

  @override
  State<SleepCheckInScreen> createState() => _SleepCheckInScreenState();
}

class _SleepCheckInScreenState extends State<SleepCheckInScreen> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);
  double _awakeMinutes = 15;
  double _score = 75;
  final _restingHrController = TextEditingController();
  final _hrvController = TextEditingController();

  bool _stagesExpanded = false;
  final _stageAwakeController = TextEditingController();
  final _stageRemController = TextEditingController();
  final _stageDeepController = TextEditingController();
  final _stageLightController = TextEditingController();

  SleepEntry? _todayEntry;
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

  @override
  void dispose() {
    _restingHrController.dispose();
    _hrvController.dispose();
    _stageAwakeController.dispose();
    _stageRemController.dispose();
    _stageDeepController.dispose();
    _stageLightController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entry = await widget.repository.getByDate(widget.uid, _today);
    if (!mounted) return;
    setState(() {
      _todayEntry = entry;
      if (entry != null) {
        _bedtime = TimeOfDay.fromDateTime(entry.bedtime);
        _wakeTime = TimeOfDay.fromDateTime(entry.wakeTime);
        _awakeMinutes = entry.awakeMinutes.toDouble();
        _score = entry.score.toDouble();
        if (entry.restingHeartRate != null) {
          _restingHrController.text = entry.restingHeartRate.toString();
        }
        if (entry.hrv != null) {
          _hrvController.text = entry.hrv.toString();
        }
        final stages = entry.stages;
        if (stages != null) {
          _stagesExpanded = true;
          _stageAwakeController.text = stages.awake.toString();
          _stageRemController.text = stages.rem.toString();
          _stageDeepController.text = stages.deep.toString();
          _stageLightController.text = stages.light.toString();
        }
      }
      _loading = false;
    });
  }

  DateTime _bedtimeDateTime() {
    // Bedtime is the evening before the wake date, unless the picked hour is
    // already past midnight (e.g. a 00:30 bedtime on a "last night" entry).
    final wakeMinutes = _wakeTime.hour * 60 + _wakeTime.minute;
    final bedMinutes = _bedtime.hour * 60 + _bedtime.minute;
    final sameDay = bedMinutes < wakeMinutes;
    final base = sameDay ? _today : _today.subtract(const Duration(days: 1));
    return DateTime(base.year, base.month, base.day, _bedtime.hour, _bedtime.minute);
  }

  DateTime _wakeDateTime() =>
      DateTime(_today.year, _today.month, _today.day, _wakeTime.hour, _wakeTime.minute);

  Future<void> _submit() async {
    setState(() => _saving = true);
    SleepStageMinutes? stages;
    if (_stagesExpanded &&
        _stageAwakeController.text.isNotEmpty &&
        _stageRemController.text.isNotEmpty &&
        _stageDeepController.text.isNotEmpty &&
        _stageLightController.text.isNotEmpty) {
      stages = SleepStageMinutes(
        awake: int.tryParse(_stageAwakeController.text) ?? 0,
        rem: int.tryParse(_stageRemController.text) ?? 0,
        deep: int.tryParse(_stageDeepController.text) ?? 0,
        light: int.tryParse(_stageLightController.text) ?? 0,
      );
    }
    final entry = await widget.repository.recordCheckIn(
      widget.uid,
      _today,
      bedtime: _bedtimeDateTime(),
      wakeTime: _wakeDateTime(),
      awakeMinutes: _awakeMinutes.round(),
      score: _score.round(),
      restingHeartRate: int.tryParse(_restingHrController.text),
      hrv: double.tryParse(_hrvController.text),
      stages: stages,
    );
    if (!mounted) return;
    setState(() {
      _todayEntry = entry;
      _saving = false;
    });
  }

  Future<void> _pickTime(bool isBedtime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isBedtime ? _bedtime : _wakeTime,
    );
    if (picked == null) return;
    setState(() => isBedtime ? _bedtime = picked : _wakeTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Sleep check-in'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_todayEntry != null) ...[
                      GlassCard(
                        glowColor: AppColors.accentViolet,
                        child: Text(
                          'Saved — ${_todayEntry!.timeAsleep.inHours}h '
                          '${_todayEntry!.timeAsleep.inMinutes % 60}m asleep, '
                          'score ${_todayEntry!.score}.',
                          style: textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Last night', style: textTheme.headlineMedium),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _TimeField(
                                  key: const Key('bedtimeField'),
                                  label: 'Bedtime',
                                  time: _bedtime,
                                  onTap: () => _pickTime(true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _TimeField(
                                  key: const Key('wakeTimeField'),
                                  label: 'Wake time',
                                  time: _wakeTime,
                                  onTap: () => _pickTime(false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _slider(
                            key: const Key('awakeMinutesSlider'),
                            label: 'Awake minutes',
                            value: _awakeMinutes,
                            min: 0,
                            max: 120,
                            display: '${_awakeMinutes.round()} min',
                            onChanged: (v) => setState(() => _awakeMinutes = v),
                          ),
                          _slider(
                            key: const Key('scoreSlider'),
                            label: 'Sleep score',
                            value: _score,
                            min: 1,
                            max: 100,
                            display: _score.round().toString(),
                            onChanged: (v) => setState(() => _score = v),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const Key('restingHrField'),
                                  controller: _restingHrController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Resting HR (bpm, optional)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const Key('hrvField'),
                                  controller: _hrvController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'HRV (ms, optional)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            key: const Key('sleepStagesExpansion'),
                            onTap: () => setState(() => _stagesExpanded = !_stagesExpanded),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(_stagesExpanded ? Icons.expand_less : Icons.expand_more),
                                  const SizedBox(width: 8),
                                  const Text('Add sleep stages'),
                                ],
                              ),
                            ),
                          ),
                          if (_stagesExpanded) ...[
                            _stageField('awakeStageField', 'Awake (min)', _stageAwakeController),
                            _stageField('remStageField', 'REM (min)', _stageRemController),
                            _stageField('deepStageField', 'Deep (min)', _stageDeepController),
                            _stageField('lightStageField', 'Light (min)', _stageLightController),
                          ],
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
      ),
    );
  }

  Widget _stageField(String key, String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          key: Key(key),
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );

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

class _TimeField extends StatelessWidget {
  const _TimeField({super.key, required this.label, required this.time, required this.onTap});

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(time.format(context), style: textTheme.bodyLarge),
      ),
    );
  }
}
