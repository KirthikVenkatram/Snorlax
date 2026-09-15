import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_chart.dart';
import '../../../core/widgets/weekly_bar_chart.dart';
import '../../adherence/data/adherence_repository.dart';
import '../../body_composition/data/body_composition_repository.dart';
import '../../body_composition/domain/body_measurement.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../workouts/data/workout_repository.dart';
import '../../workouts/domain/workout.dart';

/// Read-only aggregation screen over data that already exists elsewhere
/// (weight, adherence, nutrition, workouts) — per handoff Screen 11. No new
/// Firestore writes: every number here is computed from what other
/// repositories already persisted.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({
    super.key,
    required this.uid,
    required this.bodyCompositionRepository,
    required this.adherenceRepository,
    required this.nutritionRepository,
    required this.workoutRepository,
  });

  final String uid;
  final BodyCompositionRepository bodyCompositionRepository;
  final AdherenceRepository adherenceRepository;
  final NutritionRepository nutritionRepository;
  final WorkoutRepository workoutRepository;

  static const _weeks = 8;
  static const _windowDays = 7;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  bool _loading = true;

  List<ProgressPoint> _weightPoints = const [];
  double? _weightDeltaKg;
  String _weightUnit = 'kg';

  List<DayValue> _disciplineBars = const [];

  _StatDelta? _caloriesStat;
  _StatDelta? _proteinStat;
  _StatDelta? _sessionsStat;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final windowStart = now.subtract(const Duration(days: TrendsScreen._weeks * 7));

    final weightMeasurements =
        await widget.bodyCompositionRepository.listMeasurements(widget.uid, BodyMetric.weight);
    final recentWeights =
        weightMeasurements.where((m) => !m.measuredAt.isBefore(windowStart)).toList();

    final weeklyAdherence =
        await widget.adherenceRepository.listRecentWeekly(widget.uid, TrendsScreen._weeks);

    final foodLog = await widget.nutritionRepository.listFoodLog(widget.uid);
    final workouts = await widget.workoutRepository.listWorkouts(widget.uid);

    if (!mounted) return;
    setState(() {
      _weightPoints = [
        for (final m in recentWeights) ProgressPoint(date: m.measuredAt, value: m.value),
      ];
      if (recentWeights.length >= 2) {
        _weightDeltaKg = recentWeights.last.value - recentWeights.first.value;
        _weightUnit = recentWeights.last.unit;
      } else {
        _weightDeltaKg = null;
      }

      _disciplineBars = [
        for (var i = 0; i < weeklyAdherence.length; i++)
          DayValue(
            date: now.subtract(Duration(days: 7 * (weeklyAdherence.length - 1 - i))),
            value: (weeklyAdherence[i]?.overallScore ?? 0) * 100,
          ),
      ];

      _caloriesStat = _dailyAverageDelta(
        now: now,
        values: foodLog.map((e) => (e.date, e.calories)),
      );
      _proteinStat = _dailyAverageDelta(
        now: now,
        values: foodLog.map((e) => (e.date, e.proteinG)),
      );
      _sessionsStat = _sessionsPerWeekDelta(now: now, workouts: workouts);

      _loading = false;
    });
  }

  /// Average of [values] falling in the last [TrendsScreen._windowDays] days
  /// vs. the [TrendsScreen._windowDays] days before that — `null` when
  /// there's nothing logged in the current window (nothing to report, not a
  /// fabricated 0).
  _StatDelta? _dailyAverageDelta({
    required DateTime now,
    required Iterable<(DateTime, double)> values,
  }) {
    final currentStart = now.subtract(const Duration(days: TrendsScreen._windowDays));
    final previousStart = now.subtract(const Duration(days: TrendsScreen._windowDays * 2));

    double currentTotal = 0, previousTotal = 0;
    for (final (date, value) in values) {
      if (!date.isBefore(currentStart)) {
        currentTotal += value;
      } else if (!date.isBefore(previousStart)) {
        previousTotal += value;
      }
    }
    if (currentTotal == 0) return null;
    final currentAvg = currentTotal / TrendsScreen._windowDays;
    final previousAvg = previousTotal / TrendsScreen._windowDays;
    return _StatDelta(value: currentAvg, delta: previousTotal == 0 ? null : currentAvg - previousAvg);
  }

  _StatDelta? _sessionsPerWeekDelta({required DateTime now, required List<Workout> workouts}) {
    final currentStart = now.subtract(const Duration(days: TrendsScreen._windowDays));
    final previousStart = now.subtract(const Duration(days: TrendsScreen._windowDays * 2));
    var current = 0, previous = 0;
    for (final w in workouts) {
      if (!w.date.isBefore(currentStart)) {
        current++;
      } else if (!w.date.isBefore(previousStart)) {
        previous++;
      }
    }
    if (current == 0 && previous == 0) return null;
    return _StatDelta(value: current.toDouble(), delta: previous == 0 ? null : (current - previous).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Trends', style: textTheme.headlineMedium),
                        _ClosePill(onTap: () => Navigator.of(context).maybePop()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Weight', style: textTheme.headlineMedium),
                          const SizedBox(height: 4),
                          Text(
                            _weightDeltaKg == null
                                ? 'Not enough data yet'
                                : '${_weightDeltaKg! > 0 ? '+' : ''}${_weightDeltaKg!.toStringAsFixed(1)} $_weightUnit',
                            key: const Key('weightDelta'),
                            style: textTheme.bodyLarge?.copyWith(
                              color: _weightDeltaColor(_weightDeltaKg),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(height: 160, child: ProgressChart(points: _weightPoints)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      glowColor: AppColors.accentViolet,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discipline', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          SizedBox(height: 140, child: WeeklyBarChart(days: _disciplineBars)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _StatRow(
                            label: 'Calories / day',
                            stat: _caloriesStat,
                            format: (v) => '${v.round()} kcal',
                            deltaFormat: (d) => '${d > 0 ? '+' : ''}${d.round()}',
                          ),
                          _StatRow(
                            label: 'Protein / day',
                            stat: _proteinStat,
                            format: (v) => '${v.round()} g',
                            deltaFormat: (d) => '${d > 0 ? '+' : ''}${d.round()}g',
                          ),
                          _StatRow(
                            label: 'Sessions / week',
                            stat: _sessionsStat,
                            format: (v) => v.toStringAsFixed(1),
                            deltaFormat: (d) => '${d > 0 ? '+' : ''}${d.toStringAsFixed(1)}',
                          ),
                          // Sleep has no data source in this pass — Slice C
                          // (`lib/features/sleep/`) may land the repository
                          // this row needs after this slice ships. Stub
                          // rather than fabricate; see ISSUES.md.
                          const _StatRow(label: 'Sleep / night', stat: null, format: null, deltaFormat: null),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Neither sign is universally "good" (a bulk wants weight up, a cut wants
  /// it down), so this doesn't guess intent — it just renders the number
  /// distinctly rather than defaulting silently to one color.
  Color _weightDeltaColor(double? delta) {
    if (delta == null || delta == 0) return AppColors.textSecondary;
    return delta < 0 ? AppColors.accentGreen : AppColors.accentBlue;
  }
}

class _StatDelta {
  const _StatDelta({required this.value, required this.delta});
  final double value;
  final double? delta;
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.stat,
    required this.format,
    required this.deltaFormat,
  });

  final String label;
  final _StatDelta? stat;
  final String Function(double)? format;
  final String Function(double)? deltaFormat;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = stat != null && format != null ? format!(stat!.value) : '—';
    final delta = stat?.delta;
    final deltaText = delta != null && deltaFormat != null ? deltaFormat!(delta) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyLarge)),
          Text(value, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (deltaText != null) ...[
            const SizedBox(width: 8),
            Text(
              deltaText,
              style: textTheme.bodyMedium?.copyWith(
                color: delta! >= 0 ? AppColors.accentGreen : AppColors.accentBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClosePill extends StatelessWidget {
  const _ClosePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Close', style: TextStyle(color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}
