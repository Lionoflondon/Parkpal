import 'package:cloud_firestore/cloud_firestore.dart';

enum AtlasRoadStatus {
  unmapped,
  partially_mapped,
  awaiting_verification,
  verified,
  conflict,
  needs_refresh,
}

enum IrisInspectorState {
  clear,
  watch,
  needs_review,
  conflict,
  stale,
  critical
}

enum IrisInspectorPriority { low, medium, high, critical }

enum AtlasConfidenceLanguage {
  verifiedPlus,
  verified,
  official,
  community,
  limited,
  conflict,
}

class ParkPalAtlasRoadProfile {
  const ParkPalAtlasRoadProfile({
    required this.roadId,
    required this.roadName,
    required this.borough,
    required this.council,
    required this.city,
    required this.country,
    required this.totalParkingAssets,
    required this.verifiedSigns,
    required this.councilRecords,
    required this.fieldVerifiedRecords,
    required this.conflicts,
    required this.staleRecords,
    required this.activeMissions,
    required this.coveragePercent,
    required this.pciScore,
    required this.status,
    this.lastFieldVerificationAt,
    this.lastCouncilSyncAt,
    this.lastIrisReviewAt,
    this.updatedAt,
  });

  factory ParkPalAtlasRoadProfile.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return ParkPalAtlasRoadProfile(
      roadId: data['roadId'] as String? ?? id,
      roadName: data['roadName'] as String? ??
          data['streetName'] as String? ??
          'Unknown road',
      borough: data['borough'] as String? ?? 'Unknown borough',
      council: data['council'] as String? ?? 'Unknown council',
      city: data['city'] as String? ?? 'London',
      country: data['country'] as String? ?? 'UK',
      totalParkingAssets: (data['totalParkingAssets'] as num?)?.toInt() ?? 0,
      verifiedSigns: (data['verifiedSigns'] as num?)?.toInt() ?? 0,
      councilRecords: (data['councilRecords'] as num?)?.toInt() ?? 0,
      fieldVerifiedRecords:
          (data['fieldVerifiedRecords'] as num?)?.toInt() ?? 0,
      conflicts: (data['conflicts'] as num?)?.toInt() ?? 0,
      staleRecords: (data['staleRecords'] as num?)?.toInt() ?? 0,
      activeMissions: (data['activeMissions'] as num?)?.toInt() ?? 0,
      coveragePercent: (data['coveragePercent'] as num?)?.toDouble() ?? 0,
      pciScore: (data['pciScore'] as num?)?.toDouble() ?? 0,
      status: AtlasRoadStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => AtlasRoadStatus.unmapped,
      ),
      lastFieldVerificationAt:
          _dateFromTimestamp(data['lastFieldVerificationAt']),
      lastCouncilSyncAt: _dateFromTimestamp(data['lastCouncilSyncAt']),
      lastIrisReviewAt: _dateFromTimestamp(data['lastIrisReviewAt']),
      updatedAt: _dateFromTimestamp(data['updatedAt']),
    );
  }

  final String roadId;
  final String roadName;
  final String borough;
  final String council;
  final String city;
  final String country;
  final int totalParkingAssets;
  final int verifiedSigns;
  final int councilRecords;
  final int fieldVerifiedRecords;
  final int conflicts;
  final int staleRecords;
  final int activeMissions;
  final double coveragePercent;
  final double pciScore;
  final AtlasRoadStatus status;
  final DateTime? lastFieldVerificationAt;
  final DateTime? lastCouncilSyncAt;
  final DateTime? lastIrisReviewAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'roadId': roadId,
      'roadName': roadName,
      'borough': borough,
      'council': council,
      'city': city,
      'country': country,
      'totalParkingAssets': totalParkingAssets,
      'verifiedSigns': verifiedSigns,
      'councilRecords': councilRecords,
      'fieldVerifiedRecords': fieldVerifiedRecords,
      'conflicts': conflicts,
      'staleRecords': staleRecords,
      'activeMissions': activeMissions,
      'coveragePercent': coveragePercent,
      'pciScore': pciScore,
      'status': status.name,
      'lastFieldVerificationAt': _timestampOrNull(lastFieldVerificationAt),
      'lastCouncilSyncAt': _timestampOrNull(lastCouncilSyncAt),
      'lastIrisReviewAt': _timestampOrNull(lastIrisReviewAt),
      'updatedAt': _timestampOrNull(updatedAt),
    };
  }

  ParkPalAtlasRoadProfile copyWith({
    int? totalParkingAssets,
    int? verifiedSigns,
    int? councilRecords,
    int? fieldVerifiedRecords,
    int? conflicts,
    int? staleRecords,
    int? activeMissions,
    double? coveragePercent,
    double? pciScore,
    AtlasRoadStatus? status,
    DateTime? lastIrisReviewAt,
    DateTime? updatedAt,
  }) {
    return ParkPalAtlasRoadProfile(
      roadId: roadId,
      roadName: roadName,
      borough: borough,
      council: council,
      city: city,
      country: country,
      totalParkingAssets: totalParkingAssets ?? this.totalParkingAssets,
      verifiedSigns: verifiedSigns ?? this.verifiedSigns,
      councilRecords: councilRecords ?? this.councilRecords,
      fieldVerifiedRecords: fieldVerifiedRecords ?? this.fieldVerifiedRecords,
      conflicts: conflicts ?? this.conflicts,
      staleRecords: staleRecords ?? this.staleRecords,
      activeMissions: activeMissions ?? this.activeMissions,
      coveragePercent: coveragePercent ?? this.coveragePercent,
      pciScore: pciScore ?? this.pciScore,
      status: status ?? this.status,
      lastFieldVerificationAt: lastFieldVerificationAt,
      lastCouncilSyncAt: lastCouncilSyncAt,
      lastIrisReviewAt: lastIrisReviewAt ?? this.lastIrisReviewAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AtlasSummary {
  const AtlasSummary({
    required this.totalKnownRoads,
    required this.verifiedRoads,
    required this.unmappedRoads,
    required this.conflicts,
    required this.staleRecords,
    required this.activeMissions,
    required this.coveragePercent,
    required this.pciScore,
    this.lastSyncAt,
    this.lastReviewAt,
  });

  final int totalKnownRoads;
  final int verifiedRoads;
  final int unmappedRoads;
  final int conflicts;
  final int staleRecords;
  final int activeMissions;
  final double coveragePercent;
  final double pciScore;
  final DateTime? lastSyncAt;
  final DateTime? lastReviewAt;
}

class IrisInspectorFinding {
  const IrisInspectorFinding({
    required this.id,
    required this.roadId,
    required this.title,
    required this.notes,
    required this.state,
    required this.priority,
    required this.recommendedMissionType,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roadId;
  final String title;
  final String notes;
  final IrisInspectorState state;
  final IrisInspectorPriority priority;
  final String recommendedMissionType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'roadId': roadId,
      'title': title,
      'inspectorNotes': notes,
      'state': state.name,
      'priority': priority.name,
      'recommendedMissionType': recommendedMissionType,
      'createdAt': _timestampOrNull(createdAt),
      'updatedAt': _timestampOrNull(updatedAt),
    };
  }
}

double calculateCoveragePercent({
  required int verifiedRoads,
  required int totalKnownRoads,
}) {
  if (totalKnownRoads <= 0) return 0;
  return (verifiedRoads / totalKnownRoads * 100).clamp(0, 100).toDouble();
}

double calculatePciScore({
  required double coveragePercent,
  int conflicts = 0,
  int staleRecords = 0,
  int missingGps = 0,
  int missingFieldPhotos = 0,
  int councilSignMismatches = 0,
  int lowConfidence = 0,
}) {
  final penalty = conflicts * 8 +
      staleRecords * 4 +
      missingGps * 3 +
      missingFieldPhotos * 3 +
      councilSignMismatches * 8 +
      lowConfidence * 2;
  return (coveragePercent - penalty).clamp(0, 100).toDouble();
}

AtlasConfidenceLanguage confidenceLanguageFromState(String? state) {
  return switch (state) {
    'verified_plus' => AtlasConfidenceLanguage.verifiedPlus,
    'field_verified' => AtlasConfidenceLanguage.verified,
    'official_unverified_field' => AtlasConfidenceLanguage.official,
    'conflict' => AtlasConfidenceLanguage.conflict,
    'community' => AtlasConfidenceLanguage.community,
    _ => AtlasConfidenceLanguage.limited,
  };
}

String confidenceLanguageLabel(AtlasConfidenceLanguage language) {
  return switch (language) {
    AtlasConfidenceLanguage.verifiedPlus => 'Verified+',
    AtlasConfidenceLanguage.verified => 'Verified',
    AtlasConfidenceLanguage.official => 'Official',
    AtlasConfidenceLanguage.community => 'Community',
    AtlasConfidenceLanguage.limited => 'Limited',
    AtlasConfidenceLanguage.conflict => 'Conflict',
  };
}

DateTime? _dateFromTimestamp(Object? value) {
  return value is Timestamp ? value.toDate() : null;
}

Timestamp? _timestampOrNull(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}
