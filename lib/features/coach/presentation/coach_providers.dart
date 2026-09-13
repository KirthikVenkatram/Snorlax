import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/coach_service.dart';

final coachServiceProvider = Provider<CoachService>((ref) {
  return CoachService(
    firestore: ref.watch(firestoreProvider),
    functions: FirebaseFunctions.instance,
  );
});
