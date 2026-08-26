import 'dart:math';

import 'package:fitness_tracker/features/body_composition/domain/body_composition_estimate.dart';

import 'nutrition_goal_calculator.dart' show Sex;

/// Estimates body-fat percentage and derived mass split from circumference
/// measurements using the U.S. Navy method.
///
/// This is a pure, deterministic calculator: it performs no I/O and has no
/// dependency on Firestore or any other Phase 4 feature.
class BodyCompositionCalculator {
  BodyCompositionCalculator._();

  static const String _method = 'us-navy-circumference';

  /// The version of the calculation logic below. Bump this whenever the
  /// formula or validation rules change, so stored estimates remain
  /// traceable to the logic that produced them.
  static const int calculationVersion = 1;

  /// Estimates body composition from circumference measurements using the
  /// U.S. Navy method.
  ///
  /// All circumference/height/weight inputs must be positive. [hipCm] is
  /// required for [Sex.female] (and ignored for [Sex.male]). Throws
  /// [ArgumentError] if any input is non-positive, if a required hip
  /// measurement is missing, if the resulting circumference geometry is
  /// impossible (i.e. yields a non-positive logarithm argument), or if the
  /// computed body-fat percentage falls outside the plausible 2-75% range.
  static BodyCompositionEstimate estimate({
    required Sex sex,
    required double heightCm,
    required double weightKg,
    required double waistCm,
    required double neckCm,
    double? hipCm,
    List<String> sourceMeasurementIds = const [],
    DateTime? calculatedAt,
  }) {
    if (heightCm <= 0) {
      throw ArgumentError.value(heightCm, 'heightCm', 'must be positive');
    }
    if (weightKg <= 0) {
      throw ArgumentError.value(weightKg, 'weightKg', 'must be positive');
    }
    if (waistCm <= 0) {
      throw ArgumentError.value(waistCm, 'waistCm', 'must be positive');
    }
    if (neckCm <= 0) {
      throw ArgumentError.value(neckCm, 'neckCm', 'must be positive');
    }

    if (sex == Sex.female) {
      if (hipCm == null) {
        throw ArgumentError.value(
          hipCm,
          'hipCm',
          'is required for a female body-fat estimate',
        );
      }
      if (hipCm <= 0) {
        throw ArgumentError.value(hipCm, 'hipCm', 'must be positive');
      }
    } else if (hipCm != null && hipCm <= 0) {
      throw ArgumentError.value(hipCm, 'hipCm', 'must be positive');
    }

    final height = heightCm / 2.54;
    final waist = waistCm / 2.54;
    final neck = neckCm / 2.54;
    final hip = hipCm != null ? hipCm / 2.54 : null;

    final circumferenceTerm = sex == Sex.male ? (waist - neck) : (waist + hip! - neck);

    if (circumferenceTerm <= 0 || height <= 0) {
      throw ArgumentError(
        'Impossible circumference geometry: waist/neck${sex == Sex.female ? '/hip' : ''} '
        'measurements do not yield a valid body-fat calculation',
      );
    }

    final density = sex == Sex.male
        ? 1.0324 - 0.19077 * log(circumferenceTerm) / ln10 + 0.15456 * log(height) / ln10
        : 1.29579 - 0.35004 * log(circumferenceTerm) / ln10 + 0.22100 * log(height) / ln10;

    final bodyFatPercent = 495 / density - 450;

    if (bodyFatPercent < 2 || bodyFatPercent > 75) {
      throw ArgumentError.value(
        bodyFatPercent,
        'bodyFatPercent',
        'computed body-fat percentage is outside the plausible 2-75 range',
      );
    }

    final fatMassKg = weightKg * bodyFatPercent / 100;
    final leanBodyMassKg = weightKg - fatMassKg;

    return BodyCompositionEstimate(
      bodyFatPercent: bodyFatPercent,
      fatMassKg: fatMassKg,
      leanBodyMassKg: leanBodyMassKg,
      method: _method,
      calculationVersion: calculationVersion,
      sourceMeasurementIds: sourceMeasurementIds,
      calculatedAt: calculatedAt ?? DateTime.now(),
    );
  }
}
