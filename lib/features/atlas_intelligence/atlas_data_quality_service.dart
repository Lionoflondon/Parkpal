import 'aie_models.dart';
import 'aie_source_connector_engine.dart';

enum AtlasOperationalHealth { healthy, warning, offline, stale, conflict }

enum AtlasDataQualitySeverity { info, warning, critical }

enum AtlasDataQualityIssueType {
  duplicateSource,
  duplicateGeometry,
  conflictingRestriction,
  expiredRestriction,
  missingMetadata,
  invalidGeometry,
  parserMismatch,
  staleImport,
}

class AtlasDataQualityIssue {
  const AtlasDataQualityIssue({
    required this.type,
    required this.severity,
    required this.title,
    required this.detail,
    required this.suggestedAction,
    this.sourceId,
    this.recordId,
    this.roadName,
  });

  final AtlasDataQualityIssueType type;
  final AtlasDataQualitySeverity severity;
  final String title;
  final String detail;
  final String suggestedAction;
  final String? sourceId;
  final String? recordId;
  final String? roadName;
}

class AtlasDataQualityReport {
  const AtlasDataQualityReport({
    required this.health,
    required this.healthScore,
    required this.issues,
  });

  final AtlasOperationalHealth health;
  final double healthScore;
  final List<AtlasDataQualityIssue> issues;

  int get criticalCount => issues
      .where((issue) => issue.severity == AtlasDataQualitySeverity.critical)
      .length;

  int get warningCount => issues
      .where((issue) => issue.severity == AtlasDataQualitySeverity.warning)
      .length;
}

class AtlasDataQualityService {
  const AtlasDataQualityService();

  AtlasDataQualityReport assessSources(
    List<AieSource> sources, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final issues = <AtlasDataQualityIssue>[
      ..._duplicateSourceIssues(sources),
      ...sources.expand((source) => _sourceIssues(source, referenceTime)),
    ];
    return _report(issues);
  }

  AtlasDataQualityReport assessRestrictions(
    List<AieStructuredRestriction> restrictions, {
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final issues = <AtlasDataQualityIssue>[
      ...restrictions.expand((record) => _restrictionIssues(
            record,
            referenceTime,
          )),
      ..._duplicateGeometryIssues(restrictions),
      ..._conflictingRestrictionIssues(restrictions),
    ];
    return _report(issues);
  }

  AtlasDataQualityReport assessImport({
    required AieSource source,
    required AieConnectorDecision connector,
    required List<AieStructuredRestriction> restrictions,
    DateTime? now,
  }) {
    final referenceTime = now ?? DateTime.now();
    final issues = <AtlasDataQualityIssue>[
      ..._sourceIssues(source, referenceTime),
      if (!connector.valid)
        AtlasDataQualityIssue(
          type: AtlasDataQualityIssueType.parserMismatch,
          severity: AtlasDataQualitySeverity.critical,
          title: 'Parser mismatch',
          detail:
              'Connector: ${connector.connectorType.name}. Expected format: ${connector.expectedFormat}. Detected format: ${connector.detectedFormat}. Reason: ${connector.reasonForFailure ?? 'Validation failed'}.',
          suggestedAction: connector.suggestedAction ??
              'Update the connector/parser configuration before retrying.',
          sourceId: source.sourceId,
        ),
      ...assessRestrictions(restrictions, now: referenceTime).issues,
    ];
    return _report(issues);
  }

  AtlasOperationalHealth sourceHealth(
    AieSource source, {
    DateTime? now,
  }) {
    return assessSources([source], now: now).health;
  }

  List<AtlasDataQualityIssue> _sourceIssues(
    AieSource source,
    DateTime now,
  ) {
    final issues = <AtlasDataQualityIssue>[];
    if (!source.enabled) return issues;

    if (source.sourceUrl.trim().isEmpty) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.missingMetadata,
        severity: AtlasDataQualitySeverity.critical,
        title: 'Missing source URL',
        detail: '${source.sourceName ?? source.sourceId} has no source URL.',
        suggestedAction: 'Add the official source URL before importing.',
        sourceId: source.sourceId,
      ));
    }
    if (source.council.trim().isEmpty || source.council == 'Unknown council') {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.missingMetadata,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Missing council',
        detail:
            '${source.sourceName ?? source.sourceId} is not tied to a known council.',
        suggestedAction: 'Set the source council so Atlas can attribute rules.',
        sourceId: source.sourceId,
      ));
    }
    if (source.connectorType == null || source.parserType == null) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.parserMismatch,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Connector is inferred',
        detail:
            '${source.sourceName ?? source.sourceId} does not have an explicit connector/parser configuration.',
        suggestedAction:
            'Let Atlas infer it for first import, then persist the confirmed connector if the source is important.',
        sourceId: source.sourceId,
      ));
    }
    if (source.importStatus == AieImportStatus.failed) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.parserMismatch,
        severity: AtlasDataQualitySeverity.critical,
        title: 'Last import failed',
        detail:
            '${source.sourceName ?? source.sourceId} is currently failing imports.',
        suggestedAction:
            'Open import diagnostics, fix the connector/source, then retry.',
        sourceId: source.sourceId,
      ));
    }

    final lastImport = source.lastSuccessfulImport;
    if (lastImport == null) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.staleImport,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Never imported',
        detail:
            '${source.sourceName ?? source.sourceId} has not completed a successful import yet.',
        suggestedAction:
            'Run a manual import to establish the first Atlas version.',
        sourceId: source.sourceId,
      ));
    } else {
      final age = now.difference(lastImport);
      if (age.inDays > 30) {
        issues.add(AtlasDataQualityIssue(
          type: AtlasDataQualityIssueType.staleImport,
          severity: AtlasDataQualitySeverity.critical,
          title: 'Stale source import',
          detail:
              '${source.sourceName ?? source.sourceId} last imported ${age.inDays} days ago.',
          suggestedAction: 'Refresh this official source and review changes.',
          sourceId: source.sourceId,
        ));
      } else if (age.inDays > 14) {
        issues.add(AtlasDataQualityIssue(
          type: AtlasDataQualityIssueType.staleImport,
          severity: AtlasDataQualitySeverity.warning,
          title: 'Source freshness warning',
          detail:
              '${source.sourceName ?? source.sourceId} last imported ${age.inDays} days ago.',
          suggestedAction: 'Schedule a refresh to keep Atlas live.',
          sourceId: source.sourceId,
        ));
      }
    }

    return issues;
  }

  List<AtlasDataQualityIssue> _restrictionIssues(
    AieStructuredRestriction record,
    DateTime now,
  ) {
    final issues = <AtlasDataQualityIssue>[];
    if (record.roadName.trim().isEmpty ||
        record.roadName == 'Unknown road' ||
        record.restrictionType.trim().isEmpty ||
        record.sourceId.trim().isEmpty ||
        record.sourceUrl.trim().isEmpty) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.missingMetadata,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Missing restriction metadata',
        detail:
            'Restriction ${record.ruleId} is missing road, restriction type, source ID, or source URL.',
        suggestedAction:
            'Improve parser mapping so every legal record has clear attribution.',
        sourceId: record.sourceId,
        recordId: record.ruleId,
        roadName: record.roadName,
      ));
    }

    if (!_validLatLng(record.latitude, record.longitude)) {
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.invalidGeometry,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Invalid or missing geometry',
        detail:
            'Restriction ${record.ruleId} does not have a valid latitude/longitude pair.',
        suggestedAction:
            'Geocode from official geometry or flag for Pioneer verification.',
        sourceId: record.sourceId,
        recordId: record.ruleId,
        roadName: record.roadName,
      ));
    }

    if (record.temporaryRestriction == true) {
      final expiry = _rawDate(record.raw, const [
        'expiresAt',
        'validUntil',
        'endDate',
        'end_at',
        'to',
      ]);
      if (expiry != null && expiry.isBefore(now)) {
        issues.add(AtlasDataQualityIssue(
          type: AtlasDataQualityIssueType.expiredRestriction,
          severity: AtlasDataQualitySeverity.critical,
          title: 'Expired temporary restriction',
          detail:
              'Temporary restriction ${record.ruleId} expired on ${expiry.toIso8601String().split('T').first}.',
          suggestedAction:
              'Remove from live answers only after preserving the historical version.',
          sourceId: record.sourceId,
          recordId: record.ruleId,
          roadName: record.roadName,
        ));
      }
    }

    return issues;
  }

  List<AtlasDataQualityIssue> _duplicateSourceIssues(
    List<AieSource> sources,
  ) {
    final seen = <String, AieSource>{};
    final issues = <AtlasDataQualityIssue>[];
    for (final source in sources) {
      final key = _normalise('${source.council}|${source.sourceUrl}');
      final existing = seen[key];
      if (existing == null) {
        seen[key] = source;
        continue;
      }
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.duplicateSource,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Duplicate official source',
        detail:
            '${source.sourceName ?? source.sourceId} duplicates ${existing.sourceName ?? existing.sourceId}.',
        suggestedAction:
            'Keep one canonical source and disable duplicates before importing.',
        sourceId: source.sourceId,
      ));
    }
    return issues;
  }

  List<AtlasDataQualityIssue> _duplicateGeometryIssues(
    List<AieStructuredRestriction> restrictions,
  ) {
    final seen = <String, AieStructuredRestriction>{};
    final issues = <AtlasDataQualityIssue>[];
    for (final record in restrictions) {
      if (!_validLatLng(record.latitude, record.longitude)) continue;
      final key =
          '${record.latitude!.toStringAsFixed(5)}|${record.longitude!.toStringAsFixed(5)}|${_normalise(record.roadName)}|${_normalise(record.restrictionType)}';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = record;
        continue;
      }
      issues.add(AtlasDataQualityIssue(
        type: AtlasDataQualityIssueType.duplicateGeometry,
        severity: AtlasDataQualitySeverity.warning,
        title: 'Duplicate geometry',
        detail:
            '${record.ruleId} appears to duplicate ${existing.ruleId} at the same road/coordinate.',
        suggestedAction:
            'Merge duplicate legal records or keep both only if they represent separate bays.',
        sourceId: record.sourceId,
        recordId: record.ruleId,
        roadName: record.roadName,
      ));
    }
    return issues;
  }

  List<AtlasDataQualityIssue> _conflictingRestrictionIssues(
    List<AieStructuredRestriction> restrictions,
  ) {
    final byWindow = <String, AieStructuredRestriction>{};
    final issues = <AtlasDataQualityIssue>[];
    for (final record in restrictions) {
      if (record.parkingAllowed == null) continue;
      final key =
          '${_normalise(record.roadName)}|${_normalise(record.activeHours)}|${record.activeDays.map(_normalise).join(',')}';
      final existing = byWindow[key];
      if (existing == null) {
        byWindow[key] = record;
        continue;
      }
      if (existing.parkingAllowed != record.parkingAllowed) {
        issues.add(AtlasDataQualityIssue(
          type: AtlasDataQualityIssueType.conflictingRestriction,
          severity: AtlasDataQualitySeverity.critical,
          title: 'Conflicting restrictions',
          detail:
              '${record.ruleId} disagrees with ${existing.ruleId} for ${record.roadName} during ${record.activeHours}.',
          suggestedAction:
              'Create an IRIS review item and request field evidence before using this in confident answers.',
          sourceId: record.sourceId,
          recordId: record.ruleId,
          roadName: record.roadName,
        ));
      }
    }
    return issues;
  }

  AtlasDataQualityReport _report(List<AtlasDataQualityIssue> issues) {
    final critical = issues
        .where((issue) => issue.severity == AtlasDataQualitySeverity.critical)
        .length;
    final warnings = issues
        .where((issue) => issue.severity == AtlasDataQualitySeverity.warning)
        .length;
    final score = (1 - critical * 0.22 - warnings * 0.08).clamp(0, 1);
    final health = critical > 0
        ? issues.any((issue) =>
                issue.type == AtlasDataQualityIssueType.conflictingRestriction)
            ? AtlasOperationalHealth.conflict
            : AtlasOperationalHealth.offline
        : warnings > 0
            ? issues.any((issue) =>
                    issue.type == AtlasDataQualityIssueType.staleImport)
                ? AtlasOperationalHealth.stale
                : AtlasOperationalHealth.warning
            : AtlasOperationalHealth.healthy;
    return AtlasDataQualityReport(
      health: health,
      healthScore: score.toDouble(),
      issues: List.unmodifiable(issues),
    );
  }

  bool _validLatLng(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  DateTime? _rawDate(Map<String, Object?> raw, List<String> keys) {
    for (final key in keys) {
      final value = raw[key];
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  String _normalise(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
