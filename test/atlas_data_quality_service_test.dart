import 'package:flutter_test/flutter_test.dart';
import 'package:parkpal/features/atlas_intelligence/aie_models.dart';
import 'package:parkpal/features/atlas_intelligence/aie_source_connector_engine.dart';
import 'package:parkpal/features/atlas_intelligence/atlas_data_quality_service.dart';

void main() {
  group('AtlasDataQualityService', () {
    const service = AtlasDataQualityService();

    test('flags duplicate sources and stale imports', () {
      final now = DateTime(2026, 7, 16);
      final sources = [
        _source(
          'camden-1',
          sourceUrl: 'https://opendata.camden.gov.uk/resource/a.csv',
          lastSuccessfulImport: now.subtract(const Duration(days: 40)),
        ),
        _source(
          'camden-2',
          sourceUrl: 'https://opendata.camden.gov.uk/resource/a.csv',
          lastSuccessfulImport: now,
        ),
      ];

      final report = service.assessSources(sources, now: now);

      expect(report.health, AtlasOperationalHealth.offline);
      expect(
        report.issues.map((issue) => issue.type),
        containsAll([
          AtlasDataQualityIssueType.duplicateSource,
          AtlasDataQualityIssueType.staleImport,
        ]),
      );
    });

    test('flags invalid geometry, duplicate geometry, and conflicts', () {
      final records = [
        _restriction(
          'r1',
          roadName: 'Oxford Street',
          latitude: 51.515,
          longitude: -0.141,
          parkingAllowed: true,
        ),
        _restriction(
          'r2',
          roadName: 'Oxford Street',
          latitude: 51.515,
          longitude: -0.141,
          parkingAllowed: false,
        ),
        _restriction(
          'r3',
          roadName: 'Baker Street',
          latitude: 0,
          longitude: 0,
        ),
      ];

      final report = service.assessRestrictions(records);

      expect(report.health, AtlasOperationalHealth.conflict);
      expect(
        report.issues.map((issue) => issue.type),
        containsAll([
          AtlasDataQualityIssueType.invalidGeometry,
          AtlasDataQualityIssueType.duplicateGeometry,
          AtlasDataQualityIssueType.conflictingRestriction,
        ]),
      );
    });

    test('records parser mismatch details from connector decision', () {
      final source = _source('westminster-csv');
      const decision = AieConnectorDecision(
        connectorType: AieConnectorType.csv,
        parserType: AieParserType.csv,
        documentType: AieDocumentType.csv,
        expectedFormat: 'CSV',
        detectedFormat: 'text/html',
        valid: false,
        geometrySupported: false,
        reasonForFailure: 'Returned HTML not CSV',
        suggestedAction: 'Use the official export URL.',
      );

      final report = service.assessImport(
        source: source,
        connector: decision,
        restrictions: const [],
        now: DateTime(2026, 7, 16),
      );

      final parserIssue = report.issues.firstWhere(
        (issue) => issue.type == AtlasDataQualityIssueType.parserMismatch,
      );
      expect(parserIssue.detail, contains('Returned HTML not CSV'));
      expect(parserIssue.suggestedAction, 'Use the official export URL.');
    });

    test('handles large imported restriction batches without rebuilding state',
        () {
      final records = List.generate(
        5000,
        (index) => _restriction(
          'rule-$index',
          roadName: 'Road $index',
          latitude: 51 + index / 100000,
          longitude: -0.1 - index / 100000,
          parkingAllowed: true,
        ),
      );

      final report = service.assessRestrictions(records);

      expect(report.issues, isEmpty);
      expect(report.health, AtlasOperationalHealth.healthy);
    });
  });
}

AieSource _source(
  String id, {
  String sourceUrl = 'https://example.gov.uk/parking.csv',
  DateTime? lastSuccessfulImport,
}) {
  return AieSource(
    sourceId: id,
    sourceName: id,
    sourceUrl: sourceUrl,
    council: 'Camden',
    sourceType: AieSourceType.openDataApi,
    documentType: AieDocumentType.csv,
    importStatus: AieImportStatus.imported,
    connectorType: AieConnectorType.csv,
    parserType: AieParserType.csv,
    lastSuccessfulImport: lastSuccessfulImport,
    version: 1,
    confidence: 0.9,
    enabled: true,
  );
}

AieStructuredRestriction _restriction(
  String id, {
  required String roadName,
  double? latitude = 51.5,
  double? longitude = -0.12,
  bool? parkingAllowed,
}) {
  return AieStructuredRestriction(
    ruleId: id,
    roadName: roadName,
    council: 'Westminster',
    restrictionType: 'kerbsideNoWaiting',
    activeDays: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
    activeHours: '08:30-18:30',
    latitude: latitude,
    longitude: longitude,
    parkingAllowed: parkingAllowed,
    sourceId: 'source-1',
    sourceUrl: 'https://example.gov.uk/source.csv',
    sourceText: 'Waiting prohibited Mon-Fri 08:30-18:30',
  );
}
