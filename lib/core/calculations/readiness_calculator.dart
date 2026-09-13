import '../../features/readiness/domain/readiness_entry.dart';

/// Deterministic, pure calculation of a daily readiness result from
/// self-reported wellness inputs.
///
/// This is NOT medical advice and NOT a medically validated assessment. It
/// is a simple, transparent heuristic meant to nudge training intensity —
/// nothing more. When the result is red because of pain/injury or other
/// concerning symptoms, callers must tell users to seek appropriate
/// professional help rather than self-diagnosing from this score.
///
/// CRITICAL SAFETY PROPERTY: [calculate] evaluates hard safety overrides
/// *before* it computes or even looks at the weighted composite score. A
/// reported pain/injury flag, or the combination of extreme sleep
/// deprivation with high soreness, unconditionally forces
/// [ReadinessLevel.red] for that day. No other input, weighting, or future
/// caller — including an AI coach in a later phase — can change that
/// outcome once an override condition holds, because this function is pure
/// and the override check short-circuits before the composite path ever
/// runs. This is enforced structurally here, not by caller convention.
class ReadinessCalculator {
  ReadinessCalculator._();

  /// Sleep hours at or below this threshold count as "extreme sleep
  /// deprivation" for the hard safety override.
  static const double extremeSleepDeprivationHours = 4.0;

  /// Soreness at or above this threshold counts as "high soreness" for the
  /// hard safety override.
  static const double highSorenessThreshold = 0.8;

  static const double _greenThreshold = 0.70;
  static const double _yellowThreshold = 0.45;

  /// Computes the deterministic [ReadinessResult] for one day's
  /// [ReadinessInputs].
  static ReadinessResult calculate(ReadinessInputs inputs) {
    final score = _compositeScore(inputs);
    final overrideReason = _hardSafetyOverrideReason(inputs);

    if (overrideReason != null) {
      return ReadinessResult(
        level: ReadinessLevel.red,
        score: score,
        notes: [
          overrideReason,
          'This is not medical advice or a diagnosis. If you are in pain or '
              'have an injury, consider seeking appropriate professional help '
              'before training.',
        ],
        safetyOverrideTriggered: true,
      );
    }

    final level = score >= _greenThreshold
        ? ReadinessLevel.green
        : (score >= _yellowThreshold ? ReadinessLevel.yellow : ReadinessLevel.red);

    return ReadinessResult(
      level: level,
      score: score,
      notes: [_summaryNote(level)],
      safetyOverrideTriggered: false,
    );
  }

  /// Returns a human-readable reason if a hard safety override applies, or
  /// null otherwise. Both conditions are pass/fail gates evaluated
  /// independently of [_compositeScore] and of each other's weighting — an
  /// override here is never diluted by averaging against other inputs.
  static String? _hardSafetyOverrideReason(ReadinessInputs inputs) {
    if (inputs.painOrInjury) {
      return 'You reported pain or injury today, so a recovery/rest day is '
          'recommended regardless of your other readiness inputs.';
    }
    if (inputs.sleepHours <= extremeSleepDeprivationHours && inputs.soreness >= highSorenessThreshold) {
      return 'Very low sleep combined with high soreness triggers a recovery '
          'day regardless of your other readiness inputs.';
    }
    return null;
  }

  static double _compositeScore(ReadinessInputs inputs) {
    final sleepDurationScore = (inputs.sleepHours / 8.0).clamp(0.0, 1.0);
    final components = <double>[
      sleepDurationScore,
      inputs.sleepConsistency,
      1.0 - inputs.soreness,
      1.0 - inputs.fatigue,
      inputs.energy,
      1.0 - inputs.recentTrainingLoad,
    ];
    return components.reduce((a, b) => a + b) / components.length;
  }

  static String _summaryNote(ReadinessLevel level) => switch (level) {
        ReadinessLevel.green => 'Readiness looks solid today — training as planned is reasonable.',
        ReadinessLevel.yellow => 'Readiness is mixed today — consider reducing volume or intensity.',
        ReadinessLevel.red => 'Readiness is low today — consider a recovery or rest day.',
      };
}
