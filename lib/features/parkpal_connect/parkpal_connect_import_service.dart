import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import '../../data/models/model_helpers.dart';
import '../../data/models/parkpal_models.dart';
import 'parkpal_connect_normalizer.dart';
import 'parkpal_connect_source.dart';

class ParkPalConnectImportResult {
  const ParkPalConnectImportResult({
    required this.imported,
    required this.skipped,
    required this.failed,
    required this.conflicts,
    this.messages = const [],
  });

  final int imported;
  final int skipped;
  final int failed;
  final int conflicts;
  final List<String> messages;

  static const empty = ParkPalConnectImportResult(
    imported: 0,
    skipped: 0,
    failed: 0,
    conflicts: 0,
  );
}

class ParkPalConnectImportService {
  ParkPalConnectImportService({
    FirebaseFirestore? firestore,
    ParkPalConnectNormalizer normalizer = const ParkPalConnectNormalizer(),
  })  : _firestore = firestore,
        _normalizer = normalizer;

  final FirebaseFirestore? _firestore;
  final ParkPalConnectNormalizer _normalizer;

  Future<ParkPalConnectImportResult> importRaw({
    required ParkPalConnectSource source,
    required String rawData,
  }) async {
    final importBatchId =
        DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    final messages = <String>[];
    var imported = 0;
    var skipped = 0;
    var failed = 0;
    var conflicts = 0;

    try {
      final firestore = await _safeFirestore();
      if (firestore == null) {
        return const ParkPalConnectImportResult(
          imported: 0,
          skipped: 0,
          failed: 1,
          conflicts: 0,
          messages: ['Firestore unavailable.'],
        );
      }

      if (!source.enabled) {
        return const ParkPalConnectImportResult(
          imported: 0,
          skipped: 1,
          failed: 0,
          conflicts: 0,
          messages: ['Source disabled.'],
        );
      }

      final records = _normalizer.parseRaw(
        source: source,
        rawData: rawData,
        importBatchId: importBatchId,
      );

      if (records.isEmpty) {
        return const ParkPalConnectImportResult(
          imported: 0,
          skipped: 1,
          failed: 0,
          conflicts: 0,
          messages: ['No valid records found.'],
        );
      }

      for (final record in records) {
        try {
          final documentId =
              _documentId(source.sourceId, record.externalRecordId);
          final document =
              firestore.collection(ParkPalCollections.signs).doc(documentId);
          final existing = await document.get();
          if (existing.exists) {
            await document
                .collection('parkpal_connect_history')
                .doc(importBatchId)
                .set({
              'previousData': existing.data(),
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }

          if (existing.exists &&
              existing.data()?['verificationStatus'] == 'verified') {
            conflicts++;
            await _writeConflictReview(
              document: document,
              importBatchId: importBatchId,
              source: source,
              record: record,
              conflictNotes:
                  'Imported record targets an already verified repository record and was not overwritten.',
            );
            continue;
          }

          final approvedSign = await _findApprovedFieldSign(firestore, record);
          final approvedData = approvedSign?.data();
          final confidenceState = approvedData == null
              ? 'official_unverified_field'
              : _recordsAgree(record, approvedData)
                  ? 'verified_plus'
                  : 'conflict';

          if (confidenceState == 'conflict') {
            conflicts++;
            await _writeConflictReview(
              document: document,
              importBatchId: importBatchId,
              source: source,
              record: record,
              conflictNotes:
                  'Council/open-data import disagrees with approved ParkPal field sign ${approvedSign?.id}.',
            );
          }

          final sign = ParkPalSign(
            signId: documentId,
            photoUrl: '',
            thumbnailUrl: '',
            capturedByUserId: source.sourceId,
            capturedByRole: CapturedByRole.admin,
            capturedAt: FieldValue.serverTimestamp(),
            geoPoint: ParkPalGeoPoint(
              latitude: record.latitude,
              longitude: record.longitude,
            ),
            latitude: record.latitude,
            longitude: record.longitude,
            streetName: record.streetName,
            borough: record.borough,
            council: record.council,
            postcode: record.postcode ?? '',
            restrictionType: record.restrictionType,
            activeDays: record.activeDays,
            activeHours: record.activeHours,
            maxStayMinutes: record.maxStayMinutes,
            parkingAllowed: record.parkingAllowed,
            loadingAllowed: record.loadingAllowed,
            permitRequired: record.permitRequired,
            redRoute: record.redRoute,
            busLane: record.busLane,
            schoolStreet: record.schoolStreet,
            confidenceScore: _confidenceForState(confidenceState),
            verificationStatus: VerificationStatus.pending,
            source: SignSource.imported_dataset,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          );

          await document.set({
            ...sign.toJson(),
            'sourceId': source.sourceId,
            'sourceName': record.sourceName,
            'sourceUrl': record.sourceUrl,
            'sourceUpdatedAt': record.sourceUpdatedAt == null
                ? null
                : Timestamp.fromDate(record.sourceUpdatedAt!),
            'externalRecordId': record.externalRecordId,
            'importBatchId': record.importBatchId,
            'matchedVerifiedSignId': approvedSign?.id,
            'importReviewStatus': confidenceState,
            'confidenceState': confidenceState,
            'conflictNotes': confidenceState == 'conflict'
                ? 'Imported council/open-data record disagrees with approved ParkPal field data.'
                : null,
            'rawImportedRecord': record.rawRecord,
          }, SetOptions(merge: true));
          imported++;
        } catch (error) {
          failed++;
          messages.add('Failed record ${record.externalRecordId}: $error');
        }
      }
    } catch (error) {
      failed++;
      messages.add('Import failed: $error');
    }

    return ParkPalConnectImportResult(
      imported: imported,
      skipped: skipped,
      failed: failed,
      conflicts: conflicts,
      messages: messages,
    );
  }

  Future<ParkPalConnectImportResult> importFromSource({
    required ParkPalConnectSource source,
    String? rawData,
  }) async {
    if (rawData == null || rawData.trim().isEmpty) {
      return const ParkPalConnectImportResult(
        imported: 0,
        skipped: 1,
        failed: 0,
        conflicts: 0,
        messages: [
          'No raw data supplied. Add fetch adapter for this source before live import.',
        ],
      );
    }
    return importRaw(source: source, rawData: rawData);
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  String _documentId(String sourceId, String externalRecordId) {
    final safeSource = sourceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeRecord =
        externalRecordId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'connect_${safeSource}_$safeRecord';
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findApprovedFieldSign(
    FirebaseFirestore firestore,
    ParkPalConnectRecord record,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: record.streetName)
        .where('verificationStatus', isEqualTo: 'verified')
        .limit(10)
        .get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['source'] == 'imported_dataset') continue;
      if ((data['council'] as String?)?.toLowerCase() !=
          record.council.toLowerCase()) {
        continue;
      }
      return doc;
    }
    return null;
  }

  bool _recordsAgree(
    ParkPalConnectRecord record,
    Map<String, Object?> approvedData,
  ) {
    return _nullableBoolAgrees(
            record.parkingAllowed, approvedData['parkingAllowed']) &&
        _nullableBoolAgrees(
            record.loadingAllowed, approvedData['loadingAllowed']) &&
        _nullableBoolAgrees(
            record.permitRequired, approvedData['permitRequired']) &&
        _nullableBoolAgrees(record.redRoute, approvedData['redRoute']) &&
        _nullableBoolAgrees(record.busLane, approvedData['busLane']) &&
        _nullableBoolAgrees(
            record.schoolStreet, approvedData['schoolStreet']) &&
        _nullableTextAgrees(record.activeHours, approvedData['activeHours']) &&
        _nullableIntAgrees(
            record.maxStayMinutes, approvedData['maxStayMinutes']);
  }

  bool _nullableBoolAgrees(bool? importedValue, Object? approvedValue) {
    if (importedValue == null || approvedValue == null) return true;
    return approvedValue == importedValue;
  }

  bool _nullableTextAgrees(String? importedValue, Object? approvedValue) {
    if (importedValue == null || approvedValue == null) return true;
    return approvedValue.toString().trim().toLowerCase() ==
        importedValue.trim().toLowerCase();
  }

  bool _nullableIntAgrees(int? importedValue, Object? approvedValue) {
    if (importedValue == null || approvedValue == null) return true;
    return approvedValue == importedValue;
  }

  double _confidenceForState(String confidenceState) {
    return switch (confidenceState) {
      'verified_plus' => 0.85,
      'field_verified' => 0.75,
      'official_unverified_field' => 0.65,
      'conflict' => 0.25,
      _ => 0.5,
    };
  }

  Future<void> _writeConflictReview({
    required DocumentReference<Map<String, dynamic>> document,
    required String importBatchId,
    required ParkPalConnectSource source,
    required ParkPalConnectRecord record,
    required String conflictNotes,
  }) async {
    await document
        .collection('parkpal_connect_reviews')
        .doc(importBatchId)
        .set({
      'reviewStatus': 'conflict',
      'conflictNotes': conflictNotes,
      'incomingRecord': record.rawRecord,
      'sourceId': source.sourceId,
      'sourceName': source.sourceName,
      'requestFreshPioneerPhoto': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
