import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'iris_coverage_forecast_models.dart';
import 'parkpal_atlas_models.dart';
import 'parkpal_atlas_service.dart';

class IrisCoverageForecastCollections {
  const IrisCoverageForecastCollections._();

  static const forecasts = 'parkpal_iris_coverage_forecasts';
  static const boroughScores = 'parkpal_borough_coverage_scores';
  static const roadPriorities = 'parkpal_iris_road_priorities';
  static const pioneerMissions = ParkPalAtlasCollections.pioneerMissions;
}

class IrisCoverageForecastService {
  IrisCoverageForecastService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  Future<IrisCoverageForecast> fetchForecastDashboard({
    int roadLimit = 500,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return IrisCoverageForecast.empty;

      final roads = await firestore
          .collection(ParkPalAtlasCollections.roadProfiles)
          .limit(roadLimit)
          .get();
      final profiles = roads.docs
          .map((doc) => ParkPalAtlasRoadProfile.fromMap(doc.id, doc.data()))
          .toList(growable: false);

      if (profiles.isEmpty) return IrisCoverageForecast.empty;

      final priorities = profiles.map(_priorityForRoad).toList(growable: false)
        ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
      final boroughs = _boroughScores(profiles)
        ..sort((a, b) => a.coveragePercent.compareTo(b.coveragePercent));

      final currentPci = boroughs.isEmpty
          ? 0.0
          : boroughs.fold<double>(
                0,
                (total, score) => total + score.pciScore,
              ) /
              boroughs.length;
      final expectedPci = boroughs.isEmpty
          ? currentPci
          : boroughs.fold<double>(
                0,
                (total, score) => total + score.expectedPciAfterActiveMissions,
              ) /
              boroughs.length;
      final conflictRoads =
          profiles.where((profile) => profile.conflicts > 0).length;
      final unmappedRoads = profiles
          .where((profile) => profile.status == AtlasRoadStatus.unmapped)
          .length;
      final staleRoads =
          profiles.where((profile) => profile.staleRecords > 0).length;

      return IrisCoverageForecast(
        currentPci: currentPci,
        expectedPciAfterActiveMissions: expectedPci,
        coverageTrend: expectedPci > currentPci
            ? 'Improving with active Pioneer Missions'
            : 'Stable until more roads are verified',
        verificationTrend: staleRoads > 0
            ? 'Refresh work required on stale records'
            : 'Verification stable',
        upcomingCouncilImports: profiles
            .where((profile) => profile.lastCouncilSyncAt != null)
            .length,
        conflictTrend: conflictRoads > 0
            ? '$conflictRoads conflict road(s)'
            : 'No conflicts detected',
        nationalEstimatedCompletion:
            _estimatedCompletion(profiles.length, unmappedRoads + staleRoads),
        boroughs: boroughs,
        priorityRoads: priorities.take(20).toList(growable: false),
        recommendations: _recommendations(
          priorities: priorities,
          conflictRoads: conflictRoads,
          unmappedRoads: unmappedRoads,
          staleRoads: staleRoads,
        ),
      );
    } catch (_) {
      return IrisCoverageForecast.empty;
    }
  }

  Future<List<IrisRoadPriority>> generatePioneerMissions({
    int limit = 20,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final forecast = await fetchForecastDashboard();
      final selected =
          forecast.priorityRoads.take(limit).toList(growable: false);
      for (final priority in selected) {
        await _upsertMission(firestore, priority);
        await _upsertPriority(firestore, priority);
      }
      return selected;
    } catch (_) {
      return const [];
    }
  }

  List<BoroughCoverageScore> _boroughScores(
    List<ParkPalAtlasRoadProfile> profiles,
  ) {
    final grouped = <String, List<ParkPalAtlasRoadProfile>>{};
    for (final profile in profiles) {
      grouped.putIfAbsent(profile.borough, () => []).add(profile);
    }

    return grouped.entries.map((entry) {
      final roads = entry.value;
      final totalKnownRoads = roads.length;
      final mappedRoads = roads.where(_countsAsMapped).length;
      final conflictRoads =
          roads.where((profile) => profile.conflicts > 0).length;
      final staleRoads =
          roads.where((profile) => profile.staleRecords > 0).length;
      final activeMissions = roads.fold<int>(
          0, (total, profile) => total + profile.activeMissions);
      final coverage = boroughCoveragePercent(
        mappedRoads: mappedRoads,
        totalKnownRoads: totalKnownRoads,
      );
      final pci = _boroughPci(
        coverage: coverage,
        conflictRoads: conflictRoads,
        staleRoads: staleRoads,
        activeMissions: activeMissions,
      );

      return BoroughCoverageScore(
        borough: entry.key,
        council: roads.first.council,
        totalKnownRoads: totalKnownRoads,
        mappedRoads: mappedRoads,
        unmappedRoads: totalKnownRoads - mappedRoads,
        conflictRoads: conflictRoads,
        staleRoads: staleRoads,
        activeMissions: activeMissions,
        coveragePercent: coverage,
        pciScore: pci,
        expectedPciAfterActiveMissions:
            (pci + (activeMissions * 1.5)).clamp(0, 100).toDouble(),
        status: _boroughStatus(
          coverage: coverage,
          conflictRoads: conflictRoads,
          staleRoads: staleRoads,
          unmappedRoads: totalKnownRoads - mappedRoads,
        ),
        forecastCompletion: _estimatedCompletion(
          totalKnownRoads,
          totalKnownRoads - mappedRoads + conflictRoads + staleRoads,
        ),
      );
    }).toList(growable: false);
  }

  IrisRoadPriority _priorityForRoad(ParkPalAtlasRoadProfile profile) {
    final reasons = <String>[];
    var score = 10.0;

    if (profile.status == AtlasRoadStatus.unmapped) {
      score += 35;
      reasons.add('No verified parking data');
    }
    if (profile.conflicts > 0) {
      score += 30;
      reasons.add('Existing conflict');
    }
    if (profile.staleRecords > 0) {
      score += 20;
      reasons.add('Stale verification');
    }
    if (profile.lastCouncilSyncAt != null) {
      score += 12;
      reasons.add('Council update detected');
    }
    if (profile.coveragePercent < 50) {
      score += 12;
      reasons.add('Low road coverage');
    }
    if (profile.pciScore < 50) {
      score += 10;
      reasons.add('Low PCI');
    }
    if (_isHighValuePlace(profile.roadName)) {
      score += 15;
      reasons.add('High-value public destination');
    }

    final lastVerification = profile.lastFieldVerificationAt;
    if (lastVerification == null) {
      score += 8;
      reasons.add('No field verification date');
    } else if (DateTime.now().difference(lastVerification).inDays > 180) {
      score += 12;
      reasons.add('Time since last verification');
    }

    final priority = priorityLevel(score.clamp(0, 100).toDouble());
    return IrisRoadPriority(
      roadId: profile.roadId,
      roadName: profile.roadName,
      borough: profile.borough,
      council: profile.council,
      priorityScore: score.clamp(0, 100).toDouble(),
      priority: priority,
      stars: priorityStars(priority),
      reasons: reasons.isEmpty ? const ['Maintain watch'] : reasons,
      recommendedMission: _missionFor(profile),
      currentStatus: profile.status.name,
      confidence: profile.pciScore,
      lastVerificationAt: lastVerification,
    );
  }

  bool _countsAsMapped(ParkPalAtlasRoadProfile profile) {
    if (profile.conflicts > 0) return false;
    if (profile.staleRecords > 0) return false;
    if (profile.status == AtlasRoadStatus.unmapped) return false;
    if (profile.status == AtlasRoadStatus.conflict) return false;
    if (profile.status == AtlasRoadStatus.needs_refresh) return false;
    return profile.verifiedSigns > 0 ||
        profile.fieldVerifiedRecords > 0 ||
        profile.councilRecords > 0 ||
        profile.status == AtlasRoadStatus.verified;
  }

  BoroughCoverageStatus _boroughStatus({
    required double coverage,
    required int conflictRoads,
    required int staleRoads,
    required int unmappedRoads,
  }) {
    if (coverage >= 100 &&
        conflictRoads == 0 &&
        staleRoads == 0 &&
        unmappedRoads == 0) {
      return BoroughCoverageStatus.fullyMapped;
    }
    return boroughCoverageStatus(coverage >= 100 ? 99 : coverage);
  }

  double _boroughPci({
    required double coverage,
    required int conflictRoads,
    required int staleRoads,
    required int activeMissions,
  }) {
    final missionLift = activeMissions * 1.5;
    final penalties = conflictRoads * 6 + staleRoads * 3;
    return (coverage + missionLift - penalties).clamp(0, 100).toDouble();
  }

  String _missionFor(ParkPalAtlasRoadProfile profile) {
    if (profile.conflicts > 0) return 'Resolve conflicting restrictions';
    if (profile.staleRecords > 0) return 'Re-photograph stale signs';
    if (profile.status == AtlasRoadStatus.unmapped) {
      return 'Verify parking signs on ${profile.roadName}';
    }
    if (profile.lastCouncilSyncAt != null &&
        profile.fieldVerifiedRecords == 0) {
      return 'Confirm newly imported council restrictions';
    }
    if (_isHighValuePlace(profile.roadName)) {
      return 'Verify operating times around ${profile.roadName}';
    }
    return 'Complete road verification';
  }

  bool _isHighValuePlace(String roadName) {
    final value = roadName.toLowerCase();
    return value.contains('school') ||
        value.contains('hospital') ||
        value.contains('station') ||
        value.contains('airport') ||
        value.contains('market') ||
        value.contains('centre') ||
        value.contains('center') ||
        value.contains('high street') ||
        value.contains('oxford street');
  }

  List<String> _recommendations({
    required List<IrisRoadPriority> priorities,
    required int conflictRoads,
    required int unmappedRoads,
    required int staleRoads,
  }) {
    final recommendations = <String>[];
    if (priorities.isNotEmpty) {
      recommendations
          .add('Map these roads next: ${priorities.first.roadName}.');
    }
    if (staleRoads > 0) {
      recommendations
          .add('Verify these signs: stale sign photos need refresh.');
    }
    if (conflictRoads > 0) {
      recommendations
          .add('Council updated these restrictions or sources disagree.');
    }
    if (unmappedRoads > 0) {
      recommendations
          .add('Search demand exceeds available parking intelligence.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Maintain watch and prioritise new council imports.');
    }
    return recommendations;
  }

  DateTime? _estimatedCompletion(int totalRoads, int remainingWorkItems) {
    if (totalRoads <= 0 || remainingWorkItems <= 0) return DateTime.now();
    final weeklyCompletionRate = 25;
    final weeks = (remainingWorkItems / weeklyCompletionRate).ceil();
    return DateTime.now().add(Duration(days: weeks * 7));
  }

  Future<void> _upsertPriority(
    FirebaseFirestore firestore,
    IrisRoadPriority priority,
  ) async {
    await firestore
        .collection(IrisCoverageForecastCollections.roadPriorities)
        .doc(priority.roadId)
        .set({
      ...priority.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _upsertMission(
    FirebaseFirestore firestore,
    IrisRoadPriority priority,
  ) async {
    await firestore
        .collection(IrisCoverageForecastCollections.pioneerMissions)
        .doc('forecast_${priority.roadId}')
        .set({
      'missionId': 'forecast_${priority.roadId}',
      'roadId': priority.roadId,
      'roadName': priority.roadName,
      'borough': priority.borough,
      'missionType': priority.recommendedMission,
      'status': 'recommended',
      'priority': priority.priority.name,
      'priorityScore': priority.priorityScore,
      'assignmentFactors': [
        'distance_from_pioneer',
        'previous_contribution_quality',
        'reputation',
        'pioneer_level',
        'current_location_optional',
        'mission_difficulty',
      ],
      'futureRothRewardsConfigurable': true,
      'source': 'iris_coverage_forecast',
      'sourceAttribution': 'ParkPal Atlas + IRIS Inspector',
      'historyPreserved': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
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
