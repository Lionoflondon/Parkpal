import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import 'parkpal_atlas_models.dart';

class ParkPalAtlasCollections {
  const ParkPalAtlasCollections._();

  static const roadProfiles = 'parkpal_atlas_roads';
  static const inspectorFindings = 'parkpal_iris_inspector_findings';
  static const pioneerMissions = 'parkpal_pioneer_missions';
}

class ParkPalAtlasService {
  ParkPalAtlasService({FirebaseFirestore? firestore}) : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<AtlasSummary> fetchNationalSummary() async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return _emptySummary;

      final snapshot = await firestore
          .collection(ParkPalAtlasCollections.roadProfiles)
          .limit(500)
          .get();
      final profiles = snapshot.docs
          .map((doc) => ParkPalAtlasRoadProfile.fromMap(doc.id, doc.data()))
          .toList(growable: false);
      return _summaryFromProfiles(profiles);
    } catch (_) {
      return _emptySummary;
    }
  }

  Future<AtlasSummary> fetchCitySummary(String city) async {
    return _fetchScopedSummary('city', city);
  }

  Future<AtlasSummary> fetchBoroughSummary(String borough) async {
    return _fetchScopedSummary('borough', borough);
  }

  Future<List<ParkPalAtlasRoadProfile>> fetchRoadsNeedingReview({
    int limit = 20,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final snapshot = await firestore
          .collection(ParkPalAtlasCollections.roadProfiles)
          .where('status', whereIn: [
            AtlasRoadStatus.awaiting_verification.name,
            AtlasRoadStatus.conflict.name,
            AtlasRoadStatus.needs_refresh.name,
            AtlasRoadStatus.unmapped.name,
          ])
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ParkPalAtlasRoadProfile.fromMap(doc.id, doc.data()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<IrisInspectorFinding>> fetchInspectorFindings({
    int limit = 20,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final snapshot = await firestore
          .collection(ParkPalAtlasCollections.inspectorFindings)
          .orderBy('updatedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return IrisInspectorFinding(
          id: data['id'] as String? ?? doc.id,
          roadId: data['roadId'] as String? ?? '',
          title: data['title'] as String? ?? 'Inspector finding',
          notes: data['inspectorNotes'] as String? ?? '',
          state: IrisInspectorState.values.firstWhere(
            (state) => state.name == data['state'],
            orElse: () => IrisInspectorState.watch,
          ),
          priority: IrisInspectorPriority.values.firstWhere(
            (priority) => priority.name == data['priority'],
            orElse: () => IrisInspectorPriority.medium,
          ),
          recommendedMissionType:
              data['recommendedMissionType'] as String? ?? 'review',
          createdAt: _dateFromTimestamp(data['createdAt']),
          updatedAt: _dateFromTimestamp(data['updatedAt']),
        );
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<ParkPalAtlasRoadProfile?> buildRoadProfileFromRepository({
    required String roadId,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return null;

      final road = await firestore
          .collection(ParkPalCollections.roads)
          .doc(roadId)
          .get();
      if (!road.exists) return null;
      final roadData = road.data() ?? const <String, dynamic>{};
      final roadName = roadData['streetName'] as String? ?? roadId;

      final signs = await firestore
          .collection(ParkPalCollections.signs)
          .where('streetName', isEqualTo: roadName)
          .limit(200)
          .get();

      var verifiedSigns = 0;
      var councilRecords = 0;
      var fieldVerifiedRecords = 0;
      var conflicts = 0;
      var staleRecords = 0;
      var missingGps = 0;
      var missingFieldPhotos = 0;
      var lowConfidence = 0;
      DateTime? lastFieldVerificationAt;
      DateTime? lastCouncilSyncAt;

      for (final doc in signs.docs) {
        final data = doc.data();
        final source = data['source'];
        final verificationStatus = data['verificationStatus'];
        final confidenceState = data['confidenceState'];

        if (verificationStatus == 'verified') {
          verifiedSigns++;
          fieldVerifiedRecords++;
          lastFieldVerificationAt = _latest(
              lastFieldVerificationAt, _dateFromTimestamp(data['verifiedAt']));
        }
        if (source == 'imported_dataset' || source == 'council_data') {
          councilRecords++;
          lastCouncilSyncAt = _latest(
              lastCouncilSyncAt, _dateFromTimestamp(data['sourceUpdatedAt']));
        }
        if (confidenceState == 'conflict') conflicts++;
        if (data['stale'] == true || confidenceState == 'stale') staleRecords++;
        if (data['latitude'] == null || data['longitude'] == null) missingGps++;
        if ((data['photoUrl'] as String?)?.isEmpty ?? true) {
          missingFieldPhotos++;
        }
        if (((data['confidenceScore'] as num?)?.toDouble() ?? 0) < 0.5) {
          lowConfidence++;
        }
      }

      final totalAssets = signs.docs.length;
      final coveragePercent = totalAssets == 0
          ? 0.0
          : calculateCoveragePercent(
              verifiedRoads: verifiedSigns > 0 && conflicts == 0 ? 1 : 0,
              totalKnownRoads: 1,
            );
      final pciScore = calculatePciScore(
        coveragePercent: coveragePercent,
        conflicts: conflicts,
        staleRecords: staleRecords,
        missingGps: missingGps,
        missingFieldPhotos: missingFieldPhotos,
        councilSignMismatches: conflicts,
        lowConfidence: lowConfidence,
      );

      return ParkPalAtlasRoadProfile(
        roadId: roadId,
        roadName: roadName,
        borough: roadData['borough'] as String? ?? 'Unknown borough',
        council: roadData['council'] as String? ?? 'Unknown council',
        city: roadData['city'] as String? ?? 'London',
        country: roadData['country'] as String? ?? 'UK',
        totalParkingAssets: totalAssets,
        verifiedSigns: verifiedSigns,
        councilRecords: councilRecords,
        fieldVerifiedRecords: fieldVerifiedRecords,
        conflicts: conflicts,
        staleRecords: staleRecords,
        activeMissions: 0,
        coveragePercent: coveragePercent,
        pciScore: pciScore,
        status: _statusFor(
          totalAssets: totalAssets,
          verifiedSigns: verifiedSigns,
          conflicts: conflicts,
          staleRecords: staleRecords,
          councilRecords: councilRecords,
        ),
        lastFieldVerificationAt: lastFieldVerificationAt,
        lastCouncilSyncAt: lastCouncilSyncAt,
        lastIrisReviewAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> saveRoadProfile(ParkPalAtlasRoadProfile profile) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return false;
      final doc = firestore
          .collection(ParkPalAtlasCollections.roadProfiles)
          .doc(profile.roadId);
      final existing = await doc.get();
      if (existing.exists) {
        await doc
            .collection('history')
            .doc(DateTime.now().toIso8601String())
            .set({
          'previousData': existing.data(),
          'createdAt': FieldValue.serverTimestamp(),
          'reason': 'atlas_profile_update',
        });
      }
      await doc.set({
        ...profile.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<AtlasSummary> _fetchScopedSummary(String field, String value) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return _emptySummary;
      final snapshot = await firestore
          .collection(ParkPalAtlasCollections.roadProfiles)
          .where(field, isEqualTo: value)
          .limit(500)
          .get();
      final profiles = snapshot.docs
          .map((doc) => ParkPalAtlasRoadProfile.fromMap(doc.id, doc.data()))
          .toList(growable: false);
      return _summaryFromProfiles(profiles);
    } catch (_) {
      return _emptySummary;
    }
  }

  AtlasSummary _summaryFromProfiles(List<ParkPalAtlasRoadProfile> profiles) {
    final totalKnownRoads = profiles.length;
    final verifiedRoads = profiles
        .where((road) => road.status == AtlasRoadStatus.verified)
        .length;
    final conflicts =
        profiles.fold<int>(0, (total, road) => total + road.conflicts);
    final staleRecords =
        profiles.fold<int>(0, (total, road) => total + road.staleRecords);
    final activeMissions =
        profiles.fold<int>(0, (total, road) => total + road.activeMissions);
    final coveragePercent = calculateCoveragePercent(
      verifiedRoads: verifiedRoads,
      totalKnownRoads: totalKnownRoads,
    );
    final pciScore = calculatePciScore(
      coveragePercent: coveragePercent,
      conflicts: conflicts,
      staleRecords: staleRecords,
    );

    return AtlasSummary(
      totalKnownRoads: totalKnownRoads,
      verifiedRoads: verifiedRoads,
      unmappedRoads: profiles
          .where((road) => road.status == AtlasRoadStatus.unmapped)
          .length,
      conflicts: conflicts,
      staleRecords: staleRecords,
      activeMissions: activeMissions,
      coveragePercent: coveragePercent,
      pciScore: pciScore,
      lastSyncAt: profiles
          .map((road) => road.lastCouncilSyncAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            _latest,
          ),
      lastReviewAt: profiles
          .map((road) => road.lastIrisReviewAt)
          .whereType<DateTime>()
          .fold<DateTime?>(
            null,
            _latest,
          ),
    );
  }

  AtlasRoadStatus _statusFor({
    required int totalAssets,
    required int verifiedSigns,
    required int conflicts,
    required int staleRecords,
    required int councilRecords,
  }) {
    if (conflicts > 0) return AtlasRoadStatus.conflict;
    if (staleRecords > 0) return AtlasRoadStatus.needs_refresh;
    if (totalAssets == 0) return AtlasRoadStatus.unmapped;
    if (verifiedSigns > 0 && councilRecords > 0) {
      return AtlasRoadStatus.verified;
    }
    if (verifiedSigns > 0 || councilRecords > 0) {
      return AtlasRoadStatus.awaiting_verification;
    }
    return AtlasRoadStatus.partially_mapped;
  }

  static const _emptySummary = AtlasSummary(
    totalKnownRoads: 0,
    verifiedRoads: 0,
    unmappedRoads: 0,
    conflicts: 0,
    staleRecords: 0,
    activeMissions: 0,
    coveragePercent: 0,
    pciScore: 0,
  );
}

DateTime? _dateFromTimestamp(Object? value) {
  return value is Timestamp ? value.toDate() : null;
}

DateTime? _latest(DateTime? current, DateTime? candidate) {
  if (candidate == null) return current;
  if (current == null) return candidate;
  return candidate.isAfter(current) ? candidate : current;
}
