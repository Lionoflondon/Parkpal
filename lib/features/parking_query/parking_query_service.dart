import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import '../parking_intelligence/parking_intelligence_models.dart';
import '../parking_intelligence/parking_intelligence_service.dart';
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

    final result = await ParkingIntelligenceService(firestore: firestore)
        .evaluate(ParkingIntelligenceContext(queryText: trimmedQuery));

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
        'explanation': result.ruleSummary,
        'confidenceReason': result.evidenceReason,
        'mode': 'parking',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Query logging must never block the user-facing parking answer.
    }
  }
}
