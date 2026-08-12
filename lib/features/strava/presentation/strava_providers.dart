import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/strava_connection_repository.dart';

final stravaConnectionRepositoryProvider = Provider<StravaConnectionRepository>((ref) {
  return StravaConnectionRepository(firestore: ref.watch(firestoreProvider));
});
