import 'package:cloud_firestore/cloud_firestore.dart';

/// Mirrors `functions/src/ai/schemas.ts`'s `ProposedCommand` union. Purely a
/// read model on the client — the client never constructs or mutates one of
/// these to drive a write; it only displays what the server proposed and
/// sends an accept/reject decision back via `handleCommand`.
class ProposedCommand {
  const ProposedCommand({required this.type, required this.raw});

  final String type;

  /// The full proposal payload as returned by the server, kept as an
  /// untyped map for display purposes (each `type` has different fields).
  final Map<String, dynamic> raw;

  factory ProposedCommand.fromJson(Map<String, dynamic> json) =>
      ProposedCommand(type: json['type'] as String? ?? 'unknown', raw: json);
}

enum RecommendationStatus { pending, accepted, rejected }

/// A read-only client model of `users/{uid}/coachRecommendations/{id}`.
/// Server-written only (see `firestore.rules`); the client's only mutation
/// path is calling the `handleCommand` callable.
class CoachRecommendation {
  const CoachRecommendation({
    required this.id,
    required this.summary,
    required this.rationale,
    required this.status,
    required this.createdAt,
    this.proposedCommand,
    this.contextSchemaVersion,
  });

  final String id;
  final String summary;
  final String rationale;
  final RecommendationStatus status;
  final DateTime createdAt;
  final ProposedCommand? proposedCommand;
  final int? contextSchemaVersion;

  factory CoachRecommendation.fromJson(String id, Map<String, dynamic> json) {
    final rawCommand = json['proposedCommand'];
    final createdAtRaw = json['createdAt'];
    return CoachRecommendation(
      id: id,
      summary: json['summary'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
      status: RecommendationStatus.values.byName((json['status'] as String?) ?? 'pending'),
      createdAt: createdAtRaw is Timestamp
          ? createdAtRaw.toDate()
          : createdAtRaw is String
              ? DateTime.parse(createdAtRaw)
              : DateTime.now(),
      proposedCommand: rawCommand is Map
          ? ProposedCommand.fromJson(Map<String, dynamic>.from(rawCommand))
          : null,
      contextSchemaVersion: (json['contextSchemaVersion'] as num?)?.toInt(),
    );
  }
}
