import 'package:parkpal/features/atlas_intelligence/aie_models.dart';
import 'package:parkpal/features/atlas_intelligence/aie_parser_engine.dart';
import 'package:test/test.dart';

void main() {
  const source = AieSource(
    sourceId: 'westminster_tro',
    sourceUrl: 'https://example.gov.uk/tro',
    council: 'Westminster City Council',
    sourceType: AieSourceType.trafficRegulationOrder,
    documentType: AieDocumentType.html,
    importStatus: AieImportStatus.idle,
    version: 0,
    confidence: 1,
    enabled: true,
  );

  test('IRIS parser structures legal waiting text', () {
    const parser = AieParserEngine();
    final records = parser.parse(
      source: source,
      rawData: 'Waiting prohibited Mon-Sat 08:30-18:30 on Baker Street.',
    );

    expect(records, hasLength(1));
    expect(records.single.restrictionType, 'No Waiting');
    expect(records.single.roadName, 'Baker Street');
    expect(records.single.activeDays, [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
    ]);
    expect(records.single.startTime, '08:30');
    expect(records.single.endTime, '18:30');
    expect(records.single.parkingAllowed, isFalse);
    expect(records.single.confidence, AieConfidence.official);
  });

  test('CSV official data normalises into structured restrictions', () {
    const parser = AieParserEngine();
    final records = parser.parse(
      source: const AieSource(
        sourceId: 'camden_cpz',
        sourceUrl: 'https://example.gov.uk/cpz.csv',
        council: 'Camden Council',
        sourceType: AieSourceType.controlledParkingZone,
        documentType: AieDocumentType.csv,
        importStatus: AieImportStatus.idle,
        version: 0,
        confidence: 1,
        enabled: true,
      ),
      rawData:
          'roadName,restrictionType,activeDays,activeHours,permitRequired\nCamden High Street,Permit Parking,"Mon,Fri",08:30-18:30,true',
    );

    expect(records, hasLength(1));
    expect(records.single.roadName, 'Camden High Street');
    expect(records.single.restrictionType, 'Permit Parking');
    expect(records.single.permitRequired, isTrue);
    expect(records.single.activeHours, '08:30-18:30');
  });
}
