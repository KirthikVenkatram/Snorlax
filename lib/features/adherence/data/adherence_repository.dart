import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/adherence_calculator.dart';
import '../../habits/data/habit_repository.dart';
import '../../habits/domain/habit_completion.dart';
import '../../nutrition/data/nutrition_repository.dart';
import '../../workouts/data/workout_repository.dart';
import '../domain/adherence_summary.dart';

/// Computes and caches daily/weekly adherence summaries from the nutrition,
/// workout, and habit repositories that already exist in the app, and
/// persists/reads per-user configurable component weights.
///
/// Per the Phase 5 plan, these derived summaries are computed client-side
/// and cached to Firestore rather than via a server-only Cloud Function —
/// see `docs/superpowers/ISSUES.md` for the logged security-rule gap this
/// implies (a client could in principle write a fabricated summary
/// directly).
class AdherenceRepository {
  AdherenceRepository({
    required FirebaseFirestore firestore,
    required NutritionRepository nutritionRepository,
    required WorkoutRepository workoutRepository,
    required HabitRepository habitRepository,
  })  : // ignore: prefer_initializing_formals
        _firestore = firestore,
        // ignore: prefer_initializing_formals
        _nutritionRepository = nutritionRepository,
        // ignore: prefer_initializing_formals
        _workoutRepository = workoutRepository,
        // ignore: prefer_initializing_formals
        _habitRepository = habitRepository;

  final FirebaseFirestore _firestore;
  final NutritionRepository _nutritionRepository;
  final WorkoutRepository _workoutRepository;
  final HabitRepository _habitRepository;

  CollectionReference<Map<String, dynamic>> _dailySummaries(String uid) =>
      _firestore.collection('users').doc(uid).collection('adherenceDaily');

  CollectionReference<Map<String, dynamic>> _weeklySummaries(String uid) =>
      _firestore.collection('users').doc(uid).collection('adherenceWeekly');

  DocumentReference<Map<String, dynamic>> _weightsDoc(String uid) =>
      _firestore.collection('users').doc(uid).collection('meta').doc('adherenceWeights');

  Future<AdherenceWeights> getWeights(String uid) async {
    final doc = await _weightsDoc(uid).get();
    if (!doc.exists || doc.data() == null) return const AdherenceWeights();
    return AdherenceWeights.fromJson(doc.data()!);
  }

  Future<void> setWeights(String uid, AdherenceWeights weights) async {
    await _weightsDoc(uid).set(weights.toJson());
  }

  static String _dateDocId(DateTime date) => habitCompletionDocId(date);

  /// Computes a day's adherence from live nutrition/workout/habit data and
  /// caches the result at `adherenceDaily/{date}`.
  ///
  /// Component scoring (deterministic, documented here since these are
  /// judgment calls made for this pass — see ISSUES.md):
  /// - nutrition: 1.0 minus the fractional distance of that day's logged
  ///   calories from the daily calorie goal, floored at 0. No goal set or
  ///   no entries logged that day -> excluded (nothing to score against).
  /// - training: 1.0 if at least one workout was logged that day, else 0.0.
  ///   There is no explicit "rest day" schedule yet, so a true rest day
  ///   currently scores 0 unless the user logs a habit-level exclusion —
  ///   logged as a gap in ISSUES.md.
  /// - habits: fraction of that day's non-archived habits marked completed,
  ///   with excluded habits removed from the denominator. No habits at all
  ///   -> excluded.
  /// - recovery: always excluded (neutral) until Phase 6 readiness data
  ///   exists — logged in ISSUES.md.
  Future<DailyAdherenceSummary> computeAndCacheDaily(String uid, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final weights = await getWeights(uid);

    final nutritionInput = await _nutritionComponent(uid, day);
    final trainingInput = await _trainingComponent(uid, day);
    final habitsInput = await _habitsComponent(uid, day);
    const recoveryInput = ComponentInput.excluded();

    final result = AdherenceCalculator.calculateDaily(
      date: day,
      weights: weights,
      inputs: {
        AdherenceComponent.nutrition: nutritionInput,
        AdherenceComponent.training: trainingInput,
        AdherenceComponent.habits: habitsInput,
        AdherenceComponent.recovery: recoveryInput,
      },
    );

    final summary = DailyAdherenceSummary.fromResult(result);
    await _dailySummaries(uid).doc(_dateDocId(day)).set(summary.toJson());
    return summary;
  }

  Future<DailyAdherenceSummary?> getDaily(String uid, DateTime date) async {
    final doc = await _dailySummaries(uid).doc(_dateDocId(date)).get();
    if (!doc.exists || doc.data() == null) return null;
    return DailyAdherenceSummary.fromJson(date, doc.data()!);
  }

  /// Rolls up the 7 days of the ISO week containing [date] into a weekly
  /// summary, computing (and caching) any missing daily summaries first,
  /// then caches the roll-up at `adherenceWeekly/{weekId}`.
  Future<WeeklyAdherenceSummary> computeAndCacheWeekly(String uid, DateTime date) async {
    final weekId = AdherenceCalculator.weekIdFor(date);
    final monday = date.subtract(Duration(days: date.weekday - 1));

    final dailyScores = <double?>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(monday.year, monday.month, monday.day).add(Duration(days: i));
      if (day.isAfter(DateTime.now())) {
        dailyScores.add(null);
        continue;
      }
      var daily = await getDaily(uid, day);
      daily ??= await computeAndCacheDaily(uid, day);
      dailyScores.add(daily.overallScore);
    }

    final result = AdherenceCalculator.calculateWeekly(weekId: weekId, dailyScores: dailyScores);
    final summary = WeeklyAdherenceSummary.fromResult(result);
    await _weeklySummaries(uid).doc(weekId).set(summary.toJson());
    return summary;
  }

  Future<WeeklyAdherenceSummary?> getWeekly(String uid, String weekId) async {
    final doc = await _weeklySummaries(uid).doc(weekId).get();
    if (!doc.exists || doc.data() == null) return null;
    return WeeklyAdherenceSummary.fromJson(weekId, doc.data()!);
  }

  Future<ComponentInput> _nutritionComponent(String uid, DateTime day) async {
    final goals = await _nutritionRepository.getGoals(uid);
    if (goals == null || goals.dailyCalories <= 0) return const ComponentInput.excluded();

    final entries = await _nutritionRepository.listFoodLog(uid);
    final loggedToday = entries.where((entry) => _isSameDay(entry.date, day));
    if (loggedToday.isEmpty) return const ComponentInput.excluded();

    final totalCalories = loggedToday.fold<double>(0, (total, entry) => total + entry.calories);
    final fractionalDistance = (totalCalories - goals.dailyCalories).abs() / goals.dailyCalories;
    final score = (1.0 - fractionalDistance).clamp(0.0, 1.0);
    return ComponentInput.scored(score);
  }

  Future<ComponentInput> _trainingComponent(String uid, DateTime day) async {
    final workouts = await _workoutRepository.listWorkouts(uid);
    final loggedToday = workouts.any((workout) => _isSameDay(workout.date, day));
    return ComponentInput.scored(loggedToday ? 1.0 : 0.0);
  }

  Future<ComponentInput> _habitsComponent(String uid, DateTime day) async {
    final habits = await _habitRepository.listHabits(uid);
    if (habits.isEmpty) return const ComponentInput.excluded();

    final completion = await _habitRepository.getCompletion(uid, day);
    var completedCount = 0;
    var countedCount = 0;
    for (final habit in habits) {
      final status = completion?.entries[habit.id];
      if (status?.excluded ?? false) continue;
      countedCount++;
      if (status?.completed ?? false) completedCount++;
    }

    if (countedCount == 0) return const ComponentInput.excluded();
    return ComponentInput.scored(completedCount / countedCount);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
}
