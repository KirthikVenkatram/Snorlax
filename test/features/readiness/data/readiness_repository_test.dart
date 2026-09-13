import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/readiness/data/readiness_repository.dart';
import 'package:fitness_tracker/features/readiness/domain/readiness_entry.dart';

void main() {
  final day = DateTime(2026, 9, 13);

  test('getByDate returns null when no check-in exists', () async {
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());
    final entry = await repository.getByDate('u', day);
    expect(entry, isNull);
  });

  test('recordCheckIn computes and persists the deterministic result', () async {
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    final entry = await repository.recordCheckIn(
      'u',
      day,
      const ReadinessInputs(
        sleepHours: 8,
        sleepConsistency: 1.0,
        soreness: 0.0,
        fatigue: 0.0,
        energy: 1.0,
        recentTrainingLoad: 0.0,
      ),
    );

    expect(entry.result.level, ReadinessLevel.green);

    final fetched = await repository.getByDate('u', day);
    expect(fetched, isNotNull);
    expect(fetched!.result.level, ReadinessLevel.green);
    expect(fetched.inputs.sleepHours, 8);
  });

  test('recordCheckIn stores a hard-override red result even for otherwise excellent inputs', () async {
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    final entry = await repository.recordCheckIn(
      'u',
      day,
      const ReadinessInputs(
        sleepHours: 9,
        sleepConsistency: 1.0,
        soreness: 0.0,
        fatigue: 0.0,
        energy: 1.0,
        recentTrainingLoad: 0.0,
        painOrInjury: true,
      ),
    );

    expect(entry.result.level, ReadinessLevel.red);
    expect(entry.result.safetyOverrideTriggered, isTrue);

    final fetched = await repository.getByDate('u', day);
    expect(fetched!.result.level, ReadinessLevel.red);
    expect(fetched.result.safetyOverrideTriggered, isTrue);
  });

  test('recordCheckIn overwrites an existing entry for the same date', () async {
    final repository = ReadinessRepository(firestore: FakeFirebaseFirestore());

    await repository.recordCheckIn(
      'u',
      day,
      const ReadinessInputs(
        sleepHours: 8,
        sleepConsistency: 1.0,
        soreness: 0.0,
        fatigue: 0.0,
        energy: 1.0,
        recentTrainingLoad: 0.0,
      ),
    );
    await repository.recordCheckIn(
      'u',
      day,
      const ReadinessInputs(
        sleepHours: 2,
        sleepConsistency: 0.0,
        soreness: 0.9,
        fatigue: 0.9,
        energy: 0.0,
        recentTrainingLoad: 0.9,
      ),
    );

    final fetched = await repository.getByDate('u', day);
    expect(fetched!.result.level, ReadinessLevel.red);
  });
}
