import 'package:parkpal/features/atlas_intelligence/aie_import_engine.dart';
import 'package:parkpal/features/atlas_intelligence/aie_models.dart';
import 'package:parkpal/features/atlas_intelligence/aie_parser_engine.dart';
import 'package:test/test.dart';

void main() {
  const westminsterSource = AieSource(
    sourceId: 'westminster_csv',
    sourceUrl: 'https://www.westminster.gov.uk/parking.csv',
    council: 'Westminster City Council',
    sourceType: AieSourceType.openDataApi,
    documentType: AieDocumentType.csv,
    importStatus: AieImportStatus.idle,
    version: 0,
    confidence: 1,
    enabled: true,
  );

  test('raw CSV import input is accepted and parsed', () async {
    final engine = AieImportEngine(fetchClient: _FakeFetchClient());
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input:
          'roadName,restrictionType,activeHours\nBaker Street,No Waiting,08:30-18:30',
    );
    final records = const AieParserEngine().parse(
      source: westminsterSource,
      rawData: resolved.body,
    );

    expect(resolved.success, isTrue);
    expect(resolved.fetchUrl, isNull);
    expect(records, hasLength(1));
    expect(records.single.roadName, 'Baker Street');
  });

  test('CSV URL import fetches downloadable official data', () async {
    final engine = AieImportEngine(
      fetchClient: _FakeFetchClient({
        'https://data.westminster.gov.uk/parking.csv': const AieFetchResponse(
          statusCode: 200,
          contentType: 'text/csv',
          finalUrl: 'https://data.westminster.gov.uk/parking.csv',
          body:
              'roadName,restrictionType,activeHours\nOxford Street,No Waiting,08:30-18:30',
        ),
      }),
    );
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: 'https://data.westminster.gov.uk/parking.csv',
    );
    final records = const AieParserEngine().parse(
      source: westminsterSource,
      rawData: resolved.body,
    );

    expect(resolved.success, isTrue);
    expect(resolved.fetchUrl, 'https://data.westminster.gov.uk/parking.csv');
    expect(resolved.contentType, 'text/csv');
    expect(resolved.fetchedAt, isNotNull);
    expect(resolved.diagnostics['httpStatus'], 200);
    expect(resolved.diagnostics['finalUrl'],
        'https://data.westminster.gov.uk/parking.csv');
    expect(resolved.diagnostics['responseSize'], greaterThan(20));
    expect(resolved.diagnostics['selectedParser'], 'csv');
    expect(resolved.diagnostics['responsePreview'], contains('Oxford Street'));
    expect(records.single.roadName, 'Oxford Street');
  });

  test('empty body fails clearly', () async {
    final engine = AieImportEngine(fetchClient: _FakeFetchClient());
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: '   ',
    );

    expect(resolved.success, isFalse);
    expect(resolved.messages.join(' '), contains('Empty response'));
    expect(resolved.diagnostics['failureStage'], 'validation');
    expect(resolved.diagnostics['failureLabel'], 'Empty response');
  });

  test('missing source URL records url build failure stage', () async {
    const missingUrlSource = AieSource(
      sourceId: 'westminster_missing_url',
      sourceUrl: '',
      council: 'Westminster City Council',
      sourceType: AieSourceType.openDataApi,
      documentType: AieDocumentType.csv,
      importStatus: AieImportStatus.idle,
      version: 0,
      confidence: 1,
      enabled: true,
    );
    final engine = AieImportEngine(fetchClient: _FakeFetchClient());
    final resolved = await engine.resolveImportInput(
      source: missingUrlSource,
      input: '   ',
    );

    expect(resolved.success, isFalse);
    expect(resolved.diagnostics['failureStage'], 'url_build');
    expect(resolved.diagnostics['failureLabel'], 'Missing source URL');
    expect(resolved.diagnostics['originalSourceUrl'], '');
  });

  test('unreachable URL fails clearly', () async {
    final engine = AieImportEngine(fetchClient: _FakeFetchClient());
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: 'https://example.invalid/missing.csv',
    );

    expect(resolved.success, isFalse);
    expect(resolved.messages, contains('URL unreachable.'));
    expect(resolved.diagnostics['failureStage'], 'http_fetch');
    expect(resolved.diagnostics['failureLabel'], 'URL unreachable');
    expect(resolved.diagnostics['exceptionType'], isNull);
  });

  test('HTTP status failure records diagnostics', () async {
    final engine = AieImportEngine(
      fetchClient: _FakeFetchClient({
        'https://data.westminster.gov.uk/private.csv': const AieFetchResponse(
          statusCode: 403,
          contentType: 'text/html',
          finalUrl: 'https://data.westminster.gov.uk/private.csv',
          body: '<html>Forbidden</html>',
        ),
      }),
    );
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: 'https://data.westminster.gov.uk/private.csv',
    );

    expect(resolved.success, isFalse);
    expect(resolved.messages, contains('HTTP 403.'));
    expect(resolved.diagnostics['failureStage'], 'http_fetch');
    expect(resolved.diagnostics['failureLabel'], 'HTTP 403');
    expect(resolved.diagnostics['httpStatus'], 403);
    expect(resolved.diagnostics['responsePreview'], contains('Forbidden'));
  });

  test('HTML returned for selected CSV is labelled clearly', () async {
    final engine = AieImportEngine(
      fetchClient: _FakeFetchClient({
        'https://data.westminster.gov.uk/download': const AieFetchResponse(
          statusCode: 200,
          contentType: 'text/html; charset=utf-8',
          finalUrl: 'https://data.westminster.gov.uk/download',
          body: '<html><title>Sign in</title></html>',
        ),
      }),
    );
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: 'https://data.westminster.gov.uk/download',
    );

    expect(resolved.success, isTrue);
    expect(resolved.messages, contains('Returned HTML not CSV.'));
    expect(resolved.diagnostics['failureStage'], 'parser_selection');
    expect(resolved.diagnostics['failureLabel'], 'Returned HTML not CSV');
    expect(resolved.diagnostics['parserError'], 'Returned HTML not CSV.');
  });

  test('invalid CSV produces no parsed records', () async {
    final resolved = await AieImportEngine(fetchClient: _FakeFetchClient())
        .resolveImportInput(
      source: westminsterSource,
      input: 'not,a,parking,dataset\n1,2,3,4',
    );
    final records = const AieParserEngine().parse(
      source: westminsterSource,
      rawData: resolved.body,
    );

    expect(resolved.success, isTrue);
    expect(records, isEmpty);
  });

  test('duplicate checksum skip is detected', () async {
    final engine = AieImportEngine(fetchClient: _FakeFetchClient());
    final first = await engine.resolveImportInput(
      source: westminsterSource,
      input:
          'roadName,restrictionType,activeHours\nBaker Street,No Waiting,08:30-18:30',
    );
    final second = await engine.resolveImportInput(
      source: westminsterSource,
      input:
          'roadName,restrictionType,activeHours\nBaker Street,No Waiting,08:30-18:30',
    );

    expect(engine.isDuplicateChecksum(first.checksum, second.checksum), isTrue);
  });

  test('selected council/source mismatch warning is returned', () async {
    final engine = AieImportEngine(
      fetchClient: _FakeFetchClient({
        'https://opendata.camden.gov.uk/parking.csv': const AieFetchResponse(
          statusCode: 200,
          contentType: 'text/csv',
          finalUrl: 'https://opendata.camden.gov.uk/parking.csv',
          body:
              'roadName,council,restrictionType\nCamden High Street,Camden Council,Permit Parking',
        ),
      }),
    );
    final resolved = await engine.resolveImportInput(
      source: westminsterSource,
      input: 'https://opendata.camden.gov.uk/parking.csv',
    );

    expect(resolved.success, isTrue);
    expect(
      resolved.messages,
      contains('Selected council may not match source dataset.'),
    );
  });
}

class _FakeFetchClient implements AieFetchClient {
  _FakeFetchClient([this.responses = const {}]);

  final Map<String, AieFetchResponse> responses;

  @override
  Future<AieFetchResponse> get(Uri uri) async {
    return responses[uri.toString()] ?? const AieFetchResponse.unreachable();
  }
}
