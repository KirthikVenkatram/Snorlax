import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/exercise_library_repository.dart';
import '../data/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(firestore: ref.watch(firestoreProvider));
});

final exerciseLibraryRepositoryProvider = Provider<ExerciseLibraryRepository>((ref) {
  return ExerciseLibraryRepository(firestore: ref.watch(firestoreProvider));
});
