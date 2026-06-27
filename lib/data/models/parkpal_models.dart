import 'model_helpers.dart';

enum CapturedByRole { pioneer, rider, admin, public_user }
enum VerificationStatus { pending, verified, disputed, rejected }
enum SignSource { user_photo, council_data, admin_entry, imported_dataset }
enum ParkingRisk { low, medium, high, unknown }
enum LoadingRisk { low, medium, high, unknown }
enum ZoneType { CPZ, permit_zone, red_route, school_street, loading_zone, bus_lane, other }
enum ReportType { sign_changed, new_sign, removed_sign, temporary_suspension, wrong_interpretation, enforcement_seen, other }
enum ReportStatus { open, reviewing, resolved, rejected }
enum ContributorRole { pioneer, rider, admin, public_user }
enum QueryMode { parking, delivery, loading, fleet }

class ParkPalSign {
  const ParkPalSign({
    required this.signId,
    required this.photoUrl,
    required this.thumbnailUrl,
    required this.capturedByUserId,
    required this.capturedByRole,
    required this.capturedAt,
    required this.geoPoint,
    required this.latitude,
    required this.longitude,
    required this.streetName,
    required this.borough,
    required this.council,
    required this.postcode,
    this.country = 'UK',
    this.rawText,
    this.interpretedText,
    this.restrictionType,
    this.restrictionSummary,
    this.activeDays = const [],
    this.activeHours,
    this.maxStayMinutes,
    this.noReturnMinutes,
    this.loadingAllowed,
    this.parkingAllowed,
    this.permitRequired,
    this.permitZone,
    this.cameraEnforced,
    this.redRoute,
    this.busLane,
    this.schoolStreet,
    this.temporaryRestriction,
    this.suspensionActive,
    this.confidenceScore,
    this.verificationStatus = VerificationStatus.pending,
    this.verifiedBy,
    this.verifiedAt,
    this.source = SignSource.user_photo,
    this.createdAt,
    this.updatedAt,
  });

  final String signId;
  final String photoUrl;
  final String thumbnailUrl;
  final String capturedByUserId;
  final CapturedByRole capturedByRole;
  final Object? capturedAt;
  final ParkPalGeoPoint geoPoint;
  final double latitude;
  final double longitude;
  final String streetName;
  final String borough;
  final String council;
  final String postcode;
  final String country;
  final String? rawText;
  final String? interpretedText;
  final String? restrictionType;
  final String? restrictionSummary;
  final List<String> activeDays;
  final String? activeHours;
  final int? maxStayMinutes;
  final int? noReturnMinutes;
  final bool? loadingAllowed;
  final bool? parkingAllowed;
  final bool? permitRequired;
  final String? permitZone;
  final bool? cameraEnforced;
  final bool? redRoute;
  final bool? busLane;
  final bool? schoolStreet;
  final bool? temporaryRestriction;
  final bool? suspensionActive;
  final double? confidenceScore;
  final VerificationStatus verificationStatus;
  final String? verifiedBy;
  final Object? verifiedAt;
  final SignSource source;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'signId': signId,
        'photoUrl': photoUrl,
        'thumbnailUrl': thumbnailUrl,
        'capturedByUserId': capturedByUserId,
        'capturedByRole': capturedByRole.name,
        'capturedAt': capturedAt,
        'geoPoint': geoPoint.toJson(),
        'latitude': latitude,
        'longitude': longitude,
        'streetName': streetName,
        'borough': borough,
        'council': council,
        'postcode': postcode,
        'country': country,
        'rawText': rawText,
        'interpretedText': interpretedText,
        'restrictionType': restrictionType,
        'restrictionSummary': restrictionSummary,
        'activeDays': activeDays,
        'activeHours': activeHours,
        'maxStayMinutes': maxStayMinutes,
        'noReturnMinutes': noReturnMinutes,
        'loadingAllowed': loadingAllowed,
        'parkingAllowed': parkingAllowed,
        'permitRequired': permitRequired,
        'permitZone': permitZone,
        'cameraEnforced': cameraEnforced,
        'redRoute': redRoute,
        'busLane': busLane,
        'schoolStreet': schoolStreet,
        'temporaryRestriction': temporaryRestriction,
        'suspensionActive': suspensionActive,
        'confidenceScore': confidenceScore,
        'verificationStatus': verificationStatus.name,
        'verifiedBy': verifiedBy,
        'verifiedAt': verifiedAt,
        'source': source.name,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}

class ParkPalRoad {
  const ParkPalRoad({
    required this.roadId,
    required this.streetName,
    required this.normalizedStreetName,
    required this.borough,
    required this.council,
    required this.postcodeArea,
    this.country = 'UK',
    this.geoBounds,
    this.centrePoint,
    this.knownRestrictions = const [],
    this.parkingRisk = ParkingRisk.unknown,
    this.loadingRisk = LoadingRisk.unknown,
    this.defaultSummary,
    this.nearestLegalAlternative,
    this.signCount = 0,
    this.verifiedSignCount = 0,
    this.lastVerifiedAt,
    this.confidenceScore,
    this.createdAt,
    this.updatedAt,
  });

  final String roadId;
  final String streetName;
  final String normalizedStreetName;
  final String borough;
  final String council;
  final String postcodeArea;
  final String country;
  final ParkPalGeoBounds? geoBounds;
  final ParkPalGeoPoint? centrePoint;
  final List<String> knownRestrictions;
  final ParkingRisk parkingRisk;
  final LoadingRisk loadingRisk;
  final String? defaultSummary;
  final String? nearestLegalAlternative;
  final int signCount;
  final int verifiedSignCount;
  final Object? lastVerifiedAt;
  final double? confidenceScore;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'roadId': roadId,
        'streetName': streetName,
        'normalizedStreetName': normalizedStreetName,
        'borough': borough,
        'council': council,
        'postcodeArea': postcodeArea,
        'country': country,
        'geoBounds': geoBounds?.toJson(),
        'centrePoint': centrePoint?.toJson(),
        'knownRestrictions': knownRestrictions,
        'parkingRisk': parkingRisk.name,
        'loadingRisk': loadingRisk.name,
        'defaultSummary': defaultSummary,
        'nearestLegalAlternative': nearestLegalAlternative,
        'signCount': signCount,
        'verifiedSignCount': verifiedSignCount,
        'lastVerifiedAt': lastVerifiedAt,
        'confidenceScore': confidenceScore,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}

class ParkPalZone {
  const ParkPalZone({
    required this.zoneId,
    required this.zoneName,
    required this.zoneType,
    required this.borough,
    required this.council,
    this.geoPolygon = const [],
    this.activeDays = const [],
    this.activeHours,
    this.rulesSummary,
    this.permitRequired,
    this.loadingAllowed,
    this.maxStayMinutes,
    this.cameraEnforced,
    this.source,
    this.confidenceScore,
    this.createdAt,
    this.updatedAt,
  });

  final String zoneId;
  final String zoneName;
  final ZoneType zoneType;
  final String borough;
  final String council;
  final List<ParkPalGeoPoint> geoPolygon;
  final List<String> activeDays;
  final String? activeHours;
  final String? rulesSummary;
  final bool? permitRequired;
  final bool? loadingAllowed;
  final int? maxStayMinutes;
  final bool? cameraEnforced;
  final String? source;
  final double? confidenceScore;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'zoneId': zoneId,
        'zoneName': zoneName,
        'zoneType': zoneType.name,
        'borough': borough,
        'council': council,
        'geoPolygon': geoPolygon.map((point) => point.toJson()).toList(),
        'activeDays': activeDays,
        'activeHours': activeHours,
        'rulesSummary': rulesSummary,
        'permitRequired': permitRequired,
        'loadingAllowed': loadingAllowed,
        'maxStayMinutes': maxStayMinutes,
        'cameraEnforced': cameraEnforced,
        'source': source,
        'confidenceScore': confidenceScore,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}

class ParkPalReport {
  const ParkPalReport({
    required this.reportId,
    required this.userId,
    required this.reportType,
    required this.description,
    this.relatedSignId,
    this.relatedRoadId,
    this.photoUrl,
    this.geoPoint,
    this.streetName,
    this.borough,
    this.council,
    this.status = ReportStatus.open,
    this.adminNotes,
    this.createdAt,
    this.updatedAt,
  });

  final String reportId;
  final String userId;
  final String? relatedSignId;
  final String? relatedRoadId;
  final ReportType reportType;
  final String description;
  final String? photoUrl;
  final ParkPalGeoPoint? geoPoint;
  final String? streetName;
  final String? borough;
  final String? council;
  final ReportStatus status;
  final String? adminNotes;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'reportId': reportId,
        'userId': userId,
        'relatedSignId': relatedSignId,
        'relatedRoadId': relatedRoadId,
        'reportType': reportType.name,
        'description': description,
        'photoUrl': photoUrl,
        'geoPoint': geoPoint?.toJson(),
        'streetName': streetName,
        'borough': borough,
        'council': council,
        'status': status.name,
        'adminNotes': adminNotes,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}

class ParkPalContributor {
  const ParkPalContributor({
    required this.userId,
    required this.displayName,
    required this.role,
    this.pioneerNumber,
    this.contributionCount = 0,
    this.verifiedContributionCount = 0,
    this.rejectedContributionCount = 0,
    this.mappingPoints = 0,
    this.badges = const [],
    this.assignedBoroughs = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final String displayName;
  final ContributorRole role;
  final String? pioneerNumber;
  final int contributionCount;
  final int verifiedContributionCount;
  final int rejectedContributionCount;
  final int mappingPoints;
  final List<String> badges;
  final List<String> assignedBoroughs;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'userId': userId,
        'displayName': displayName,
        'role': role.name,
        'pioneerNumber': pioneerNumber,
        'contributionCount': contributionCount,
        'verifiedContributionCount': verifiedContributionCount,
        'rejectedContributionCount': rejectedContributionCount,
        'mappingPoints': mappingPoints,
        'badges': badges,
        'assignedBoroughs': assignedBoroughs,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}

class ParkPalQuery {
  const ParkPalQuery({
    required this.queryId,
    required this.userId,
    required this.queriedAt,
    required this.geoPoint,
    required this.latitude,
    required this.longitude,
    required this.mode,
    this.streetName,
    this.borough,
    this.council,
    this.resultRisk,
    this.resultSummary,
    this.matchedRoadId,
    this.matchedZoneIds = const [],
    this.matchedSignIds = const [],
    this.createdAt,
  });

  final String queryId;
  final String userId;
  final Object? queriedAt;
  final ParkPalGeoPoint geoPoint;
  final double latitude;
  final double longitude;
  final String? streetName;
  final String? borough;
  final String? council;
  final QueryMode mode;
  final String? resultRisk;
  final String? resultSummary;
  final String? matchedRoadId;
  final List<String> matchedZoneIds;
  final List<String> matchedSignIds;
  final Object? createdAt;

  JsonMap toJson() => compact({
        'queryId': queryId,
        'userId': userId,
        'queriedAt': queriedAt,
        'geoPoint': geoPoint.toJson(),
        'latitude': latitude,
        'longitude': longitude,
        'streetName': streetName,
        'borough': borough,
        'council': council,
        'mode': mode.name,
        'resultRisk': resultRisk,
        'resultSummary': resultSummary,
        'matchedRoadId': matchedRoadId,
        'matchedZoneIds': matchedZoneIds,
        'matchedSignIds': matchedSignIds,
        'createdAt': createdAt,
      });
}

class ParkPalCouncil {
  const ParkPalCouncil({
    required this.councilId,
    required this.councilName,
    required this.country,
    required this.region,
    this.website,
    this.parkingRulesUrl,
    this.enforcementUrl,
    this.dataSourceUrls = const [],
    this.lastImportedAt,
    this.confidenceScore,
    this.createdAt,
    this.updatedAt,
  });

  final String councilId;
  final String councilName;
  final String country;
  final String region;
  final String? website;
  final String? parkingRulesUrl;
  final String? enforcementUrl;
  final List<String> dataSourceUrls;
  final Object? lastImportedAt;
  final double? confidenceScore;
  final Object? createdAt;
  final Object? updatedAt;

  JsonMap toJson() => compact({
        'councilId': councilId,
        'councilName': councilName,
        'country': country,
        'region': region,
        'website': website,
        'parkingRulesUrl': parkingRulesUrl,
        'enforcementUrl': enforcementUrl,
        'dataSourceUrls': dataSourceUrls,
        'lastImportedAt': lastImportedAt,
        'confidenceScore': confidenceScore,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      });
}
