import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../firebase/parkpal_firebase_options.dart';
import 'aie_models.dart';

class AieApiService {
  AieApiService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<List<Map<String, Object?>>> searchRoad(String query) async {
    final firestore = await _safeFirestore();
    if (firestore == null || query.trim().isEmpty) return const [];
    final normalized = query.trim();
    final snapshot = await firestore
        .collection(AieCollections.atlasRoads)
        .where('roadName', isGreaterThanOrEqualTo: normalized)
        .where('roadName', isLessThan: '$normalized\uf8ff')
        .limit(20)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<List<AieStructuredRestriction>> getParkingRules(String roadId) async {
    final data = await _roadData(roadId);
    return (data?['currentParkingRules'] as List?)
            ?.whereType<Map>()
            .map((value) =>
                AieStructuredRestriction.fromMap(value.cast<String, dynamic>()))
            .toList(growable: false) ??
        const [];
  }

  Future<List<Map<String, Object?>>> getCouncilHistory(String council) async {
    final firestore = await _safeFirestore();
    if (firestore == null) return const [];
    final snapshot = await firestore
        .collection(AieCollections.importLogs)
        .where('council', isEqualTo: council)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> getRoadHistory(String roadId) async {
    final firestore = await _safeFirestore();
    if (firestore == null) return const [];
    final snapshot = await firestore
        .collection(AieCollections.atlasRoads)
        .doc(roadId)
        .collection('versions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> getEvidence(String roadId) async {
    final firestore = await _safeFirestore();
    if (firestore == null) return const [];
    final snapshot = await firestore
        .collection('parkpalEvidenceRecords')
        .where('roadId', isEqualTo: roadId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<double> getConfidence(String roadId) async {
    final data = await _roadData(roadId);
    return (data?['confidencePercent'] as num?)?.toDouble() ?? 0;
  }

  Future<List<Map<String, Object?>>> getConflicts(String roadId) async {
    final firestore = await _safeFirestore();
    if (firestore == null) return const [];
    final snapshot = await firestore
        .collection(AieCollections.conflicts)
        .where('roadId', isEqualTo: roadId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList(growable: false);
  }

  Future<Map<String, Object?>> getRoadHealth(String roadId) async {
    final data = await _roadData(roadId);
    return {
      'roadId': roadId,
      'roadHealth': data?['roadHealth'] ?? 0,
      'stalenessScore': data?['stalenessScore'] ?? 100,
      'lastCouncilUpdate': data?['lastCouncilUpdate'],
      'lastVerified': data?['lastVerified'],
      'confidencePercent': data?['confidencePercent'] ?? 0,
    };
  }

  Future<Map<String, Object?>> getCoverage(String roadId) async {
    final data = await _roadData(roadId);
    return {
      'roadId': roadId,
      'coverageScore': data?['coverageScore'] ?? 0,
      'currentRuleCount': (data?['currentParkingRules'] as List?)?.length ?? 0,
      'activeConflicts': data?['activeConflicts'] ?? const [],
    };
  }

  Future<Map<String, dynamic>?> _roadData(String roadId) async {
    final firestore = await _safeFirestore();
    if (firestore == null) return null;
    final snapshot =
        await firestore.collection(AieCollections.atlasRoads).doc(roadId).get();
    return snapshot.data();
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
      }
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
}
