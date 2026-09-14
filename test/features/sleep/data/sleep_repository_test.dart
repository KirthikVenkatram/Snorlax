import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/sleep/data/sleep_repository.dart';
import 'package:fitness_tracker/features/sleep/domain/sleep_entry.dart';

void main() {
  final day = DateTime(2026, 9, 13);
  final bedtime = DateTime(2026, 9, 12, 23, 48);
  final wakeTime = DateTime(2026, 9, 13, 8, 22);

  test('getByDate returns null when no check-in exists', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());
    final entry = await repository.getByDate('u', day);
    expect(entry, isNull);
  });

  test('recordCheckIn persists and getByDate reads it back', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());

    final entry = await repository.recordCheckIn(
      'u',
      day,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakeMinutes: 34,
      score: 82,
      restingHeartRate: 62,
      hrv: 58.0,
      stages: const SleepStageMinutes(awake: 34, rem: 82, deep: 64, light: 252),
    );

    expect(entry.score, 82);

    final fetched = await repository.getByDate('u', day);
    expect(fetched, isNotNull);
    expect(fetched!.bedtime, bedtime);
    expect(fetched.wakeTime, wakeTime);
    expect(fetched.restingHeartRate, 62);
    expect(fetched.hrv, 58.0);
    expect(fetched.stages!.rem, 82);
  });

  test('recordCheckIn without stage data leaves stages null', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());

    await repository.recordCheckIn(
      'u',
      day,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakeMinutes: 20,
      score: 70,
    );

    final fetched = await repository.getByDate('u', day);
    expect(fetched!.stages, isNull);
    expect(fetched.restingHeartRate, isNull);
    expect(fetched.hrv, isNull);
  });

  test('recordCheckIn overwrites an existing entry for the same date', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());

    await repository.recordCheckIn(
      'u',
      day,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakeMinutes: 34,
      score: 82,
    );
    await repository.recordCheckIn(
      'u',
      day,
      bedtime: bedtime,
      wakeTime: wakeTime,
      awakeMinutes: 90,
      score: 40,
    );

    final fetched = await repository.getByDate('u', day);
    expect(fetched!.score, 40);
    expect(fetched.awakeMinutes, 90);
  });

  test('listRecent returns nights newest first, limited to the requested count', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());

    for (var i = 0; i < 10; i++) {
      final d = day.subtract(Duration(days: i));
      await repository.recordCheckIn(
        'u',
        d,
        bedtime: d.subtract(const Duration(hours: 8)),
        wakeTime: d,
        awakeMinutes: 10,
        score: 60 + i,
      );
    }

    final recent = await repository.listRecent('u', 7);

    expect(recent.length, 7);
    expect(recent.first.date, day);
    expect(recent.last.date, day.subtract(const Duration(days: 6)));
  });

  test('listRecent returns an empty list when there are no check-ins', () async {
    final repository = SleepRepository(firestore: FakeFirebaseFirestore());
    final recent = await repository.listRecent('u', 7);
    expect(recent, isEmpty);
  });
}
