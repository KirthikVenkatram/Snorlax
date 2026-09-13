import 'package:cloud_firestore/cloud_firestore.dart';

/// A read-only client model of `users/{uid}/coachEvents/{id}` — the audit
/// trail of every decision `handleCommand` made server-side. Server-written
/// only; the client never writes to this collection (see `firestore.rules`).
class CoachEvent {
  const CoachEvent({
    required this.id,
    required this.recommendationId,
    required this.outcome,
    required this.reason,
    required this.decision,
    required this.createdAt,
  });

  final String id;
  final String recommendationId;
  final String outcome;
  final String reason;
  final String decision;
  final DateTime createdAt;

  factory CoachEvent.fromJson(String id, Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    return CoachEvent(
      id: id,
      recommendationId: json['recommendationId'] as String? ?? '',
      outcome: json['outcome'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      decision: json['decision'] as String? ?? '',
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : createdAtRaw is String
              ? DateTime.parse(createdAtRaw)
              : DateTime.now(),
    );
  }
}
