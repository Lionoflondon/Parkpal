import 'package:cloud_firestore/cloud_firestore.dart';

import 'dtro_models.dart';

class DtroLegalService {
  DtroLegalService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<List<DtroLegalRecord>> fetchLegalRecords({int limit = 50}) async {
    final snapshot = await _db
        .collection(DtroCollections.legalRecords)
        .orderBy('lastUpdatedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => DtroLegalRecord.fromMap(doc.id, doc.data()))
        .toList(growable: false);
  }

  DtroLegalRecord normalizeProvision({
    required String troId,
    required DtroAuthority authority,
    required DtroSource source,
    required DtroProvision provision,
    required Map<String, Object?> rawProvision,
    String? version,
    DtroSourceStatus status = DtroSourceStatus.draft,
  }) {
    final id = '${troId}_${provision.provisionId}';
    return DtroLegalRecord(
      id: id,
      troId: troId,
      provisionId: provision.provisionId,
      authority: authority,
      source: source,
      regulationType: provision.regulationType,
      irisLabel: dtroIrisLabel(provision.regulationType),
      irisExplanation: dtroIrisExplanation(provision.regulationType),
      conditions: provision.conditions,
      geometry: provision.geometry,
      confidence: 0.75,
      verificationStatus: DtroVerificationStatus.pending,
      status: status,
      version: version,
      lastUpdatedAt: DateTime.now().toUtc(),
      rawProvision: rawProvision,
    );
  }

  Future<void> storeImportReadyOrder({
    required TrafficRegulationOrder order,
    required List<DtroLegalRecord> legalRecords,
  }) async {
    final db = _db;
    final batch = db.batch();
    batch.set(
      db.collection(DtroCollections.rawOrders).doc(order.troId),
      {
        ...order.toRawOrderMap(),
        'rawDtroJson': order.rawDtroJson,
        'storedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    for (final record in legalRecords) {
      batch.set(
        db.collection(DtroCollections.legalRecords).doc(record.id),
        {
          ...record.toMap(),
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }
}
