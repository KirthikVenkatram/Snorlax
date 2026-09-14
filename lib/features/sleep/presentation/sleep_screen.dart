import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/weekly_bar_chart.dart';
import '../data/sleep_repository.dart';
import '../domain/sleep_entry.dart';
import 'sleep_check_in_screen.dart';

/// Sleep display screen — per handoff Screen 10 ("Last night"): duration,
/// bed/wake time, an optional stages breakdown, optional HR/HRV/score
/// tiles, and a 7-night duration chart.
///
/// Never fabricates data: the stages card only renders when the user
/// actually entered stage minutes, and each metric tile only renders when
/// its field was entered.
class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key, required this.uid, required this.repository});

  final String uid;
  final SleepRepository repository;

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  SleepEntry? _latest;
  List<SleepEntry> _recent = const [];
  bool _loading = true;

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
    final recent = await widget.repository.listRecent(widget.uid, 7);
    if (!mounted) return;
    setState(() {
      _latest = entry;
      _recent = recent;
      _loading = false;
    });
  }

  Future<void> _openCheckIn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SleepCheckInScreen(uid: widget.uid, repository: widget.repository),
      ),
    );
    _load();
  }

  String _formatDuration(Duration d) => '${d.inHours}h ${d.inMinutes % 60}m';

  String _formatTimeOfDay(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Sleep'), backgroundColor: Colors.transparent),
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (_latest == null)
                      GlassCard(
                        glowColor: AppColors.accentViolet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LAST NIGHT',
                              key: const Key('lastNightKicker'),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.accentViolet,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No check-in yet. Log last night\'s sleep to see it here.',
                              style: textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 16),
                            PrimaryButton(label: 'Log sleep', onPressed: _openCheckIn),
                          ],
                        ),
                      )
                    else ...[
                      GlassCard(
                        hero: true,
                        glowColor: AppColors.accentViolet,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LAST NIGHT',
                              key: const Key('lastNightKicker'),
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.accentViolet,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(_latest!.timeAsleep),
                              key: const Key('sleepDurationText'),
                              style: textTheme.displayLarge?.copyWith(
                                fontSize: 58,
                                color: AppColors.accentViolet,
                                shadows: [
                                  Shadow(
                                    color: AppColors.accentViolet.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatTimeOfDay(_latest!.bedtime)} → '
                              '${_formatTimeOfDay(_latest!.wakeTime)} · '
                              '${_latest!.awakeMinutes} min awake',
                              style: textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_latest!.stages != null) ...[
                        _StagesCard(stages: _latest!.stages!),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          if (_latest!.restingHeartRate != null)
                            Expanded(
                              child: _MetricTile(
                                key: const Key('restingHrTile'),
                                label: 'RESTING HR',
                                value: '${_latest!.restingHeartRate} bpm',
                              ),
                            ),
                          if (_latest!.restingHeartRate != null) const SizedBox(width: 12),
                          if (_latest!.hrv != null)
                            Expanded(
                              child: _MetricTile(
                                key: const Key('hrvTile'),
                                label: 'HRV',
                                value: '${_latest!.hrv!.round()} ms',
                              ),
                            ),
                          if (_latest!.hrv != null) const SizedBox(width: 12),
                          Expanded(
                            child: _MetricTile(
                              key: const Key('scoreTile'),
                              label: 'SCORE',
                              value: '${_latest!.score}',
                              accent: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LAST 7 NIGHTS', style: textTheme.bodySmall),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 160,
                              child: WeeklyBarChart(
                                days: [
                                  for (final e in _recent.reversed)
                                    DayValue(date: e.date, value: e.timeAsleep.inMinutes / 60),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.stages});

  final SleepStageMinutes stages;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = [stages.awake, stages.rem, stages.deep, stages.light]
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 1 << 30);
    return GlassCard(
      key: const Key('sleepStagesCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STAGES', style: textTheme.bodySmall),
          const SizedBox(height: 12),
          _lane('Awake', stages.awake, total, AppColors.accentBlue),
          _lane('REM', stages.rem, total, AppColors.accentViolet),
          _lane('Deep', stages.deep, total, AppColors.accentGreen),
          _lane('Light', stages.light, total, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _lane(String label, int minutes, int total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: minutes / total,
                minHeight: 8,
                backgroundColor: AppColors.glassFill,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${minutes}m', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({super.key, required this.label, required this.value, this.accent = false});

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: accent ? AppColors.accentGreen : AppColors.accentViolet,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent ? AppColors.accentGreen : AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
