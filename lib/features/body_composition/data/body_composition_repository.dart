import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/body_composition_estimate.dart';
import '../domain/body_measurement.dart';

/// Persists raw body measurements and derived body-composition estimates as
/// two separate Firestore collections, so historical raw readings are never
/// overwritten by (or coupled to) later recalculations of derived data.
class BodyCompositionRepository {
  BodyCompositionRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _measurements(String uid) =>
      _firestore.collection('users').doc(uid).collection('bodyMeasurements');

  CollectionReference<Map<String, dynamic>> _estimates(String uid) =>
      _firestore.collection('users').doc(uid).collection('bodyCompositionRecords');

  Future<String> recordMeasurement(String uid, BodyMeasurement measurement) async {
    final doc = await _measurements(uid).add(measurement.toJson());
    return doc.id;
  }

  Future<String> recordEstimate(String uid, BodyCompositionEstimate estimate) async {
    final doc = await _estimates(uid).add(estimate.toJson());
    return doc.id;
  }

  Future<List<BodyMeasurement>> listMeasurements(String uid, BodyMetric metric) async {
    final snapshot = await _measurements(uid)
        .where('metric', isEqualTo: metric.name)
        .orderBy('measuredAt')
        .get();
    return snapshot.docs.map((doc) => BodyMeasurement.fromJson(doc.data())).toList();
  }

  Future<List<BodyCompositionEstimate>> listEstimates(String uid) async {
    final snapshot = await _estimates(uid).orderBy('calculatedAt').get();
    return snapshot.docs.map((doc) => BodyCompositionEstimate.fromJson(doc.data())).toList();
  }
}
