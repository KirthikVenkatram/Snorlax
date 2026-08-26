import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toJson() => {
        'metric': metric.name,
        'value': value,
        'unit': unit,
        'measuredAt': Timestamp.fromDate(measuredAt),
        'createdAt': Timestamp.fromDate(createdAt),
        if (method != null) 'method': method,
        if (note != null) 'note': note,
        if (supersessionId != null) 'supersessionId': supersessionId,
      };

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) => BodyMeasurement(
        metric: BodyMetric.values.byName(json['metric'] as String),
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
        measuredAt: (json['measuredAt'] as Timestamp).toDate(),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        method: json['method'] as String?,
        note: json['note'] as String?,
        supersessionId: json['supersessionId'] as String?,
      );
}
