import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import '../atlas_intelligence/aie_models.dart';
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
      final profiles = await _canonicalRoadProfiles(firestore);
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
      final profiles = await _canonicalRoadProfiles(firestore);
      return profiles
          .where((profile) => {
                AtlasRoadStatus.awaiting_verification,
                AtlasRoadStatus.conflict,
                AtlasRoadStatus.needs_refresh,
                AtlasRoadStatus.unmapped,
              }.contains(profile.status))
          .take(limit)
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
      final profiles =
          (await _canonicalRoadProfiles(firestore)).where((profile) {
        return field == 'city'
            ? profile.city == value
            : profile.borough == value;
      }).toList(growable: false);
      return _summaryFromProfiles(profiles);
    } catch (_) {
      return _emptySummary;
    }
  }

  /// Customer Atlas uses an in-memory projection (Option A) generated from
  /// canonical intelligence. `parkpal_atlas_roads` remains a legacy materialised
  /// projection for existing Inspector/forecast compatibility, but is not read
  /// by customer Atlas services.
  Future<List<ParkPalAtlasRoadProfile>> _canonicalRoadProfiles(
    FirebaseFirestore firestore,
  ) async {
    final snapshot = await firestore
        .collection(AieCollections.canonicalIntelligence)
        .limit(5000)
        .get();
    final grouped = <String, _CanonicalRoadAccumulator>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final key = _canonicalRoadKey(doc.id, data);
      if (key == null) continue;
      grouped.putIfAbsent(key, () => _CanonicalRoadAccumulator(key)).add(data);
    }

    return grouped.values.map(_toRoadProfile).toList(growable: false);
  }

  String? _canonicalRoadKey(String recordId, Map<String, dynamic> data) {
    final roadId = _text(data['roadId']);
    if (roadId != null) return roadId;
    final road =
        _normaliseKeyPart(data['normalizedRoadName'] ?? data['roadName']);
    final borough =
        _normaliseKeyPart(data['normalizedBorough'] ?? data['borough']);
    final council =
        _normaliseKeyPart(data['normalizedCouncil'] ?? data['council']);
    if (road == null || borough == null || council == null) {
      // Preserve malformed records without allowing them to collapse into one
      // blank-key aggregate. The record ID is deterministic and reviewable.
      final fallback = _normaliseKeyPart(recordId);
      return fallback == null ? null : 'record|$fallback';
    }
    return '$road|$borough|$council';
  }

  ParkPalAtlasRoadProfile _toRoadProfile(_CanonicalRoadAccumulator road) {
    final coverage = calculateCoveragePercent(
      verifiedRoads: road.verifiedSigns > 0 && road.conflicts == 0 ? 1 : 0,
      totalKnownRoads: 1,
    );
    final pci = calculatePciScore(
      coveragePercent: coverage,
      conflicts: road.conflicts,
      staleRecords: road.staleRecords,
      missingGps: road.missingGps,
      lowConfidence: road.lowConfidence,
    );
    return ParkPalAtlasRoadProfile(
      roadId: road.key,
      roadName: road.roadName,
      borough: road.borough,
      council: road.council,
      city: road.city,
      country: road.country,
      totalParkingAssets: road.totalAssets,
      verifiedSigns: road.verifiedSigns,
      councilRecords: road.councilRecords,
      fieldVerifiedRecords: road.fieldVerifiedRecords,
      conflicts: road.conflicts,
      staleRecords: road.staleRecords,
      activeMissions: 0,
      coveragePercent: coverage,
      pciScore: pci,
      status: _statusFor(
        totalAssets: road.totalAssets,
        verifiedSigns: road.verifiedSigns,
        conflicts: road.conflicts,
        staleRecords: road.staleRecords,
        councilRecords: road.councilRecords,
      ),
      lastFieldVerificationAt: road.lastFieldVerificationAt,
      lastCouncilSyncAt: road.lastImportedAt,
      lastIrisReviewAt: road.lastVerifiedAt,
      updatedAt: road.updatedAt,
    );
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

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _normaliseKeyPart(Object? value) {
  final text = _text(value)?.toLowerCase();
  if (text == null) return null;
  final normalised = text
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), '-');
  return normalised.isEmpty ? null : normalised;
}

class _CanonicalRoadAccumulator {
  _CanonicalRoadAccumulator(this.key);

  final String key;
  var totalAssets = 0;
  var verifiedSigns = 0;
  var councilRecords = 0;
  var fieldVerifiedRecords = 0;
  var conflicts = 0;
  var staleRecords = 0;
  var missingGps = 0;
  var lowConfidence = 0;
  String roadName = 'Unknown road';
  String borough = 'Unknown borough';
  String council = 'Unknown council';
  String city = 'London';
  String country = 'UK';
  DateTime? lastFieldVerificationAt;
  DateTime? lastImportedAt;
  DateTime? lastVerifiedAt;
  DateTime? updatedAt;

  void add(Map<String, dynamic> data) {
    totalAssets++;
    roadName = _text(data['roadName']) ?? roadName;
    borough = _text(data['borough']) ?? borough;
    council = _text(data['council']) ?? council;
    city = _text(data['city']) ?? city;
    country = _text(data['country']) ?? country;

    final verification = _text(data['verificationState']);
    final safety = _text(data['customerSafetyState']);
    final source = _text(data['sourceName']) ?? _text(data['sourceId']);
    if (verification == AtlasVerificationState.official.name ||
        verification == AtlasVerificationState.verifiedPlus.name) {
      verifiedSigns++;
    }
    if (verification == AtlasVerificationState.fieldVerified.name ||
        verification == AtlasVerificationState.verifiedPlus.name) {
      fieldVerifiedRecords++;
    }
    if (source != null || safety == AtlasCustomerSafetyState.likely.name) {
      councilRecords++;
    }
    if (safety == AtlasCustomerSafetyState.conflicting.name ||
        verification == AtlasVerificationState.conflict.name ||
        (data['conflictIds'] is List &&
            (data['conflictIds'] as List).isNotEmpty)) {
      conflicts++;
    }
    if (safety == AtlasCustomerSafetyState.stale.name ||
        _isStale(_dateFromTimestamp(data['lastImportedAt']) ??
            _dateFromTimestamp(data['updatedAt']))) {
      staleRecords++;
    }
    if (data['latitude'] == null || data['longitude'] == null) missingGps++;
    if (((data['confidence'] as num?)?.toDouble() ?? 0) < 0.5) {
      lowConfidence++;
    }
    lastFieldVerificationAt = _latest(
      lastFieldVerificationAt,
      _dateFromTimestamp(data['lastVerifiedAt']),
    );
    lastImportedAt = _latest(
      lastImportedAt,
      _dateFromTimestamp(data['lastImportedAt']),
    );
    lastVerifiedAt = _latest(
      lastVerifiedAt,
      _dateFromTimestamp(data['lastVerifiedAt']),
    );
    updatedAt = _latest(
      updatedAt,
      _dateFromTimestamp(data['updatedAt']),
    );
  }
}

bool _isStale(DateTime? value) {
  if (value == null) return false;
  return DateTime.now().toUtc().difference(value.toUtc()).inDays > 90;
}
