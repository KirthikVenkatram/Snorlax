// lib/features/auth/data/user_profile_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/calculations/nutrition_goal_calculator.dart';

class UserProfile {
  const UserProfile({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.sex,
    required this.activityLevel,
    required this.goal,
    required this.targets,
  });

  final int age;
  final double weightKg;
  final double heightCm;
  final Sex sex;
  final ActivityLevel activityLevel;
  final Goal goal;
  final NutritionTargets targets;

  Map<String, dynamic> toJson() => {
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'sex': sex.name,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
        'targets': {
          'calories': targets.calories,
          'proteinGrams': targets.proteinGrams,
          'carbsGrams': targets.carbsGrams,
          'fatGrams': targets.fatGrams,
        },
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final targetsJson = json['targets'] as Map<String, dynamic>;
    return UserProfile(
      age: json['age'] as int,
      weightKg: (json['weightKg'] as num).toDouble(),
      heightCm: (json['heightCm'] as num).toDouble(),
      sex: Sex.values.byName(json['sex'] as String),
      activityLevel: ActivityLevel.values.byName(json['activityLevel'] as String),
      goal: Goal.values.byName(json['goal'] as String),
      targets: NutritionTargets(
        calories: targetsJson['calories'] as int,
        proteinGrams: (targetsJson['proteinGrams'] as num).toDouble(),
        carbsGrams: (targetsJson['carbsGrams'] as num).toDouble(),
        fatGrams: (targetsJson['fatGrams'] as num).toDouble(),
      ),
    );
  }
}

class UserProfileRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firestore` while the backing field
  // stays private as `_firestore`)
  UserProfileRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<void> saveProfile(String uid, UserProfile profile) async {
    await _firestore.collection('users').doc(uid).set(profile.toJson());
  }

  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!);
  }
}
