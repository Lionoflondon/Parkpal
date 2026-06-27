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
    final result = await _lookupRoad(firestore, normalizedQuery) ??
        await _lookupSign(firestore, trimmedQuery) ??
        await _lookupZone(firestore, trimmedQuery) ??
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
    );
  }

  Future<ParkingLookupResult?> _lookupSign(
    FirebaseFirestore firestore,
    String queryText,
  ) async {
    final snapshot = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: queryText)
        .where('verificationStatus', whereIn: ['verified', 'pending'])
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final data = snapshot.docs.first.data();
    final isVerified = data['verificationStatus'] == 'verified';
    final parkingAllowed = data['parkingAllowed'] as bool?;
    final paymentRequired = (data['permitRequired'] == true)
        ? PaymentRequiredStatus.yes
        : PaymentRequiredStatus.unknown;

    return ParkingLookupResult(
      canPark: isVerified ? _canParkFromBool(parkingAllowed) : CanParkStatus.unknown,
      ruleSummary: data['restrictionSummary'] as String? ??
          'Sign data found, but ParkPal needs more verification before making a confident claim.',
      timeWindow: data['activeHours'] as String? ?? 'Unknown',
      paymentRequired: paymentRequired,
      riskLevel: isVerified ? 'Medium' : 'Unknown',
      confidenceScore: isVerified
          ? ((data['confidenceScore'] as num?)?.toDouble() ?? 0)
          : 0,
      evidenceSource:
          isVerified ? ParkingEvidenceSource.verifiedSign : ParkingEvidenceSource.seedData,
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
}
