import 'package:cloud_firestore/cloud_firestore.dart';

enum AieSourceType {
  councilParkingPage,
  trafficRegulationOrder,
  controlledParkingZone,
  temporaryTrafficOrder,
  parkingSuspension,
  roadClosure,
  consultation,
  permitChange,
  bayChange,
  loadingRestriction,
  busLaneChange,
  schoolStreet,
  cleanAirZone,
  lowTrafficNeighbourhood,
  openDataApi,
}

enum AieDocumentType { html, pdf, docx, csv, json, xml, rss, geojson }

enum AieImportStatus { idle, queued, importing, imported, unchanged, failed }

enum AieChangeType {
  newRestriction,
  removedRestriction,
  changedHours,
  newParkingBay,
  removedBay,
  permitChange,
  temporarySuspension,
  roadClosure,
  cpzAmendment,
  unchanged,
}

enum AieConflictState { pending, needsReview, resolved, rejected }

enum AieConfidence { official, verifiedPlus, fieldVerified, limited, conflict }

class AieCollections {
  const AieCollections._();

  static const sources = 'parkpal_aie_sources';
  static const importLogs = 'parkpal_aie_import_logs';
  static const changeRecords = 'parkpal_aie_change_records';
  static const conflicts = 'parkpal_aie_conflicts';
  static const deadLetters = 'parkpal_aie_dead_letters';
  static const auditLogs = 'parkpal_aie_audit_logs';
  static const atlasRoads = 'parkpal_atlas_knowledge_roads';
  static const apiRateLimits = 'parkpal_aie_api_rate_limits';
}

class AieSource {
  const AieSource({
    required this.sourceId,
    required this.sourceUrl,
    required this.council,
    required this.sourceType,
    required this.documentType,
    required this.importStatus,
    required this.version,
    required this.confidence,
    required this.enabled,
    this.sourceName,
    this.lastSuccessfulImport,
    this.lastFailedImport,
    this.nextScheduledCheck,
    this.checksum,
  });

  factory AieSource.fromMap(String id, Map<String, dynamic> data) {
    return AieSource(
      sourceId: data['sourceId'] as String? ?? id,
      sourceName: data['sourceName'] as String?,
      sourceUrl: data['sourceUrl'] as String? ?? '',
      council: data['council'] as String? ?? 'Unknown council',
      sourceType: AieSourceType.values.firstWhere(
        (value) => value.name == data['sourceType'],
        orElse: () => AieSourceType.councilParkingPage,
      ),
      documentType: AieDocumentType.values.firstWhere(
        (value) => value.name == data['documentType'],
        orElse: () => AieDocumentType.html,
      ),
      lastSuccessfulImport: _date(data['lastSuccessfulImport']),
      lastFailedImport: _date(data['lastFailedImport']),
      nextScheduledCheck: _date(data['nextScheduledCheck']),
      importStatus: AieImportStatus.values.firstWhere(
        (value) => value.name == data['importStatus'],
        orElse: () => AieImportStatus.idle,
      ),
      checksum: data['checksum'] as String?,
      version: (data['version'] as num?)?.toInt() ?? 0,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      enabled: data['enabled'] as bool? ?? true,
    );
  }

  final String sourceId;
  final String? sourceName;
  final String sourceUrl;
  final String council;
  final AieSourceType sourceType;
  final AieDocumentType documentType;
  final DateTime? lastSuccessfulImport;
  final DateTime? lastFailedImport;
  final DateTime? nextScheduledCheck;
  final AieImportStatus importStatus;
  final String? checksum;
  final int version;
  final double confidence;
  final bool enabled;

  Map<String, Object?> toMap() {
    return {
      'sourceId': sourceId,
      'sourceName': sourceName,
      'sourceUrl': sourceUrl,
      'council': council,
      'sourceType': sourceType.name,
      'documentType': documentType.name,
      'lastSuccessfulImport': _timestamp(lastSuccessfulImport),
      'lastFailedImport': _timestamp(lastFailedImport),
      'nextScheduledCheck': _timestamp(nextScheduledCheck),
      'importStatus': importStatus.name,
      'checksum': checksum,
      'version': version,
      'confidence': confidence,
      'enabled': enabled,
    };
  }
}

class AieStructuredRestriction {
  const AieStructuredRestriction({
    required this.ruleId,
    required this.roadName,
    required this.council,
    required this.restrictionType,
    required this.activeDays,
    required this.activeHours,
    required this.sourceId,
    required this.sourceUrl,
    required this.sourceText,
    this.borough,
    this.postcodeArea,
    this.latitude,
    this.longitude,
    this.startTime,
    this.endTime,
    this.maxStayMinutes,
    this.parkingAllowed,
    this.loadingAllowed,
    this.permitRequired,
    this.redRoute,
    this.busLane,
    this.schoolStreet,
    this.temporaryRestriction,
    this.confidence = AieConfidence.official,
    this.raw = const {},
  });

  factory AieStructuredRestriction.fromMap(Map<String, dynamic> data) {
    return AieStructuredRestriction(
      ruleId: data['ruleId'] as String? ?? '',
      roadName: data['roadName'] as String? ?? 'Unknown road',
      council: data['council'] as String? ?? 'Unknown council',
      borough: data['borough'] as String?,
      postcodeArea: data['postcodeArea'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      restrictionType: data['restrictionType'] as String? ?? 'Restriction',
      activeDays: (data['activeDays'] as List?)?.cast<String>() ?? const [],
      activeHours: data['activeHours'] as String? ?? 'Unknown',
      startTime: data['startTime'] as String?,
      endTime: data['endTime'] as String?,
      maxStayMinutes: (data['maxStayMinutes'] as num?)?.toInt(),
      parkingAllowed: data['parkingAllowed'] as bool?,
      loadingAllowed: data['loadingAllowed'] as bool?,
      permitRequired: data['permitRequired'] as bool?,
      redRoute: data['redRoute'] as bool?,
      busLane: data['busLane'] as bool?,
      schoolStreet: data['schoolStreet'] as bool?,
      temporaryRestriction: data['temporaryRestriction'] as bool?,
      sourceId: data['sourceId'] as String? ?? '',
      sourceUrl: data['sourceUrl'] as String? ?? '',
      sourceText: data['sourceText'] as String? ?? '',
      confidence: AieConfidence.values.firstWhere(
        (value) => value.name == data['confidence'],
        orElse: () => AieConfidence.official,
      ),
      raw: (data['raw'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  final String ruleId;
  final String roadName;
  final String council;
  final String? borough;
  final String? postcodeArea;
  final double? latitude;
  final double? longitude;
  final String restrictionType;
  final List<String> activeDays;
  final String activeHours;
  final String? startTime;
  final String? endTime;
  final int? maxStayMinutes;
  final bool? parkingAllowed;
  final bool? loadingAllowed;
  final bool? permitRequired;
  final bool? redRoute;
  final bool? busLane;
  final bool? schoolStreet;
  final bool? temporaryRestriction;
  final String sourceId;
  final String sourceUrl;
  final String sourceText;
  final AieConfidence confidence;
  final Map<String, Object?> raw;

  Map<String, Object?> toMap() {
    return {
      'ruleId': ruleId,
      'roadName': roadName,
      'council': council,
      'borough': borough,
      'postcodeArea': postcodeArea,
      'latitude': latitude,
      'longitude': longitude,
      'restrictionType': restrictionType,
      'activeDays': activeDays,
      'activeHours': activeHours,
      'startTime': startTime,
      'endTime': endTime,
      'maxStayMinutes': maxStayMinutes,
      'parkingAllowed': parkingAllowed,
      'loadingAllowed': loadingAllowed,
      'permitRequired': permitRequired,
      'redRoute': redRoute,
      'busLane': busLane,
      'schoolStreet': schoolStreet,
      'temporaryRestriction': temporaryRestriction,
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
      'sourceText': sourceText,
      'confidence': confidence.name,
      'raw': raw,
    };
  }
}

class AieImportResult {
  const AieImportResult({
    required this.batchId,
    required this.imported,
    required this.changed,
    required this.skipped,
    required this.failed,
    required this.conflicts,
    required this.missionsCreated,
    required this.status,
    this.messages = const [],
  });

  final String batchId;
  final int imported;
  final int changed;
  final int skipped;
  final int failed;
  final int conflicts;
  final int missionsCreated;
  final AieImportStatus status;
  final List<String> messages;
}

class AieDashboardSummary {
  const AieDashboardSummary({
    required this.connectedCouncils,
    required this.importQueue,
    required this.failedImports,
    required this.importLogs,
    required this.pendingConflicts,
    required this.pendingVerification,
    required this.staleRoads,
    required this.missionQueue,
    required this.councilStatus,
    required this.recentLogs,
    required this.recentChanges,
  });

  final int connectedCouncils;
  final int importQueue;
  final int failedImports;
  final int importLogs;
  final int pendingConflicts;
  final int pendingVerification;
  final int staleRoads;
  final int missionQueue;
  final String councilStatus;
  final List<Map<String, Object?>> recentLogs;
  final List<Map<String, Object?>> recentChanges;

  static const empty = AieDashboardSummary(
    connectedCouncils: 0,
    importQueue: 0,
    failedImports: 0,
    importLogs: 0,
    pendingConflicts: 0,
    pendingVerification: 0,
    staleRoads: 0,
    missionQueue: 0,
    councilStatus: 'No sources connected',
    recentLogs: [],
    recentChanges: [],
  );
}

String aieSourceTypeLabel(AieSourceType type) {
  return switch (type) {
    AieSourceType.councilParkingPage => 'Council parking page',
    AieSourceType.trafficRegulationOrder => 'Traffic Regulation Order',
    AieSourceType.controlledParkingZone => 'Controlled Parking Zone',
    AieSourceType.temporaryTrafficOrder => 'Temporary Traffic Order',
    AieSourceType.parkingSuspension => 'Parking suspension',
    AieSourceType.roadClosure => 'Road closure',
    AieSourceType.consultation => 'Parking consultation',
    AieSourceType.permitChange => 'Permit change',
    AieSourceType.bayChange => 'Bay addition/removal',
    AieSourceType.loadingRestriction => 'Loading restriction',
    AieSourceType.busLaneChange => 'Bus lane change',
    AieSourceType.schoolStreet => 'School Street',
    AieSourceType.cleanAirZone => 'Clean Air Zone',
    AieSourceType.lowTrafficNeighbourhood => 'Low Traffic Neighbourhood',
    AieSourceType.openDataApi => 'Official Open Data API',
  };
}

DateTime? _date(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

Timestamp? _timestamp(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}
