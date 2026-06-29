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

          if (existing.exists &&
              existing.data()?['verificationStatus'] == 'verified') {
            conflicts++;
            await document
                .collection('parkpal_connect_reviews')
                .doc(importBatchId)
                .set({
              'reviewStatus': 'conflict',
              'conflictNotes':
                  'Imported council/open-data record may conflict with approved ParkPal field data.',
              'incomingRecord': record.rawRecord,
              'sourceId': source.sourceId,
              'sourceName': source.sourceName,
              'createdAt': FieldValue.serverTimestamp(),
            });
            continue;
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
            confidenceScore: 0.65,
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
            'importReviewStatus': 'official_unverified_field',
            'confidenceState': 'official_unverified_field',
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
}
