import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/readiness_repository.dart';

final readinessRepositoryProvider = Provider<ReadinessRepository>((ref) {
  return ReadinessRepository(firestore: ref.watch(firestoreProvider));
});
