import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/firebase/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initCrashlytics();
  runApp(const ProviderScope(child: FitnessTrackerApp()));
}

/// Wires uncaught Flutter framework errors and platform-level async errors
/// through to Crashlytics. This is a personal, single-user app with no
/// analytics/consent flow to gate on, so reporting is unconditional — but
/// initialization itself is wrapped so that Crashlytics being unavailable
/// (e.g. misconfiguration, no network) can never prevent the app from
/// starting.
Future<void> _initCrashlytics() async {
  try {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Crashlytics wiring is best-effort only — never let a setup failure
    // here crash app startup.
  }
}

class FitnessTrackerApp extends ConsumerWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Fitness Tracker',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
