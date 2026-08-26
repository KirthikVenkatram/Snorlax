import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/body_composition_repository.dart';

final bodyCompositionRepositoryProvider = Provider<BodyCompositionRepository>((ref) {
  return BodyCompositionRepository(firestore: ref.watch(firestoreProvider));
});
