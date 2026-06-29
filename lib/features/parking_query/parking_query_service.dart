import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import 'parking_lookup_result.dart';

class ParkingQueryService {
  ParkingQueryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  Future<ParkingLookupResult> search(String queryText) async {
    final trimmedQuery = queryText.trim();
    if (trimmedQuery.isEmpty) return ParkingLookupResult.unknown();

    final firestore = await _safeFirestore();
    if (firestore == null) return ParkingLookupResult.unknown();

    final normalizedQuery = _normalize(trimmedQuery);
    final result = await _lookupVerifiedSign(firestore, trimmedQuery) ??
        await _lookupRoad(firestore, normalizedQuery) ??
        await _lookupZone(firestore, trimmedQuery) ??
        await _lookupConnectImport(firestore, trimmedQuery) ??
        await _lookupUnverifiedSignal(firestore, trimmedQuery) ??
        ParkingLookupResult.unknown();

    await _logQuery(
      firestore: firestore,
      queryText: trimmedQuery,
      result: result,
    );

    return result;
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

  Future<ParkingLookupResult?> _lookupRoad(
    FirebaseFirestore firestore,
    String normalizedQuery,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.roads)
        .where('normalizedStreetName', isEqualTo: normalizedQuery)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    final risk = _titleCase(data['parkingRisk'] as String? ?? 'unknown');
    final summary = data['defaultSummary'] as String?;

    return ParkingLookupResult(
      canPark: CanParkStatus.unknown,
      ruleSummary: summary ??
          'Road-level data exists, but ParkPal needs a verified sign before giving a yes/no answer.',
      timeWindow: 'Check nearby signs',
      paymentRequired: PaymentRequiredStatus.unknown,
      riskLevel: risk,
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0,
      evidenceSource: ParkingEvidenceSource.seedData,
      evidenceReason:
          'Matched road-level intelligence. Verified signs and admin rules still take priority.',
    );
  }

  Future<ParkingLookupResult?> _lookupVerifiedSign(
    FirebaseFirestore firestore,
    String queryText,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: queryText)
        .where('verificationStatus', isEqualTo: 'verified')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final docs = snapshot.docs
        .where((doc) => doc.data()['source'] != 'imported_dataset')
        .toList(growable: false);
    if (docs.isEmpty) return null;

    final data = docs.first.data();
    final isAdmin = data['capturedByRole'] == 'admin';
    final parkingAllowed = data['parkingAllowed'] as bool?;
    final paymentRequired = (data['permitRequired'] == true)
        ? PaymentRequiredStatus.yes
        : PaymentRequiredStatus.unknown;

    return ParkingLookupResult(
      canPark: _canParkFromBool(parkingAllowed),
      ruleSummary: data['restrictionSummary'] as String? ??
          'Verified ParkPal sign evidence found for this location.',
      timeWindow: data['activeHours'] as String? ?? 'Unknown',
      paymentRequired: paymentRequired,
      riskLevel: 'Medium',
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0.9,
      evidenceSource: isAdmin
          ? ParkingEvidenceSource.adminVerifiedRule
          : ParkingEvidenceSource.verifiedSign,
      evidenceReason: isAdmin
          ? 'Matched an admin-verified ParkPal rule. This is the highest-ranked evidence.'
          : 'Matched a verified ParkPal sign capture. Imported Connect data cannot override this.',
    );
  }

  Future<ParkingLookupResult?> _lookupZone(
    FirebaseFirestore firestore,
    String queryText,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.zones)
        .where('zoneName', isEqualTo: queryText)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    final zoneType = data['zoneType'] as String?;
    final canPark = zoneType == 'red_route' || zoneType == 'school_street'
        ? CanParkStatus.no
        : CanParkStatus.unknown;

    return ParkingLookupResult(
      canPark: canPark,
      ruleSummary: data['rulesSummary'] as String? ??
          'Zone data found. Check local signs for bay-level rules.',
      timeWindow: data['activeHours'] as String? ?? 'Unknown',
      paymentRequired: (data['permitRequired'] == true)
          ? PaymentRequiredStatus.yes
          : PaymentRequiredStatus.unknown,
      riskLevel: canPark == CanParkStatus.no ? 'High' : 'Unknown',
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0,
      evidenceSource: ParkingEvidenceSource.seedData,
      evidenceReason:
          'Matched zone/council intelligence. Verified signs and admin rules still take priority.',
    );
  }

  Future<ParkingLookupResult?> _lookupConnectImport(
    FirebaseFirestore firestore,
    String queryText,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: queryText)
        .limit(10)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final importedDocs = snapshot.docs
        .where((doc) => doc.data()['source'] == 'imported_dataset')
        .toList(growable: false);
    if (importedDocs.isEmpty) return null;

    final doc = importedDocs.first;
    final data = doc.data();
    final confidenceState =
        data['confidenceState'] as String? ?? 'official_unverified_field';
    if (confidenceState == 'conflict') {
      return ParkingLookupResult(
        canPark: CanParkStatus.unknown,
        ruleSummary:
            'Imported council/open-data evidence conflicts with field evidence and needs admin review.',
        timeWindow: data['activeHours'] as String? ?? 'Unknown',
        paymentRequired: _paymentFromPermit(data['permitRequired'] as bool?),
        riskLevel: 'Unknown',
        confidenceScore: 0.25,
        evidenceSource: ParkingEvidenceSource.parkpalConnect,
        evidenceReason:
            'Matched ParkPal Connect import ${doc.id}, but it is marked Conflict.',
      );
    }

    return ParkingLookupResult(
      canPark: _canParkFromBool(data['parkingAllowed'] as bool?),
      ruleSummary: data['restrictionSummary'] as String? ??
          data['restrictionType'] as String? ??
          'Council/open-data restriction imported by ParkPal Connect.',
      timeWindow: data['activeHours'] as String? ?? 'Unknown',
      paymentRequired: _paymentFromPermit(data['permitRequired'] as bool?),
      riskLevel: _riskFromImportedRecord(data),
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ??
          _confidenceFromState(confidenceState),
      evidenceSource: ParkingEvidenceSource.parkpalConnect,
      evidenceReason:
          'Matched ParkPal Connect source "${data['sourceName'] ?? 'unknown'}" with confidence state $confidenceState. Higher-priority verified ParkPal evidence was not found.',
    );
  }

  Future<ParkingLookupResult?> _lookupUnverifiedSignal(
    FirebaseFirestore firestore,
    String queryText,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: queryText)
        .where('verificationStatus', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    final data = snapshot.docs.first.data();
    if (data['source'] == 'imported_dataset') return null;

    return ParkingLookupResult(
      canPark: CanParkStatus.unknown,
      ruleSummary:
          'Unverified ParkPal field signal found. ParkPal needs review before making a confident claim.',
      timeWindow: data['activeHours'] as String? ?? 'Unknown',
      paymentRequired: PaymentRequiredStatus.unknown,
      riskLevel: 'Unknown',
      confidenceScore: 0.2,
      evidenceSource: ParkingEvidenceSource.userReport,
      evidenceReason:
          'Matched a user-submitted or Pioneer signal that has not been verified yet.',
    );
  }

  Future<void> _logQuery({
    required FirebaseFirestore firestore,
    required String queryText,
    required ParkingLookupResult result,
  }) async {
    try {
      final userId = (_auth ?? FirebaseAuth.instance).currentUser?.uid;
      final document = firestore.collection(ParkPalCollections.queries).doc();

      await document.set({
        'queryId': document.id,
        'queryText': queryText,
        'userId': userId,
        'queriedAt': FieldValue.serverTimestamp(),
        'resultStatus': result.canParkLabel,
        'riskLevel': result.riskLevel,
        'ruleSummary': result.ruleSummary,
        'timeWindow': result.timeWindow,
        'paymentRequired': result.paymentRequiredLabel,
        'confidence': result.confidenceScore,
        'sourceUsed': result.evidenceSourceLabel,
        'mode': 'parking',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Query logging must never block the user-facing parking answer.
    }
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }

  CanParkStatus _canParkFromBool(bool? value) {
    if (value == true) return CanParkStatus.yes;
    if (value == false) return CanParkStatus.no;
    return CanParkStatus.unknown;
  }

  PaymentRequiredStatus _paymentFromPermit(bool? permitRequired) {
    if (permitRequired == true) return PaymentRequiredStatus.yes;
    if (permitRequired == false) return PaymentRequiredStatus.unknown;
    return PaymentRequiredStatus.unknown;
  }

  String _riskFromImportedRecord(Map<String, Object?> data) {
    if (data['redRoute'] == true ||
        data['busLane'] == true ||
        data['schoolStreet'] == true) {
      return 'High';
    }
    if (data['parkingAllowed'] == false) return 'High';
    return 'Medium';
  }

  double _confidenceFromState(String state) {
    return switch (state) {
      'verified_plus' => 0.85,
      'field_verified' => 0.75,
      'official_unverified_field' => 0.65,
      'conflict' => 0.25,
      _ => 0.5,
    };
  }
}
