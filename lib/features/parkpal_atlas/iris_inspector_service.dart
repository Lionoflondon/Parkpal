import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import 'parkpal_atlas_models.dart';
import 'parkpal_atlas_service.dart';

class IrisInspectorService {
  IrisInspectorService({
    FirebaseFirestore? firestore,
    ParkPalAtlasService? atlasService,
  })  : _firestore = firestore,
        _atlasService =
            atlasService ?? ParkPalAtlasService(firestore: firestore);

  final FirebaseFirestore? _firestore;
  final ParkPalAtlasService _atlasService;

  Future<List<IrisInspectorFinding>> inspectRoad({
    required String roadId,
  }) async {
    final findings = <IrisInspectorFinding>[];
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return findings;

      final profile =
          await _atlasService.buildRoadProfileFromRepository(roadId: roadId);
      if (profile == null) return findings;

      findings.addAll(_findProfileIssues(profile));
      findings.addAll(await _findImportedSignIssues(firestore, profile));

      final reviewedProfile = profile.copyWith(
        activeMissions: findings.length,
        lastIrisReviewAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: _statusAfterInspection(profile, findings),
      );
      await _atlasService.saveRoadProfile(reviewedProfile);

      for (final finding in findings) {
        await _upsertFinding(firestore, finding);
        await _upsertMission(firestore, finding);
      }
    } catch (_) {
      return findings;
    }
    return findings;
  }

  Future<List<IrisInspectorFinding>> inspectAtlasBatch({int limit = 25}) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final roads = await firestore
          .collection(ParkPalCollections.roads)
          .limit(limit)
          .get();

      final findings = <IrisInspectorFinding>[];
      for (final road in roads.docs) {
        findings.addAll(await inspectRoad(roadId: road.id));
      }
      return findings;
    } catch (_) {
      return const [];
    }
  }

  List<IrisInspectorFinding> _findProfileIssues(
    ParkPalAtlasRoadProfile profile,
  ) {
    final findings = <IrisInspectorFinding>[];
    if (profile.totalParkingAssets == 0) {
      findings.add(_finding(
        profile: profile,
        key: 'unmapped-road',
        title: 'Road has no verified parking data',
        notes:
            'IRIS Inspector found no parking assets for this road. Recommend Pioneer field mapping.',
        state: IrisInspectorState.needs_review,
        priority: IrisInspectorPriority.high,
        mission: 'map_unmapped_road',
      ));
    }
    if (profile.conflicts > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'source-conflict',
        title: 'Council and field evidence conflict',
        notes:
            'Sources disagree. Do not overwrite verified evidence; route this road for admin review and fresh field photo.',
        state: IrisInspectorState.conflict,
        priority: IrisInspectorPriority.critical,
        mission: 'capture_conflict_photo',
      ));
    }
    if (profile.staleRecords > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'stale-records',
        title: 'Stale parking records need refresh',
        notes:
            'One or more records are stale. Recommend fresh sign photo and council-source review.',
        state: IrisInspectorState.stale,
        priority: IrisInspectorPriority.medium,
        mission: 'refresh_stale_signs',
      ));
    }
    if (profile.coveragePercent < 100 && profile.totalParkingAssets > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'partial-coverage',
        title: 'Road coverage is incomplete',
        notes:
            'Coverage cannot reach 100% until all known roads are mapped, verified, conflict-free, and refreshed.',
        state: IrisInspectorState.watch,
        priority: IrisInspectorPriority.low,
        mission: 'complete_road_verification',
      ));
    }
    return findings;
  }

  Future<List<IrisInspectorFinding>> _findImportedSignIssues(
    FirebaseFirestore firestore,
    ParkPalAtlasRoadProfile profile,
  ) async {
    final findings = <IrisInspectorFinding>[];
    final signs = await firestore
        .collection(ParkPalCollections.signs)
        .where('streetName', isEqualTo: profile.roadName)
        .limit(200)
        .get();

    var missingGps = 0;
    var missingPhotos = 0;
    var lowConfidence = 0;
    var importedChanges = 0;

    for (final doc in signs.docs) {
      final data = doc.data();
      if (data['latitude'] == null || data['longitude'] == null) missingGps++;
      if ((data['photoUrl'] as String?)?.isEmpty ?? true) missingPhotos++;
      if (((data['confidenceScore'] as num?)?.toDouble() ?? 0) < 0.5) {
        lowConfidence++;
      }
      if (data['source'] == 'imported_dataset' &&
          data['importReviewStatus'] == 'official_unverified_field') {
        importedChanges++;
      }
    }

    if (missingGps > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'missing-gps',
        title: 'Parking assets missing GPS',
        notes:
            '$missingGps asset(s) need measured GPS before IRIS can rank confidence safely.',
        state: IrisInspectorState.needs_review,
        priority: IrisInspectorPriority.high,
        mission: 'capture_precise_gps',
      ));
    }
    if (missingPhotos > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'missing-field-photo',
        title: 'Missing field sign photos',
        notes:
            '$missingPhotos asset(s) need Pioneer field photos before becoming field verified.',
        state: IrisInspectorState.needs_review,
        priority: IrisInspectorPriority.medium,
        mission: 'capture_sign_photo',
      ));
    }
    if (lowConfidence > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'low-confidence',
        title: 'Low-confidence parking assets',
        notes:
            '$lowConfidence asset(s) need review because confidence is below the ParkPal threshold.',
        state: IrisInspectorState.watch,
        priority: IrisInspectorPriority.medium,
        mission: 'review_low_confidence_assets',
      ));
    }
    if (importedChanges > 0) {
      findings.add(_finding(
        profile: profile,
        key: 'new-council-import',
        title: 'New council/open-data changes need field check',
        notes:
            '$importedChanges imported official record(s) exist without approved ParkPal field evidence.',
        state: IrisInspectorState.needs_review,
        priority: IrisInspectorPriority.high,
        mission: 'verify_new_council_change',
      ));
    }
    return findings;
  }

  IrisInspectorFinding _finding({
    required ParkPalAtlasRoadProfile profile,
    required String key,
    required String title,
    required String notes,
    required IrisInspectorState state,
    required IrisInspectorPriority priority,
    required String mission,
  }) {
    final id = '${profile.roadId}_$key';
    return IrisInspectorFinding(
      id: id,
      roadId: profile.roadId,
      title: title,
      notes: notes,
      state: state,
      priority: priority,
      recommendedMissionType: mission,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  AtlasRoadStatus _statusAfterInspection(
    ParkPalAtlasRoadProfile profile,
    List<IrisInspectorFinding> findings,
  ) {
    if (findings
        .any((finding) => finding.state == IrisInspectorState.conflict)) {
      return AtlasRoadStatus.conflict;
    }
    if (findings.any((finding) => finding.state == IrisInspectorState.stale)) {
      return AtlasRoadStatus.needs_refresh;
    }
    if (findings.any(
      (finding) => finding.state == IrisInspectorState.needs_review,
    )) {
      return AtlasRoadStatus.awaiting_verification;
    }
    return profile.status;
  }

  Future<void> _upsertFinding(
    FirebaseFirestore firestore,
    IrisInspectorFinding finding,
  ) async {
    await firestore
        .collection(ParkPalAtlasCollections.inspectorFindings)
        .doc(finding.id)
        .set({
      ...finding.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _upsertMission(
    FirebaseFirestore firestore,
    IrisInspectorFinding finding,
  ) async {
    await firestore
        .collection(ParkPalAtlasCollections.pioneerMissions)
        .doc(finding.id)
        .set({
      'missionId': finding.id,
      'roadId': finding.roadId,
      'missionType': finding.recommendedMissionType,
      'status': 'recommended',
      'priority': finding.priority.name,
      'title': finding.title,
      'inspectorNotes': finding.notes,
      'futureRothRewardsConfigurable': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
}
