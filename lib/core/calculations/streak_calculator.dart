import '../../features/adherence/domain/adherence_summary.dart';

/// Pure calculation of a "streak" (current + longest consecutive run of
/// qualifying days) from adherence data. No I/O — callers gather the
/// `DailyAdherenceSummary` list (already fetchable via `AdherenceRepository`)
/// and call into this calculator. See "Reconciliation decisions" item 3 in
/// `docs/superpowers/plans/2026-09-15-glass-handoff-new-features.md`.
class StreakResult {
  const StreakResult({required this.current, required this.longest});

  final int current;
  final int longest;
}

class StreakCalculator {
  StreakCalculator._();

  /// A day counts toward a streak if `overallScore != null && overallScore
  /// >= threshold`. Missing data (no entry for that day in the list, or an
  /// entry with a null `overallScore` because every adherence component was
  /// excluded that day) does NOT qualify — it is not treated as "qualifies"
  /// and it is not treated as an instant reset of everything before it
  /// either: scanning from most recent, the current streak is simply the
  /// count of leading qualifying days before the first day that doesn't
  /// qualify (whether that's a low score or no data at all). `longest` is
  /// the longest run of consecutive qualifying days anywhere in the list.
  ///
  /// [recentDaysNewestFirst] must be ordered most-recent-day-first (index 0
  /// = today, or whatever the caller considers "most recent" — e.g. a
  /// caller that hasn't computed today's summary yet may choose to start
  /// the list at yesterday instead; that choice is the caller's, not this
  /// calculator's).
  static StreakResult calculate(
    List<DailyAdherenceSummary> recentDaysNewestFirst, {
    double threshold = 0.6,
  }) {
    return fromQualifyingDays([
      for (final day in recentDaysNewestFirst) _qualifies(day, threshold),
    ]);
  }

  static bool _qualifies(DailyAdherenceSummary day, double threshold) =>
      day.overallScore != null && day.overallScore! >= threshold;

  /// Same rule as [calculate], but over an already-reduced list of
  /// per-day qualifying flags (`true` = qualifies, `false`/absent day =
  /// doesn't). Exposed so other qualify rules (e.g. a single habit's own
  /// "completed that day" rule, in `streaks_screen.dart`) can reuse this
  /// calculator's shape without re-implementing the run-counting logic.
  static StreakResult fromQualifyingDays(List<bool> qualifiesNewestFirst) {
    if (qualifiesNewestFirst.isEmpty) return const StreakResult(current: 0, longest: 0);

    var current = 0;
    for (final qualifies in qualifiesNewestFirst) {
      if (!qualifies) break;
      current++;
    }

    var longest = 0;
    var run = 0;
    for (final qualifies in qualifiesNewestFirst) {
      run = qualifies ? run + 1 : 0;
      if (run > longest) longest = run;
    }

    return StreakResult(current: current, longest: longest);
  }
}
