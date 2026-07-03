import 'package:parkpal/features/dtro/dtro_legal_service.dart';
import 'package:parkpal/features/dtro/dtro_models.dart';
import 'package:test/test.dart';

void main() {
  test('D-TRO regulation type mapping preserves official code names', () {
    final type = dtroRegulationTypeFromCode('kerbsideNoWaiting');

    expect(type, DtroRegulationType.kerbsideNoWaiting);
    expect(dtroRegulationTypeCode(type), 'kerbsideNoWaiting');
  });

  test('IRIS explanation is separate from official regulation type', () {
    final type = DtroRegulationType.kerbsideResidentParkingPlace;

    expect(dtroRegulationTypeCode(type), 'kerbsideResidentParkingPlace');
    expect(dtroIrisLabel(type), 'Resident permit holders only');
    expect(dtroIrisExplanation(type), 'Resident permit holders only.');
  });

  test('normalizes provision into ParkPal legal record shape', () {
    final service = DtroLegalService();
    const authority = DtroAuthority(
      authorityId: 'camden',
      name: 'Camden Council',
    );
    const source = DtroSource(
      sourceId: 'dtro-api',
      sourceUrl: 'https://example.invalid/dtro',
      name: 'D-TRO API',
      status: DtroSourceStatus.draft,
      version: 'v1',
    );
    const provision = DtroProvision(
      provisionId: 'p1',
      regulationType: DtroRegulationType.kerbsideNoWaiting,
      geometry: DtroGeometry(
        type: 'LineString',
        coordinates: [
          [-0.1, 51.5],
          [-0.11, 51.51],
        ],
      ),
      conditions: [
        DtroCondition(
          timeValidity: DtroTimeValidity(
            days: ['Monday', 'Tuesday'],
            startTime: '08:30',
            endTime: '18:30',
          ),
        ),
      ],
    );

    final record = service.normalizeProvision(
      troId: 'tro-1',
      authority: authority,
      source: source,
      provision: provision,
      rawProvision: const {'regulationType': 'kerbsideNoWaiting'},
      version: '2026-01',
    );

    expect(record.id, 'tro-1_p1');
    expect(record.regulationType, DtroRegulationType.kerbsideNoWaiting);
    expect(record.irisExplanation, 'No waiting is allowed here.');
    expect(record.geometry?.type, 'LineString');
    expect(record.verificationStatus, DtroVerificationStatus.pending);
    expect(record.toMap()['rawProvision'],
        {'regulationType': 'kerbsideNoWaiting'});
  });
}
