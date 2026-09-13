/// Domain types for the readiness/recovery feature.
///
/// IMPORTANT: readiness results produced from these types are a simple,
/// transparent, self-reported wellness heuristic. They are NOT medical
/// advice and NOT a medically validated assessment of any kind. See
/// `lib/core/calculations/readiness_calculator.dart` for the deterministic
/// logic and its hard safety-override guarantees.
library;

/// Self-reported inputs for one day's readiness check-in.
///
/// Continuous inputs use the app's `[0, 1]` convention (see
/// `adherence_calculator.dart`) except [sleepHours], a raw hour count that
/// the calculator normalizes internally. Higher is "better" for
/// [sleepConsistency] and [energy]; higher is "worse" for [soreness],
/// [fatigue], and [recentTrainingLoad].
class ReadinessInputs {
  const ReadinessInputs({
    required this.sleepHours,
    required this.sleepConsistency,
    required this.soreness,
    required this.fatigue,
    required this.energy,
    required this.recentTrainingLoad,
    this.painOrInjury = false,
  })  : assert(sleepHours >= 0, 'sleepHours must be non-negative'),
        assert(sleepConsistency >= 0 && sleepConsistency <= 1, 'sleepConsistency must be in [0, 1]'),
        assert(soreness >= 0 && soreness <= 1, 'soreness must be in [0, 1]'),
        assert(fatigue >= 0 && fatigue <= 1, 'fatigue must be in [0, 1]'),
        assert(energy >= 0 && energy <= 1, 'energy must be in [0, 1]'),
        assert(recentTrainingLoad >= 0 && recentTrainingLoad <= 1, 'recentTrainingLoad must be in [0, 1]');

  final double sleepHours;
  final double sleepConsistency;
  final double soreness;
  final double fatigue;
  final double energy;
  final double recentTrainingLoad;

  /// Self-reported pain or injury flag. When true, this is a hard safety
  /// override in `ReadinessCalculator` — the result is forced to
  /// [ReadinessLevel.red] regardless of every other input, and no other
  /// layer of the app (including a future AI coach) can change that.
  final bool painOrInjury;

  Map<String, dynamic> toJson() => {
        'sleepHours': sleepHours,
        'sleepConsistency': sleepConsistency,
        'soreness': soreness,
        'fatigue': fatigue,
        'energy': energy,
        'recentTrainingLoad': recentTrainingLoad,
        'painOrInjury': painOrInjury,
      };

  factory ReadinessInputs.fromJson(Map<String, dynamic> json) => ReadinessInputs(
        sleepHours: (json['sleepHours'] as num).toDouble(),
        sleepConsistency: (json['sleepConsistency'] as num).toDouble(),
        soreness: (json['soreness'] as num).toDouble(),
        fatigue: (json['fatigue'] as num).toDouble(),
        energy: (json['energy'] as num).toDouble(),
        recentTrainingLoad: (json['recentTrainingLoad'] as num).toDouble(),
        painOrInjury: json['painOrInjury'] as bool? ?? false,
      );
}

/// The deterministic, non-medical readiness result: green (train normally),
/// yellow (reduce volume/intensity), or red (recovery/rest; seek
/// appropriate professional help when pain or concerning symptoms are
/// present).
enum ReadinessLevel { green, yellow, red }

/// The calculator's output for one day: a [ReadinessLevel], a numeric
/// [score] in `[0, 1]` (used as the adherence recovery component's input),
/// human-readable [notes] explaining the drivers, and whether a hard safety
/// override forced the level to red.
class ReadinessResult {
  const ReadinessResult({
    required this.level,
    required this.score,
    required this.notes,
    required this.safetyOverrideTriggered,
  });

  final ReadinessLevel level;
  final double score;
  final List<String> notes;
  final bool safetyOverrideTriggered;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'score': score,
        'notes': notes,
        'safetyOverrideTriggered': safetyOverrideTriggered,
      };

  factory ReadinessResult.fromJson(Map<String, dynamic> json) => ReadinessResult(
        level: ReadinessLevel.values.byName(json['level'] as String),
        score: (json['score'] as num).toDouble(),
        notes: (json['notes'] as List? ?? const []).map((n) => n as String).toList(),
        safetyOverrideTriggered: json['safetyOverrideTriggered'] as bool? ?? false,
      );
}

/// Current calculator logic version, bumped whenever the readiness scoring
/// or override rules change, so historical entries stay traceable to the
/// logic that produced them (same convention as
/// `BodyCompositionCalculator.calculationVersion`).
const readinessCalculationVersion = 1;

/// A persisted document at `users/{uid}/readiness/{date}`: the day's raw
/// [inputs] plus the deterministic [result] computed from them.
///
/// This is self-reported wellness data, not medical advice or a medically
/// validated assessment.
class ReadinessEntry {
  const ReadinessEntry({
    required this.date,
    required this.inputs,
    required this.result,
    this.calculationVersion = readinessCalculationVersion,
  });

  final DateTime date;
  final ReadinessInputs inputs;
  final ReadinessResult result;
  final int calculationVersion;

  Map<String, dynamic> toJson() => {
        'inputs': inputs.toJson(),
        'result': result.toJson(),
        'calculationVersion': calculationVersion,
      };

  factory ReadinessEntry.fromJson(DateTime date, Map<String, dynamic> json) => ReadinessEntry(
        date: date,
        inputs: ReadinessInputs.fromJson(Map<String, dynamic>.from(json['inputs'] as Map)),
        result: ReadinessResult.fromJson(Map<String, dynamic>.from(json['result'] as Map)),
        calculationVersion: (json['calculationVersion'] as num?)?.toInt() ?? readinessCalculationVersion,
      );
}

/// Normalizes a [DateTime] to a date-only key (`yyyy-MM-dd`), matching the
/// document-id convention used elsewhere (see `habitCompletionDocId`).
String readinessDocId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
