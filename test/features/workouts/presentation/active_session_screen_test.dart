import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/workouts/data/workout_repository.dart';
import 'package:fitness_tracker/features/workouts/domain/workout.dart';
import 'package:fitness_tracker/features/workouts/presentation/active_session_screen.dart';

void main() {
  group('formatSessionDuration', () {
    test('formats mm:ss with zero padding', () {
      expect(formatSessionDuration(0), '00:00');
      expect(formatSessionDuration(5), '00:05');
      expect(formatSessionDuration(65), '01:05');
      expect(formatSessionDuration(600), '10:00');
    });
  });

  // A repeating Timer.periodic never "settles", so these tests use
  // tester.pump(Duration(...)) to advance fake time instead of
  // pumpAndSettle, per this repo's testing convention for ticking timers.
  group('ActiveSessionScreen', () {
    final plan = [
      const ExerciseEntry(
        exerciseName: 'Bench Press',
        sets: [
          SetEntry(reps: 8, weightKg: 60),
          SetEntry(reps: 8, weightKg: 60),
        ],
      ),
      const ExerciseEntry(
        exerciseName: 'Overhead Press',
        sets: [SetEntry(reps: 10, weightKg: 35)],
      ),
    ];

    testWidgets('ticks the timer every second and starts at 0/3 sets', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final workoutRepository = WorkoutRepository(firestore: firestore);

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionScreen(
            uid: 'uid-1',
            workoutRepository: workoutRepository,
            plan: plan,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('0/3 sets'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('tapping a set chip toggles completion and updates the header count', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final workoutRepository = WorkoutRepository(firestore: firestore);

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionScreen(
            uid: 'uid-1',
            workoutRepository: workoutRepository,
            plan: plan,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('60×8').first);
      await tester.pump();

      expect(find.text('1/3 sets'), findsOneWidget);

      // Tapping again un-marks it.
      await tester.tap(find.text('60×8').first);
      await tester.pump();

      expect(find.text('0/3 sets'), findsOneWidget);
    });

    testWidgets(
        'finishing writes only completed sets via WorkoutRepository and navigates to Session complete',
        (tester) async {
      final firestore = FakeFirebaseFirestore();
      final workoutRepository = WorkoutRepository(firestore: firestore);

      await tester.pumpWidget(
        MaterialApp(
          home: ActiveSessionScreen(
            uid: 'uid-1',
            workoutRepository: workoutRepository,
            plan: plan,
          ),
        ),
      );
      await tester.pump();

      // Complete one Bench Press set and the Overhead Press set; leave the
      // second Bench Press set undone.
      await tester.tap(find.text('60×8').first);
      await tester.pump();
      await tester.tap(find.text('35×10').first);
      await tester.pump();

      await tester.tap(find.text('Finish workout'));
      // The write is a real async Firestore call — pump (not pumpAndSettle,
      // which would hang on the still-running timer if it were still
      // mounted) until the navigation lands.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final workouts = await workoutRepository.listWorkouts('uid-1');
      expect(workouts, hasLength(1));
      final saved = workouts.first;
      expect(saved.type, WorkoutType.strength);
      expect(saved.exercises, hasLength(2));
      expect(saved.exercises![0].exerciseName, 'Bench Press');
      expect(saved.exercises![0].sets, hasLength(1));
      expect(saved.exercises![1].exerciseName, 'Overhead Press');
      expect(saved.exercises![1].sets, hasLength(1));

      expect(find.text('SESSION COMPLETE'), findsOneWidget);
      expect(find.textContaining('Quick session logged'), findsOneWidget);
    });

    testWidgets('exiting asks for confirmation before popping', (tester) async {
      final firestore = FakeFirebaseFirestore();
      final workoutRepository = WorkoutRepository(firestore: firestore);

      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (_) => ActiveSessionScreen(
                uid: 'uid-1',
                workoutRepository: workoutRepository,
                plan: plan,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Exit'));
      await tester.pump();

      expect(find.text('Exit workout?'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await tester.pump();

      expect(find.byType(ActiveSessionScreen), findsOneWidget);
    });
  });
}
