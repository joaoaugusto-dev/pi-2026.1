import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:siderapredict/app/features/inspection/model/measurement_record.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, required this.collectionName})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String collectionName;

  CollectionReference<MeasurementRecord> get _collection => _firestore
      .collection(collectionName)
      .withConverter<MeasurementRecord>(
        fromFirestore: (snapshot, _) =>
            MeasurementRecord.fromJson(snapshot.data()!),
        toFirestore: (record, _) => record.toJson(),
      );

  Future<void> saveRecord(MeasurementRecord record) async {
    await _collection.doc(record.id).set(record);
  }

  Future<List<MeasurementRecord>> fetchRecords() async {
    final querySnapshot = await _collection
        .orderBy('createdAt', descending: true)
        .get();
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> deleteRecord(String recordId) async {
    await _collection.doc(recordId).delete();
  }

  Stream<List<MeasurementRecord>> streamRecords() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
