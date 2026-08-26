/// The result of a deterministic body-composition calculation (e.g. from
/// [BodyCompositionCalculator]).
class BodyCompositionEstimate {
  const BodyCompositionEstimate({
    required this.bodyFatPercent,
    required this.fatMassKg,
    required this.leanBodyMassKg,
    required this.method,
    required this.calculationVersion,
    required this.sourceMeasurementIds,
    required this.calculatedAt,
  });

  final double bodyFatPercent;
  final double fatMassKg;
  final double leanBodyMassKg;

  /// Identifier of the estimation method used, e.g. "us-navy-circumference".
  final String method;

  /// Version of the calculation logic that produced this estimate, so
  /// historical estimates remain reproducible/interpretable if the formula
  /// or validation rules change later.
  final int calculationVersion;

  /// IDs of the [BodyMeasurement]s that fed into this estimate, if known.
  final List<String> sourceMeasurementIds;

  final DateTime calculatedAt;
}
