import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/price_snapshot.dart';

/// Owner-scoped CRUD for `users/{uid}/priceSnapshots/{snapshotId}`.
class PriceRepository {
  PriceRepository({
    required FirebaseFirestore firestore,
    // ignore: prefer_initializing_formals
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _snapshots(String uid) =>
      _firestore.collection('users').doc(uid).collection('priceSnapshots');

  /// Records a new snapshot, letting Firestore generate the id.
  Future<PriceSnapshot> record(String uid, PriceSnapshot snapshot) async {
    final doc = await _snapshots(uid).add(snapshot.toJson());
    return PriceSnapshot(
      id: doc.id,
      itemName: snapshot.itemName,
      price: snapshot.price,
      currency: snapshot.currency,
      unit: snapshot.unit,
      quantity: snapshot.quantity,
      source: snapshot.source,
      timestamp: snapshot.timestamp,
    );
  }

  Future<List<PriceSnapshot>> listForItem(String uid, String itemName) async {
    final snapshot = await _snapshots(uid)
        .where('itemName', isEqualTo: itemName)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs.map((doc) => PriceSnapshot.fromJson(doc.id, doc.data())).toList();
  }

  /// The most recent snapshot for [itemName], or null if none exists yet —
  /// callers must treat that as "no price on file", not as a free item.
  Future<PriceSnapshot?> latestForItem(String uid, String itemName) async {
    final results = await listForItem(uid, itemName);
    return results.isEmpty ? null : results.first;
  }

  Future<List<PriceSnapshot>> listAll(String uid) async {
    final snapshot = await _snapshots(uid).orderBy('timestamp', descending: true).get();
    return snapshot.docs.map((doc) => PriceSnapshot.fromJson(doc.id, doc.data())).toList();
  }
}
