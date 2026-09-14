/// Domain types for the sleep feature.
///
/// IMPORTANT: no HealthKit/Health Connect integration exists yet (real
/// device entitlements, native config, and App Store review implications
/// are out of scope for this pass — see the glass-handoff plan's
/// reconciliation decisions). Every field here is a manual, self-reported
/// check-in. The shape is deliberately close to what a future HealthKit
/// sync could populate, so a later sync can write into the same
/// `users/{uid}/sleep/{date}` doc without a schema change.
library;

/// Optional stage-minute breakdown for one night's sleep. Only present when
/// the user actually entered it (e.g. copying from a wearable's own app) —
/// the presentation layer must never fabricate stage minutes when this is
/// null.
class SleepStageMinutes {
  const SleepStageMinutes({
    required this.awake,
    required this.rem,
    required this.deep,
    required this.light,
  })  : assert(awake >= 0, 'awake must be non-negative'),
        assert(rem >= 0, 'rem must be non-negative'),
        assert(deep >= 0, 'deep must be non-negative'),
        assert(light >= 0, 'light must be non-negative');

  final int awake;
  final int rem;
  final int deep;
  final int light;

  Map<String, dynamic> toJson() => {
        'awake': awake,
        'rem': rem,
        'deep': deep,
        'light': light,
      };

  factory SleepStageMinutes.fromJson(Map<String, dynamic> json) => SleepStageMinutes(
        awake: (json['awake'] as num).toInt(),
        rem: (json['rem'] as num).toInt(),
        deep: (json['deep'] as num).toInt(),
        light: (json['light'] as num).toInt(),
      );
}

/// A persisted document at `users/{uid}/sleep/{date}`: one night's manually
/// entered sleep check-in.
///
/// [restingHeartRate], [hrv], and [stages] are optional. The presentation
/// layer must render a metric tile / stages card only when the
/// corresponding field is present — never show a fabricated value.
class SleepEntry {
  const SleepEntry({
    required this.date,
    required this.bedtime,
    required this.wakeTime,
    required this.awakeMinutes,
    required this.score,
    this.restingHeartRate,
    this.hrv,
    this.stages,
  })  : assert(awakeMinutes >= 0, 'awakeMinutes must be non-negative'),
        assert(score >= 1 && score <= 100, 'score must be in [1, 100]');

  final DateTime date;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int awakeMinutes;
  final int score;
  final int? restingHeartRate;
  final double? hrv;
  final SleepStageMinutes? stages;

  /// Time actually asleep: time in bed minus [awakeMinutes]. Clamped to
  /// zero rather than going negative if awake time was over-reported
  /// relative to time in bed.
  Duration get timeAsleep {
    final inBed = wakeTime.difference(bedtime);
    final asleep = inBed - Duration(minutes: awakeMinutes);
    return asleep.isNegative ? Duration.zero : asleep;
  }

  Map<String, dynamic> toJson() => {
        'bedtime': bedtime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
        'awakeMinutes': awakeMinutes,
        'score': score,
        'restingHeartRate': restingHeartRate,
        'hrv': hrv,
        'stages': stages?.toJson(),
      };

  factory SleepEntry.fromJson(DateTime date, Map<String, dynamic> json) => SleepEntry(
        date: date,
        bedtime: DateTime.parse(json['bedtime'] as String),
        wakeTime: DateTime.parse(json['wakeTime'] as String),
        awakeMinutes: (json['awakeMinutes'] as num).toInt(),
        score: (json['score'] as num).toInt(),
        restingHeartRate: (json['restingHeartRate'] as num?)?.toInt(),
        hrv: (json['hrv'] as num?)?.toDouble(),
        stages: json['stages'] == null
            ? null
            : SleepStageMinutes.fromJson(Map<String, dynamic>.from(json['stages'] as Map)),
      );
}

/// Normalizes a [DateTime] to a date-only key (`yyyy-MM-dd`), matching the
/// document-id convention used elsewhere (see `readinessDocId`).
String sleepDocId(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
