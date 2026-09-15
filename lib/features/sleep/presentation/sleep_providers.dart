import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/sleep_repository.dart';

final sleepRepositoryProvider = Provider<SleepRepository>((ref) {
  return SleepRepository(firestore: ref.watch(firestoreProvider));
});
