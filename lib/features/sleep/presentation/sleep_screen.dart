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

  static const _awakeColor = AppColors.accentBlue; // token is actually red (FF3B24)
  static const _remColor = AppColors.accentViolet;
  static const _deepColor = AppColors.accentGreen;
  static const _lightColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Full-width lane bars: each track represents the whole night, so the
    // fill fraction is this stage's share of total time in bed — not
    // relative to whichever stage happens to be largest.
    final total = (stages.awake + stages.rem + stages.deep + stages.light).clamp(1, 1 << 30);
    return GlassCard(
      key: const Key('sleepStagesCard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STAGES', style: textTheme.bodySmall),
          const SizedBox(height: 14),
          _lane(stages.awake, total, _awakeColor),
          _lane(stages.rem, total, _remColor),
          _lane(stages.deep, total, _deepColor),
          _lane(stages.light, total, _lightColor.withValues(alpha: 0.65)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendEntry('AWAKE', stages.awake, _awakeColor),
              _legendEntry('REM', stages.rem, _remColor),
              _legendEntry('DEEP', stages.deep, _deepColor),
              _legendEntry('LIGHT', stages.light, _lightColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lane(int minutes, int total, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: minutes / total,
          minHeight: 10,
          backgroundColor: Colors.white.withValues(alpha: 0.12),
          color: color,
        ),
      ),
    );
  }

  Widget _legendEntry(String label, int minutes, Color color) {
    return Text(
      '$label ${_formatMinutes(minutes)}',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
    );
  }

  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}M';
    return '${h}H ${m.toString().padLeft(2, '0')}M';
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
