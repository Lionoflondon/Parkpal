import 'package:parkpal/features/atlas_intelligence/aie_models.dart';
import 'package:test/test.dart';

void main() {
  test(
      'canonical Atlas record preserves restriction and customer safety fields',
      () {
    final importedAt = DateTime.utc(2026, 7, 16, 10);
    const restriction = AieStructuredRestriction(
      ruleId: 'rule-1',
      roadName: 'Oxford Street',
      council: 'Westminster City Council',
      restrictionType: 'No Waiting',
      activeDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
      activeHours: '08:30-18:30',
      maxStayMinutes: 30,
      parkingAllowed: false,
      loadingAllowed: true,
      permitRequired: false,
      sourceId: 'westminster_tro',
      sourceUrl: 'https://example.gov.uk/tro.csv',
      sourceText: 'Waiting prohibited Mon-Fri 08:30-18:30',
      latitude: 51.515,
      longitude: -0.141,
    );

    final record = AtlasCanonicalIntelligenceRecord.fromRestriction(
      restriction: restriction,
      roadId: 'westminster_oxford_street',
      importBatchId: 'batch-1',
      importedAt: importedAt,
      sourcePriority: 100,
    );
    final map = record.toMap();

    expect(record.kind, AtlasIntelligenceKind.maximumStay);
    expect(map['parkingAllowed'], isFalse);
    expect(map['loadingAllowed'], isTrue);
    expect(map['sourcePriority'], 100);
    expect(map['sourceFreshness'], 1);
    expect(map['verificationState'], AtlasVerificationState.official.name);
    expect(map['customerSafetyState'], AtlasCustomerSafetyState.confirmed.name);
    expect(map['geographicCoverage'], 1);
    expect(map['confidencePercent'], 100);
  });

  test('canonical Atlas record degrades customer safety on conflicts', () {
    final record = AtlasCanonicalIntelligenceRecord.fromRestriction(
      restriction: const AieStructuredRestriction(
        ruleId: 'rule-2',
        roadName: 'Camden High Street',
        council: 'Camden Council',
        restrictionType: 'Permit Holders Only',
        activeDays: ['Mon'],
        activeHours: '09:00-17:00',
        parkingAllowed: false,
        permitRequired: true,
        sourceId: 'camden_cpz',
        sourceUrl: 'https://example.gov.uk/cpz.csv',
        sourceText: 'Permit holders only',
      ),
      roadId: 'camden_camden_high_street',
      importBatchId: 'batch-2',
      importedAt: DateTime.utc(2026, 7, 16),
      conflictId: 'conflict-1',
    );

    expect(record.verificationState, AtlasVerificationState.conflict);
    expect(record.customerSafetyState, AtlasCustomerSafetyState.conflicting);
    expect(record.confidence, lessThan(0.5));
    expect(record.warnings.single, contains('Customer certainty degraded'));
  });
}
