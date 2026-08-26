import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/body_composition/data/body_composition_repository.dart';
import 'package:fitness_tracker/features/body_composition/domain/body_composition_estimate.dart';
import 'package:fitness_tracker/features/body_composition/domain/body_measurement.dart';

BodyMeasurement _weight(double value, DateTime measuredAt) => BodyMeasurement(
      metric: BodyMetric.weight,
      value: value,
      unit: 'kg',
      measuredAt: measuredAt,
      createdAt: measuredAt,
    );

void main() {
  test('records and lists weight measurements oldest first', () async {
    final repository = BodyCompositionRepository(firestore: FakeFirebaseFirestore());
    final laterWeight = _weight(80, DateTime(2026, 8, 20));
    final earlierWeight = _weight(81, DateTime(2026, 8, 10));

    await repository.recordMeasurement('u', laterWeight);
    await repository.recordMeasurement('u', earlierWeight);

    expect(
      (await repository.listMeasurements('u', BodyMetric.weight)).map((m) => m.value),
      [81, 80],
    );
  });

  test('listMeasurements does not leak other metrics into the result', () async {
    final repository = BodyCompositionRepository(firestore: FakeFirebaseFirestore());

    await repository.recordMeasurement('u', _weight(80, DateTime(2026, 8, 20)));
    await repository.recordMeasurement(
      'u',
      BodyMeasurement(
        metric: BodyMetric.waist,
        value: 90,
        unit: 'cm',
        measuredAt: DateTime(2026, 8, 20),
        createdAt: DateTime(2026, 8, 20),
      ),
    );

    final weights = await repository.listMeasurements('u', BodyMetric.weight);
    expect(weights, hasLength(1));
    expect(weights.single.metric, BodyMetric.weight);
  });

  test('records an estimate independently from raw measurements', () async {
    final repository = BodyCompositionRepository(firestore: FakeFirebaseFirestore());
    final estimate = BodyCompositionEstimate(
      bodyFatPercent: 18.5,
      fatMassKg: 14.8,
      leanBodyMassKg: 65.2,
      method: 'us-navy-circumference',
      calculationVersion: 1,
      sourceMeasurementIds: const ['m1', 'm2'],
      calculatedAt: DateTime(2026, 8, 20),
    );

    await repository.recordEstimate('u', estimate);
    final estimates = await repository.listEstimates('u');

    expect(estimates.single.leanBodyMassKg, estimate.leanBodyMassKg);
    expect(estimates.single.sourceMeasurementIds, estimate.sourceMeasurementIds);
    expect(estimates.single.method, estimate.method);
    expect(estimates.single.calculationVersion, estimate.calculationVersion);
  });
}
