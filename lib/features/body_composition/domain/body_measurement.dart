/// The physical circumference/weight metrics that can be recorded and used
/// as inputs to body-composition estimates.
enum BodyMetric {
  weight,
  waist,
  neck,
  hip,
  chest,
  thigh,
  upperArm,
  forearm,
}

/// A single recorded body measurement (e.g. a waist circumference reading).
class BodyMeasurement {
  const BodyMeasurement({
    required this.metric,
    required this.value,
    required this.unit,
    required this.measuredAt,
    required this.createdAt,
    this.method,
    this.note,
    this.supersessionId,
  });

  final BodyMetric metric;
  final double value;
  final String unit;
  final DateTime measuredAt;

  /// How the measurement was taken/derived, e.g. "manual", "tape", "scale".
  final String? method;
  final String? note;

  /// The ID of a prior measurement this one supersedes/replaces, if any.
  final String? supersessionId;

  final DateTime createdAt;
}
