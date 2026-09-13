import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../habits/presentation/habit_providers.dart';
import '../../nutrition/presentation/nutrition_providers.dart';
import '../../workouts/presentation/workout_providers.dart';
import '../data/adherence_repository.dart';

final adherenceRepositoryProvider = Provider<AdherenceRepository>((ref) {
  return AdherenceRepository(
    firestore: ref.watch(firestoreProvider),
    nutritionRepository: ref.watch(nutritionRepositoryProvider),
    workoutRepository: ref.watch(workoutRepositoryProvider),
    habitRepository: ref.watch(habitRepositoryProvider),
  );
});
