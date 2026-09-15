import 'package:flutter/material.dart';
import '../../../core/calculations/streak_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/glass_card.dart';
import '../../adherence/data/adherence_repository.dart';
import '../../adherence/domain/adherence_summary.dart';
import '../data/habit_repository.dart';
import '../domain/habit.dart';
import '../domain/habit_completion.dart';

/// How many days of history the grid/hero/per-habit streaks look back over
/// — 35 = the 7x5 grid the handoff's Screen 12 shows.
const _lookbackDays = 35;

/// See `StreakCalculator`'s doc comment and reconciliation decision 3 in
/// `docs/superpowers/plans/2026-09-15-glass-handoff-new-features.md` for why
/// this specific number.
const _streakThreshold = 0.6;

const _milestones = [7, 10, 14, 30];

/// Streaks & habits screen (handoff Screen 12, new route `/streaks` — this
/// slice does not wire the route itself, see the plan's "Final integration"
/// step). Read-only consumer of `HabitRepository` and `AdherenceRepository`:
/// the hero streak and 35-day grid are computed from real
/// `DailyAdherenceSummary` history via `StreakCalculator`, and each habit's
/// own row reuses the same calculator (over that habit's own "completed
/// that day" history) rather than a second implementation.
class StreaksScreen extends StatefulWidget {
  const StreaksScreen({
    super.key,
    required this.uid,
    required this.habitRepository,
    required this.adherenceRepository,
    this.onBack,
  });

  final String uid;
  final HabitRepository habitRepository;
  final AdherenceRepository adherenceRepository;

  /// Called when "← Today" is tapped. Defaults to `Navigator.pop` when null,
  /// so this screen works whether it's pushed or given an explicit callback
  /// by whatever wires its route (the final integration step, not this
  /// slice).
  final VoidCallback? onBack;

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  bool _loading = true;
  List<Habit> _habits = const [];

  /// Index 0 = today, index 34 = 34 days ago. A day with no cached summary
  /// is represented as a summary with a null `overallScore` (same shape
  /// `DailyAdherenceSummary` already uses for "every component excluded") so
  /// `StreakCalculator.calculate` can run directly over this list without a
  /// separate nullable-vs-not representation.
  List<DailyAdherenceSummary> _dailySummariesNewestFirst = const [];

  /// Index 0 = today, index 34 = 34 days ago. Null where no completion doc
  /// exists for that date at all.
  List<HabitCompletion?> _completionsNewestFirst = const [];

  StreakResult _overall = const StreakResult(current: 0, longest: 0);

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
    final today = _today;
    final days = [for (var i = 0; i < _lookbackDays; i++) today.subtract(Duration(days: i))];

    final habits = await widget.habitRepository.listHabits(widget.uid);

    final dailySummaries = <DailyAdherenceSummary>[];
    for (final day in days) {
      var summary = await widget.adherenceRepository.getDaily(widget.uid, day);
      // Only compute-and-cache *today's* summary on the fly, matching the
      // Adherence screen's own convention — backfilling every missing past
      // day here would be a lot of unnecessary Firestore writes for a
      // read-only streaks view. A past day with nothing cached is
      // legitimately "missing data" for streak purposes, not an error.
      if (summary == null && day == today) {
        summary = await widget.adherenceRepository.computeAndCacheDaily(widget.uid, day);
      }
      dailySummaries.add(
        summary ??
            DailyAdherenceSummary(
              date: day,
              overallScore: null,
              componentScores: const {},
              excludedComponents: const {},
              calculatedAt: day,
            ),
      );
    }

    final completions = <HabitCompletion?>[];
    for (final day in days) {
      completions.add(await widget.habitRepository.getCompletion(widget.uid, day));
    }

    final overall = StreakCalculator.calculate(dailySummaries, threshold: _streakThreshold);

    if (!mounted) return;
    setState(() {
      _habits = habits;
      _dailySummariesNewestFirst = dailySummaries;
      _completionsNewestFirst = completions;
      _overall = overall;
      _loading = false;
    });
  }

  bool _qualifies(DailyAdherenceSummary day) =>
      day.overallScore != null && day.overallScore! >= _streakThreshold;

  /// A habit's own streak: reuses `StreakCalculator`'s run-counting logic
  /// (via `fromQualifyingDays`) over that habit's own "completed that day"
  /// history, rather than a second streak implementation.
  StreakResult _habitStreak(Habit habit) {
    final flags = [
      for (final completion in _completionsNewestFirst)
        completion?.entries[habit.id]?.completed ?? false,
    ];
    return StreakCalculator.fromQualifyingDays(flags);
  }

  Future<void> _toggleHabit(Habit habit) async {
    if (_completionsNewestFirst.isEmpty) return;
    final todayCompletion = _completionsNewestFirst[0];
    final completedNow = todayCompletion?.entries[habit.id]?.completed ?? false;
    final status = HabitEntryStatus(completed: !completedNow);
    final updated =
        (todayCompletion ?? HabitCompletion(date: _today, entries: const {})).withEntry(habit.id, status);

    setState(() {
      _completionsNewestFirst = [updated, ..._completionsNewestFirst.skip(1)];
    });

    await widget.habitRepository.completeHabit(widget.uid, _today, habit.id, completed: !completedNow);
  }

  void _back() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
                  padding: const EdgeInsets.all(18),
                  children: [
                    _BackPill(onTap: _back),
                    const SizedBox(height: 14),
                    _StreakHero(current: _overall.current, longest: _overall.longest),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Habits', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          if (_habits.isEmpty)
                            const Text(
                              'No habits yet. Add some from Habits to build a streak.',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          else
                            for (final habit in _habits)
                              _HabitRow(
                                habit: habit,
                                completedToday:
                                    _completionsNewestFirst.isNotEmpty &&
                                    (_completionsNewestFirst[0]?.entries[habit.id]?.completed ?? false),
                                streak: _habitStreak(habit),
                                onToggle: () => _toggleHabit(habit),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Last 35 days', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          _StreakGrid(
                            daysNewestFirst: _dailySummariesNewestFirst,
                            currentStreak: _overall.current,
                            qualifies: _qualifies,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Milestones', style: textTheme.headlineMedium),
                          const SizedBox(height: 12),
                          for (final milestone in _milestones)
                            _MilestoneRow(days: milestone, longest: _overall.longest),
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

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glassFill,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.glassStroke)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 16, color: AppColors.textPrimary),
              SizedBox(width: 6),
              Text('Today', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.current, required this.longest});

  final int current;
  final int longest;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('streakHero'),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: AppColors.accentGradient,
        boxShadow: [
          BoxShadow(color: AppColors.accentBlue.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT STREAK',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '$current',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 82,
              letterSpacing: -3,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'days in a row. Longest yet: $longest.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.completedToday,
    required this.streak,
    required this.onToggle,
  });

  final Habit habit;
  final bool completedToday;
  final StreakResult streak;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          IconButton(
            key: Key('streakHabitToggle_${habit.id}'),
            icon: Icon(
              completedToday ? Icons.check_circle : Icons.check_circle_outline,
              color: completedToday ? AppColors.accentGreen : AppColors.textSecondary,
            ),
            onPressed: onToggle,
          ),
          Expanded(child: Text(habit.name, style: textTheme.bodyLarge)),
          Text(
            '${streak.current}🔥',
            style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _StreakGrid extends StatelessWidget {
  const _StreakGrid({
    required this.daysNewestFirst,
    required this.currentStreak,
    required this.qualifies,
  });

  final List<DailyAdherenceSummary> daysNewestFirst;
  final int currentStreak;
  final bool Function(DailyAdherenceSummary) qualifies;

  @override
  Widget build(BuildContext context) {
    // Render oldest-first, left-to-right / top-to-bottom (a familiar
    // "contribution graph" reading order), even though the underlying data
    // is newest-first.
    final oldestFirst = daysNewestFirst.reversed.toList();

    return GridView.builder(
      key: const Key('streakGrid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: oldestFirst.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final newestFirstIndex = oldestFirst.length - 1 - index;
        final day = oldestFirst[index];
        final isQualifying = qualifies(day);
        final isCurrentRun = isQualifying && newestFirstIndex < currentStreak;

        final color = !isQualifying
            ? AppColors.glassFill
            : (isCurrentRun ? AppColors.accentBlue : AppColors.accentGreen);

        return DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isQualifying
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)]
                : null,
          ),
        );
      },
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.days, required this.longest});

  final int days;
  final int longest;

  static const _labels = {7: 'One clean week', 10: 'Double digits', 14: 'Fortnight', 30: 'A full month'};

  @override
  Widget build(BuildContext context) {
    final unlocked = longest >= days;
    final away = days - longest;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            key: Key('milestoneBadge_$days'),
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? AppColors.accentGreen.withValues(alpha: 0.22) : AppColors.glassFill,
            ),
            child: Text(
              '$days',
              style: TextStyle(
                color: unlocked ? AppColors.accentGreen : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _labels[days] ?? '$days days',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            unlocked ? 'Unlocked' : '$away day${away == 1 ? '' : 's'} away',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
