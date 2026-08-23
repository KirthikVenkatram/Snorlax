import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalCategory { primary, physique, performance, lifestyle }

enum GoalStatus { active, paused, completed, archived }

class FitnessGoal {
  const FitnessGoal({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.targetValue,
    this.unit,
    this.baselineValue,
    this.currentValue,
    this.targetDate,
    this.metadata = const {},
  });

  final String id;
  final String name;
  final GoalCategory category;
  final GoalStatus status;
  final int priority;
  final double? targetValue;
  final String? unit;
  final double? baselineValue;
  final double? currentValue;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.name,
        'status': status.name,
        'priority': priority,
        if (targetValue != null) 'targetValue': targetValue,
        if (unit != null) 'unit': unit,
        if (baselineValue != null) 'baselineValue': baselineValue,
        if (currentValue != null) 'currentValue': currentValue,
        if (targetDate != null) 'targetDate': Timestamp.fromDate(targetDate!),
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        if (metadata.isNotEmpty) 'metadata': metadata,
      };

  factory FitnessGoal.fromJson(String id, Map<String, dynamic> json) => FitnessGoal(
        id: id,
        name: json['name'] as String,
        category: GoalCategory.values.byName(json['category'] as String),
        status: GoalStatus.values.byName(json['status'] as String),
        priority: json['priority'] as int,
        targetValue: (json['targetValue'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        baselineValue: (json['baselineValue'] as num?)?.toDouble(),
        currentValue: (json['currentValue'] as num?)?.toDouble(),
        targetDate: (json['targetDate'] as Timestamp?)?.toDate(),
        createdAt: (json['createdAt'] as Timestamp).toDate(),
        updatedAt: (json['updatedAt'] as Timestamp).toDate(),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      );
}
