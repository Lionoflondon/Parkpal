import 'package:cloud_firestore/cloud_firestore.dart';

enum IrisForecastPriority { critical, high, medium, low }

enum BoroughCoverageStatus {
  earlyMapping,
  growingCoverage,
  strongCoverage,
  nearComplete,
  fullyMapped,
}

class IrisRoadPriority {
  const IrisRoadPriority({
    required this.roadId,
    required this.roadName,
    required this.borough,
    required this.council,
    required this.priorityScore,
    required this.priority,
    required this.stars,
    required this.reasons,
    required this.recommendedMission,
    required this.currentStatus,
    required this.confidence,
    this.lastVerificationAt,
  });

  final String roadId;
  final String roadName;
  final String borough;
  final String council;
  final double priorityScore;
  final IrisForecastPriority priority;
  final String stars;
  final List<String> reasons;
  final String recommendedMission;
  final String currentStatus;
  final double confidence;
  final DateTime? lastVerificationAt;

  Map<String, Object?> toMap() {
    return {
      'roadId': roadId,
      'roadName': roadName,
      'borough': borough,
      'council': council,
      'priorityScore': priorityScore,
      'priority': priority.name,
      'stars': stars,
      'reasons': reasons,
      'recommendedMission': recommendedMission,
      'currentStatus': currentStatus,
      'confidence': confidence,
      'lastVerificationAt': _timestampOrNull(lastVerificationAt),
    };
  }
}

class BoroughCoverageScore {
  const BoroughCoverageScore({
    required this.borough,
    required this.council,
    required this.totalKnownRoads,
    required this.mappedRoads,
    required this.unmappedRoads,
    required this.conflictRoads,
    required this.staleRoads,
    required this.activeMissions,
    required this.coveragePercent,
    required this.pciScore,
    required this.expectedPciAfterActiveMissions,
    required this.status,
    required this.forecastCompletion,
  });

  final String borough;
  final String council;
  final int totalKnownRoads;
  final int mappedRoads;
  final int unmappedRoads;
  final int conflictRoads;
  final int staleRoads;
  final int activeMissions;
  final double coveragePercent;
  final double pciScore;
  final double expectedPciAfterActiveMissions;
  final BoroughCoverageStatus status;
  final DateTime? forecastCompletion;

  String get statusLabel {
    return switch (status) {
      BoroughCoverageStatus.earlyMapping => 'Early Mapping',
      BoroughCoverageStatus.growingCoverage => 'Growing Coverage',
      BoroughCoverageStatus.strongCoverage => 'Strong Coverage',
      BoroughCoverageStatus.nearComplete => 'Near Complete',
      BoroughCoverageStatus.fullyMapped => 'Fully Mapped',
    };
  }
}

class IrisCoverageForecast {
  const IrisCoverageForecast({
    required this.currentPci,
    required this.expectedPciAfterActiveMissions,
    required this.coverageTrend,
    required this.verificationTrend,
    required this.upcomingCouncilImports,
    required this.conflictTrend,
    required this.nationalEstimatedCompletion,
    required this.boroughs,
    required this.priorityRoads,
    required this.recommendations,
  });

  final double currentPci;
  final double expectedPciAfterActiveMissions;
  final String coverageTrend;
  final String verificationTrend;
  final int upcomingCouncilImports;
  final String conflictTrend;
  final DateTime? nationalEstimatedCompletion;
  final List<BoroughCoverageScore> boroughs;
  final List<IrisRoadPriority> priorityRoads;
  final List<String> recommendations;

  static const empty = IrisCoverageForecast(
    currentPci: 0,
    expectedPciAfterActiveMissions: 0,
    coverageTrend: 'No trend yet',
    verificationTrend: 'No verification trend yet',
    upcomingCouncilImports: 0,
    conflictTrend: 'No conflicts detected',
    nationalEstimatedCompletion: null,
    boroughs: [],
    priorityRoads: [],
    recommendations: [
      'Map these roads next.',
      'Verify these signs.',
      'Search demand exceeds available parking intelligence.',
    ],
  );
}

double boroughCoveragePercent({
  required int mappedRoads,
  required int totalKnownRoads,
}) {
  if (totalKnownRoads <= 0) return 0;
  return (mappedRoads / totalKnownRoads * 100).clamp(0, 100).toDouble();
}

BoroughCoverageStatus boroughCoverageStatus(double coveragePercent) {
  if (coveragePercent >= 100) return BoroughCoverageStatus.fullyMapped;
  if (coveragePercent >= 75) return BoroughCoverageStatus.nearComplete;
  if (coveragePercent >= 50) return BoroughCoverageStatus.strongCoverage;
  if (coveragePercent >= 25) return BoroughCoverageStatus.growingCoverage;
  return BoroughCoverageStatus.earlyMapping;
}

IrisForecastPriority priorityLevel(double score) {
  if (score >= 85) return IrisForecastPriority.critical;
  if (score >= 65) return IrisForecastPriority.high;
  if (score >= 40) return IrisForecastPriority.medium;
  return IrisForecastPriority.low;
}

String priorityStars(IrisForecastPriority priority) {
  return switch (priority) {
    IrisForecastPriority.critical => '★★★★★ Critical',
    IrisForecastPriority.high => '★★★★ High',
    IrisForecastPriority.medium => '★★★ Medium',
    IrisForecastPriority.low => '★ Low',
  };
}

Timestamp? _timestampOrNull(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}
