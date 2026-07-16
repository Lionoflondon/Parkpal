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

enum AieConnectorType {
  csv,
  json,
  geojson,
  xml,
  rss,
  pdf,
  socrataOpenData,
  genericHttp,
}

enum AieParserType {
  csv,
  json,
  geojson,
  xml,
  rss,
  pdf,
  text,
  socrataOpenData,
}

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

enum AtlasIntelligenceKind {
  parkingRestriction,
  permittedParkingPeriod,
  controlledZone,
  bayType,
  price,
  maximumStay,
  returnRestriction,
  permitRequirement,
  loadingRestriction,
  disabledBay,
  suspension,
  temporaryChange,
  eventRestriction,
  enforcementHours,
}

enum AtlasVerificationState {
  imported,
  official,
  fieldVerified,
  verifiedPlus,
  conflict,
  stale,
  rejected,
}

enum AtlasCustomerSafetyState {
  confirmed,
  likely,
  conflicting,
  stale,
  incompleteCoverage,
  sourceUnavailable,
  noUsableData,
}

class AieCollections {
  const AieCollections._();

  static const sources = 'parkpal_aie_sources';
  static const importLogs = 'parkpal_aie_import_logs';
  static const changeRecords = 'parkpal_aie_change_records';
  static const conflicts = 'parkpal_aie_conflicts';
  static const deadLetters = 'parkpal_aie_dead_letters';
  static const auditLogs = 'parkpal_aie_audit_logs';
  static const atlasRoads = 'parkpal_atlas_knowledge_roads';
  static const canonicalIntelligence = 'parkpal_atlas_intelligence_records';
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
    this.connectorType,
    this.parserType,
    this.validationRules = const {},
    this.authenticationRequirements = const {},
    this.expectedHeaders = const [],
    this.geometrySupport = false,
    this.connectorFingerprint,
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
      connectorType: _enumValue(
        AieConnectorType.values,
        data['connectorType'] as String?,
      ),
      parserType: _enumValue(
        AieParserType.values,
        data['parserType'] as String?,
      ),
      validationRules:
          (data['validationRules'] as Map?)?.cast<String, Object?>() ??
              const {},
      authenticationRequirements: (data['authenticationRequirements'] as Map?)
              ?.cast<String, Object?>() ??
          const {},
      expectedHeaders:
          (data['expectedHeaders'] as List?)?.cast<String>() ?? const [],
      geometrySupport: data['geometrySupport'] as bool? ?? false,
      connectorFingerprint: data['connectorFingerprint'] as String?,
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
  final AieConnectorType? connectorType;
  final AieParserType? parserType;
  final Map<String, Object?> validationRules;
  final Map<String, Object?> authenticationRequirements;
  final List<String> expectedHeaders;
  final bool geometrySupport;
  final String? connectorFingerprint;
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
      'connectorType': connectorType?.name,
      'parserType': parserType?.name,
      'validationRules': validationRules,
      'authenticationRequirements': authenticationRequirements,
      'expectedHeaders': expectedHeaders,
      'geometrySupport': geometrySupport,
      'connectorFingerprint': connectorFingerprint,
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

class AtlasCanonicalIntelligenceRecord {
  const AtlasCanonicalIntelligenceRecord({
    required this.recordId,
    required this.roadId,
    required this.roadName,
    required this.council,
    required this.kind,
    required this.restrictionType,
    required this.sourceId,
    required this.sourceUrl,
    required this.sourcePriority,
    required this.sourceFreshness,
    required this.verificationState,
    required this.confidence,
    required this.geographicCoverage,
    required this.customerSafetyState,
    required this.importBatchId,
    required this.updatedAt,
    this.borough,
    this.postcodeArea,
    this.latitude,
    this.longitude,
    this.activeDays = const [],
    this.activeHours = 'Unknown',
    this.startTime,
    this.endTime,
    this.maxStayMinutes,
    this.noReturnMinutes,
    this.parkingAllowed,
    this.loadingAllowed,
    this.permitRequired,
    this.permitZone,
    this.redRoute,
    this.busLane,
    this.schoolStreet,
    this.disabledBay,
    this.suspensionActive,
    this.temporaryRestriction,
    this.eventRestriction,
    this.price,
    this.currency,
    this.chargingPeriod,
    this.effectiveStart,
    this.effectiveEnd,
    this.lastObservedAt,
    this.lastImportedAt,
    this.lastVerifiedAt,
    this.geometry = const {},
    this.sourceRecords = const [],
    this.conflictIds = const [],
    this.warnings = const [],
    this.raw = const {},
  });

  factory AtlasCanonicalIntelligenceRecord.fromRestriction({
    required AieStructuredRestriction restriction,
    required String roadId,
    required String importBatchId,
    required DateTime importedAt,
    String? conflictId,
    int sourcePriority = 80,
  }) {
    final confidence = conflictId == null ? 1.0 : 0.45;
    final state = conflictId == null
        ? AtlasVerificationState.official
        : AtlasVerificationState.conflict;
    return AtlasCanonicalIntelligenceRecord(
      recordId: '${roadId}_${restriction.ruleId}',
      roadId: roadId,
      roadName: restriction.roadName,
      council: restriction.council,
      borough: restriction.borough,
      postcodeArea: restriction.postcodeArea,
      latitude: restriction.latitude,
      longitude: restriction.longitude,
      kind: _kindForRestriction(restriction),
      restrictionType: restriction.restrictionType,
      activeDays: restriction.activeDays,
      activeHours: restriction.activeHours,
      startTime: restriction.startTime,
      endTime: restriction.endTime,
      maxStayMinutes: restriction.maxStayMinutes,
      noReturnMinutes: _intValue(restriction.raw['noReturnMinutes']),
      parkingAllowed: restriction.parkingAllowed,
      loadingAllowed: restriction.loadingAllowed,
      permitRequired: restriction.permitRequired,
      permitZone: _stringValue(restriction.raw['permitZone']),
      redRoute: restriction.redRoute,
      busLane: restriction.busLane,
      schoolStreet: restriction.schoolStreet,
      disabledBay: _boolValue(restriction.raw['disabledBay']),
      suspensionActive: _boolValue(restriction.raw['suspensionActive']),
      temporaryRestriction: restriction.temporaryRestriction,
      eventRestriction: _boolValue(restriction.raw['eventRestriction']),
      price: _doubleValue(restriction.raw['price']),
      currency: _stringValue(restriction.raw['currency']) ?? 'GBP',
      chargingPeriod: _stringValue(restriction.raw['chargingPeriod']),
      effectiveStart: _dateValue(restriction.raw['effectiveStart']),
      effectiveEnd: _dateValue(restriction.raw['effectiveEnd']),
      sourceId: restriction.sourceId,
      sourceUrl: restriction.sourceUrl,
      sourcePriority: sourcePriority,
      sourceFreshness: 1,
      verificationState: state,
      confidence: confidence,
      geographicCoverage: _coverageForRestriction(restriction),
      customerSafetyState: conflictId == null
          ? AtlasCustomerSafetyState.confirmed
          : AtlasCustomerSafetyState.conflicting,
      lastObservedAt: _dateValue(restriction.raw['lastObservedAt']),
      lastImportedAt: importedAt,
      lastVerifiedAt: null,
      importBatchId: importBatchId,
      updatedAt: importedAt,
      geometry: {
        if (restriction.latitude != null) 'latitude': restriction.latitude,
        if (restriction.longitude != null) 'longitude': restriction.longitude,
      },
      sourceRecords: [
        {
          'sourceId': restriction.sourceId,
          'sourceUrl': restriction.sourceUrl,
          'sourceText': restriction.sourceText,
        }
      ],
      conflictIds: conflictId == null ? const [] : [conflictId],
      warnings: conflictId == null
          ? const []
          : const ['Unresolved source conflict. Customer certainty degraded.'],
      raw: restriction.raw,
    );
  }

  factory AtlasCanonicalIntelligenceRecord.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return AtlasCanonicalIntelligenceRecord(
      recordId: data['recordId'] as String? ?? id,
      roadId: data['roadId'] as String? ?? '',
      roadName: data['roadName'] as String? ?? 'Unknown road',
      council: data['council'] as String? ?? 'Unknown council',
      borough: data['borough'] as String?,
      postcodeArea: data['postcodeArea'] as String?,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      kind: _enumValue(
            AtlasIntelligenceKind.values,
            data['kind'] as String?,
          ) ??
          AtlasIntelligenceKind.parkingRestriction,
      restrictionType: data['restrictionType'] as String? ?? 'Restriction',
      activeDays: (data['activeDays'] as List?)?.cast<String>() ?? const [],
      activeHours: data['activeHours'] as String? ?? 'Unknown',
      startTime: data['startTime'] as String?,
      endTime: data['endTime'] as String?,
      maxStayMinutes: (data['maxStayMinutes'] as num?)?.toInt(),
      noReturnMinutes: (data['noReturnMinutes'] as num?)?.toInt(),
      parkingAllowed: data['parkingAllowed'] as bool?,
      loadingAllowed: data['loadingAllowed'] as bool?,
      permitRequired: data['permitRequired'] as bool?,
      permitZone: data['permitZone'] as String?,
      redRoute: data['redRoute'] as bool?,
      busLane: data['busLane'] as bool?,
      schoolStreet: data['schoolStreet'] as bool?,
      disabledBay: data['disabledBay'] as bool?,
      suspensionActive: data['suspensionActive'] as bool?,
      temporaryRestriction: data['temporaryRestriction'] as bool?,
      eventRestriction: data['eventRestriction'] as bool?,
      price: (data['price'] as num?)?.toDouble(),
      currency: data['currency'] as String?,
      chargingPeriod: data['chargingPeriod'] as String?,
      effectiveStart: _date(data['effectiveStart']),
      effectiveEnd: _date(data['effectiveEnd']),
      sourceId: data['sourceId'] as String? ?? '',
      sourceUrl: data['sourceUrl'] as String? ?? '',
      sourcePriority: (data['sourcePriority'] as num?)?.toInt() ?? 0,
      sourceFreshness: (data['sourceFreshness'] as num?)?.toDouble() ?? 0,
      verificationState: _enumValue(
            AtlasVerificationState.values,
            data['verificationState'] as String?,
          ) ??
          AtlasVerificationState.imported,
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      geographicCoverage: (data['geographicCoverage'] as num?)?.toDouble() ?? 0,
      customerSafetyState: _enumValue(
            AtlasCustomerSafetyState.values,
            data['customerSafetyState'] as String?,
          ) ??
          AtlasCustomerSafetyState.noUsableData,
      lastObservedAt: _date(data['lastObservedAt']),
      lastImportedAt: _date(data['lastImportedAt']),
      lastVerifiedAt: _date(data['lastVerifiedAt']),
      importBatchId: data['importBatchId'] as String? ?? '',
      updatedAt:
          _date(data['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      geometry: (data['geometry'] as Map?)?.cast<String, Object?>() ?? const {},
      sourceRecords: (data['sourceRecords'] as List?)
              ?.whereType<Map>()
              .map((value) => value.cast<String, Object?>())
              .toList(growable: false) ??
          const [],
      conflictIds: (data['conflictIds'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      warnings: (data['warnings'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      raw: (data['raw'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  final String recordId;
  final String roadId;
  final String roadName;
  final String council;
  final String? borough;
  final String? postcodeArea;
  final double? latitude;
  final double? longitude;
  final AtlasIntelligenceKind kind;
  final String restrictionType;
  final List<String> activeDays;
  final String activeHours;
  final String? startTime;
  final String? endTime;
  final int? maxStayMinutes;
  final int? noReturnMinutes;
  final bool? parkingAllowed;
  final bool? loadingAllowed;
  final bool? permitRequired;
  final String? permitZone;
  final bool? redRoute;
  final bool? busLane;
  final bool? schoolStreet;
  final bool? disabledBay;
  final bool? suspensionActive;
  final bool? temporaryRestriction;
  final bool? eventRestriction;
  final double? price;
  final String? currency;
  final String? chargingPeriod;
  final DateTime? effectiveStart;
  final DateTime? effectiveEnd;
  final String sourceId;
  final String sourceUrl;
  final int sourcePriority;
  final double sourceFreshness;
  final AtlasVerificationState verificationState;
  final double confidence;
  final double geographicCoverage;
  final AtlasCustomerSafetyState customerSafetyState;
  final DateTime? lastObservedAt;
  final DateTime? lastImportedAt;
  final DateTime? lastVerifiedAt;
  final String importBatchId;
  final DateTime updatedAt;
  final Map<String, Object?> geometry;
  final List<Map<String, Object?>> sourceRecords;
  final List<String> conflictIds;
  final List<String> warnings;
  final Map<String, Object?> raw;

  Map<String, Object?> toMap() {
    return {
      'recordId': recordId,
      'roadId': roadId,
      'roadName': roadName,
      'normalizedRoadName': roadName.toLowerCase().trim(),
      'council': council,
      'borough': borough,
      'postcodeArea': postcodeArea,
      'country': 'UK',
      'latitude': latitude,
      'longitude': longitude,
      'kind': kind.name,
      'restrictionType': restrictionType,
      'activeDays': activeDays,
      'activeHours': activeHours,
      'startTime': startTime,
      'endTime': endTime,
      'maxStayMinutes': maxStayMinutes,
      'noReturnMinutes': noReturnMinutes,
      'parkingAllowed': parkingAllowed,
      'loadingAllowed': loadingAllowed,
      'permitRequired': permitRequired,
      'permitZone': permitZone,
      'redRoute': redRoute,
      'busLane': busLane,
      'schoolStreet': schoolStreet,
      'disabledBay': disabledBay,
      'suspensionActive': suspensionActive,
      'temporaryRestriction': temporaryRestriction,
      'eventRestriction': eventRestriction,
      'price': price,
      'currency': currency,
      'chargingPeriod': chargingPeriod,
      'effectiveStart': _timestamp(effectiveStart),
      'effectiveEnd': _timestamp(effectiveEnd),
      'sourceId': sourceId,
      'sourceUrl': sourceUrl,
      'sourcePriority': sourcePriority,
      'sourceFreshness': sourceFreshness,
      'verificationState': verificationState.name,
      'confidence': confidence,
      'confidencePercent': (confidence * 100).round(),
      'geographicCoverage': geographicCoverage,
      'customerSafetyState': customerSafetyState.name,
      'lastObservedAt': _timestamp(lastObservedAt),
      'lastImportedAt': _timestamp(lastImportedAt),
      'lastVerifiedAt': _timestamp(lastVerifiedAt),
      'importBatchId': importBatchId,
      'updatedAt': _timestamp(updatedAt),
      'geometry': geometry,
      'sourceRecords': sourceRecords,
      'conflictIds': conflictIds,
      'warnings': warnings,
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

T? _enumValue<T extends Enum>(List<T> values, String? name) {
  if (name == null || name.isEmpty) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

AtlasIntelligenceKind _kindForRestriction(AieStructuredRestriction rule) {
  final text = '${rule.restrictionType} ${rule.sourceText}'.toLowerCase();
  if (text.contains('suspension')) return AtlasIntelligenceKind.suspension;
  if (rule.temporaryRestriction == true || text.contains('temporary')) {
    return AtlasIntelligenceKind.temporaryChange;
  }
  if (text.contains('event')) return AtlasIntelligenceKind.eventRestriction;
  if (rule.schoolStreet == true) return AtlasIntelligenceKind.controlledZone;
  if (rule.busLane == true) return AtlasIntelligenceKind.controlledZone;
  if (rule.redRoute == true) return AtlasIntelligenceKind.controlledZone;
  if (text.contains('disabled')) return AtlasIntelligenceKind.disabledBay;
  if (text.contains('loading')) return AtlasIntelligenceKind.loadingRestriction;
  if (text.contains('permit') || rule.permitRequired == true) {
    return AtlasIntelligenceKind.permitRequirement;
  }
  if (rule.maxStayMinutes != null) return AtlasIntelligenceKind.maximumStay;
  if (text.contains('bay')) return AtlasIntelligenceKind.bayType;
  if (text.contains('pay') || text.contains('charge')) {
    return AtlasIntelligenceKind.price;
  }
  return AtlasIntelligenceKind.parkingRestriction;
}

double _coverageForRestriction(AieStructuredRestriction rule) {
  if (rule.latitude != null && rule.longitude != null) return 1;
  if (rule.postcodeArea != null && rule.postcodeArea!.trim().isNotEmpty) {
    return 0.7;
  }
  if (rule.roadName.trim().isNotEmpty) return 0.55;
  return 0;
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _doubleValue(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

bool? _boolValue(Object? value) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim();
  if (text == 'true' || text == 'yes' || text == '1') return true;
  if (text == 'false' || text == 'no' || text == '0') return false;
  return null;
}

DateTime? _dateValue(Object? value) => _date(value);
