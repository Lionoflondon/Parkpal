import 'dart:convert';

import 'aie_models.dart';

class AieSourceConnectorEngine {
  const AieSourceConnectorEngine();

  AieConnectorDecision detect({
    required AieSource source,
    required String input,
    String? contentType,
    String? url,
  }) {
    final configuredConnector = source.connectorType;
    final configuredParser = source.parserType;
    final detectedConnector = _detectConnector(
      source: source,
      input: input,
      contentType: contentType,
      url: url,
    );
    final connectorType = configuredConnector ?? detectedConnector;
    final parserType = configuredParser ?? _parserFor(connectorType, source);
    final expectedFormat = _expectedFormat(connectorType, parserType);
    final detectedFormat = _detectedFormat(
      connectorType: detectedConnector,
      input: input,
      contentType: contentType,
      url: url,
    );
    final validation = validate(
      source: source,
      connectorType: connectorType,
      parserType: parserType,
      input: input,
      contentType: contentType,
    );

    return AieConnectorDecision(
      connectorType: connectorType,
      parserType: parserType,
      documentType: _documentTypeFor(parserType, source.documentType),
      expectedFormat: expectedFormat,
      detectedFormat: detectedFormat,
      valid: validation.valid,
      reasonForFailure: validation.reasonForFailure,
      suggestedAction: validation.suggestedAction,
      geometrySupported: _geometrySupported(source, connectorType, input),
      diagnostics: {
        'connectorType': connectorType.name,
        'parserType': parserType.name,
        'connectorUsed': _connectorLabel(connectorType),
        'expectedFormat': expectedFormat,
        'detectedFormat': detectedFormat,
        'geometrySupport': _geometrySupported(source, connectorType, input),
        'authenticationRequired': source.authenticationRequirements.isNotEmpty,
        'expectedHeaders': source.expectedHeaders,
        if (validation.reasonForFailure != null)
          'reasonForFailure': validation.reasonForFailure,
        if (validation.suggestedAction != null)
          'suggestedAction': validation.suggestedAction,
      },
    );
  }

  AieConnectorValidation validate({
    required AieSource source,
    required AieConnectorType connectorType,
    required AieParserType parserType,
    required String input,
    String? contentType,
  }) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Empty response',
        suggestedAction:
            'Paste official data or provide a reachable official download URL.',
      );
    }
    if (connectorType == AieConnectorType.pdf) {
      if (_looksPdf(trimmed, contentType)) {
        return const AieConnectorValidation.success();
      }
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Detected content is not a PDF',
        suggestedAction:
            'Check the source URL points directly to a PDF, or change connector type.',
      );
    }
    if (parserType == AieParserType.csv && _looksHtml(trimmed, contentType)) {
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Returned HTML not CSV',
        suggestedAction:
            'Use the official export/download URL rather than a landing or login page.',
      );
    }
    if (parserType == AieParserType.csv && !_hasCsvHeader(trimmed)) {
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Invalid CSV headers',
        suggestedAction:
            'Confirm the CSV has a header row with fields such as roadName, streetName, restrictionType, description, latitude or longitude.',
      );
    }
    if ((parserType == AieParserType.json ||
            parserType == AieParserType.geojson ||
            parserType == AieParserType.socrataOpenData) &&
        !_validJson(trimmed)) {
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Invalid JSON',
        suggestedAction:
            'Confirm the source exports valid JSON/GeoJSON or switch the connector to the detected format.',
      );
    }
    if ((parserType == AieParserType.xml || parserType == AieParserType.rss) &&
        !_looksXml(trimmed, contentType)) {
      return const AieConnectorValidation.failure(
        reasonForFailure: 'Invalid XML',
        suggestedAction:
            'Confirm the source returns XML/RSS, or switch to CSV/JSON if that is what the source provides.',
      );
    }
    return const AieConnectorValidation.success();
  }

  String fingerprintFor(AieSource source, AieConnectorDecision decision) {
    final payload = jsonEncode({
      'connectorType': decision.connectorType.name,
      'parserType': decision.parserType.name,
      'documentType': decision.documentType.name,
      'validationRules': source.validationRules,
      'authenticationRequirements': source.authenticationRequirements,
      'expectedHeaders': source.expectedHeaders,
      'geometrySupport': decision.geometrySupported,
    });
    var hash = 5381;
    for (final code in payload.codeUnits) {
      hash = ((hash << 5) + hash + code) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }

  AieConnectorType _detectConnector({
    required AieSource source,
    required String input,
    String? contentType,
    String? url,
  }) {
    final target =
        '${url ?? source.sourceUrl}\n${input.substring(0, input.length > 300 ? 300 : input.length)}';
    final lower = target.toLowerCase();
    final content = contentType?.toLowerCase() ?? '';
    if (_looksSocrata(lower)) return AieConnectorType.socrataOpenData;
    if (_looksPdf(input, contentType) || lower.contains('.pdf')) {
      return AieConnectorType.pdf;
    }
    if (content.contains('geo+json') ||
        content.contains('geojson') ||
        _looksGeoJson(input)) {
      return AieConnectorType.geojson;
    }
    if (content.contains('json') || _looksJson(input)) {
      return AieConnectorType.json;
    }
    if (content.contains('rss') || _looksRss(input)) {
      return AieConnectorType.rss;
    }
    if (content.contains('xml') || _looksXml(input, contentType)) {
      return AieConnectorType.xml;
    }
    if (content.contains('csv') || _hasCsvHeader(input)) {
      return AieConnectorType.csv;
    }
    if (Uri.tryParse(url ?? source.sourceUrl)?.hasAbsolutePath ?? false) {
      return AieConnectorType.genericHttp;
    }
    return AieConnectorType.csv;
  }

  AieParserType _parserFor(AieConnectorType connectorType, AieSource source) {
    return switch (connectorType) {
      AieConnectorType.csv => AieParserType.csv,
      AieConnectorType.json => AieParserType.json,
      AieConnectorType.geojson => AieParserType.geojson,
      AieConnectorType.xml => AieParserType.xml,
      AieConnectorType.rss => AieParserType.rss,
      AieConnectorType.pdf => AieParserType.pdf,
      AieConnectorType.socrataOpenData => AieParserType.socrataOpenData,
      AieConnectorType.genericHttp => _parserForDocument(source.documentType),
    };
  }

  AieParserType _parserForDocument(AieDocumentType documentType) {
    return switch (documentType) {
      AieDocumentType.csv => AieParserType.csv,
      AieDocumentType.json => AieParserType.json,
      AieDocumentType.geojson => AieParserType.geojson,
      AieDocumentType.xml => AieParserType.xml,
      AieDocumentType.rss => AieParserType.rss,
      AieDocumentType.pdf => AieParserType.pdf,
      AieDocumentType.html || AieDocumentType.docx => AieParserType.text,
    };
  }

  AieDocumentType _documentTypeFor(
    AieParserType parserType,
    AieDocumentType fallback,
  ) {
    return switch (parserType) {
      AieParserType.csv => AieDocumentType.csv,
      AieParserType.json => AieDocumentType.json,
      AieParserType.geojson => AieDocumentType.geojson,
      AieParserType.xml => AieDocumentType.xml,
      AieParserType.rss => AieDocumentType.rss,
      AieParserType.pdf => AieDocumentType.pdf,
      AieParserType.text => fallback,
      AieParserType.socrataOpenData => AieDocumentType.json,
    };
  }

  String _expectedFormat(
    AieConnectorType connectorType,
    AieParserType parserType,
  ) {
    return switch (connectorType) {
      AieConnectorType.socrataOpenData =>
        'Socrata/Open Data API export routed to CSV, JSON or GeoJSON',
      AieConnectorType.genericHttp =>
        'Generic HTTP download parsed as ${parserType.name.toUpperCase()}',
      _ => parserType.name.toUpperCase(),
    };
  }

  String _detectedFormat({
    required AieConnectorType connectorType,
    required String input,
    String? contentType,
    String? url,
  }) {
    if (contentType != null && contentType.isNotEmpty) {
      return contentType;
    }
    if (_looksSocrata('${url ?? ''}\n$input')) return 'Socrata/Open Data';
    if (_looksGeoJson(input)) return 'GeoJSON';
    if (_looksJson(input)) return 'JSON';
    if (_looksRss(input)) return 'RSS';
    if (_looksXml(input, contentType)) return 'XML';
    if (_looksPdf(input, contentType)) return 'PDF';
    if (_hasCsvHeader(input)) return 'CSV';
    return connectorType == AieConnectorType.genericHttp
        ? 'Unknown HTTP response'
        : connectorType.name;
  }

  String _connectorLabel(AieConnectorType connectorType) {
    return switch (connectorType) {
      AieConnectorType.csv => 'CsvSourceConnector',
      AieConnectorType.json => 'JsonSourceConnector',
      AieConnectorType.geojson => 'GeoJsonSourceConnector',
      AieConnectorType.xml => 'XmlSourceConnector',
      AieConnectorType.rss => 'RssSourceConnector',
      AieConnectorType.pdf => 'PdfSourceConnector',
      AieConnectorType.socrataOpenData => 'SocrataOpenDataSourceConnector',
      AieConnectorType.genericHttp => 'GenericHttpSourceConnector',
    };
  }

  bool _geometrySupported(
    AieSource source,
    AieConnectorType connectorType,
    String input,
  ) {
    if (source.geometrySupport) return true;
    if (connectorType == AieConnectorType.geojson ||
        connectorType == AieConnectorType.socrataOpenData) {
      return true;
    }
    final lower = input.toLowerCase();
    return lower.contains('latitude') && lower.contains('longitude') ||
        lower.contains('"geometry"');
  }

  bool _looksSocrata(String value) {
    final lower = value.toLowerCase();
    return lower.contains('socrata') ||
        lower.contains('/api/views/') ||
        lower.contains('/api/v3/views/') ||
        lower.contains('/resource/') ||
        lower.contains('/dataset/');
  }

  bool _looksJson(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  bool _validJson(String value) {
    try {
      jsonDecode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _looksGeoJson(String value) {
    if (!_looksJson(value)) return false;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map &&
          (decoded['type'] == 'FeatureCollection' ||
              decoded['features'] is List);
    } catch (_) {
      return false;
    }
  }

  bool _looksXml(String value, String? contentType) {
    final content = contentType?.toLowerCase() ?? '';
    final trimmed = value.trimLeft().toLowerCase();
    return content.contains('xml') ||
        trimmed.startsWith('<?xml') ||
        trimmed.startsWith('<root') ||
        trimmed.startsWith('<feed') ||
        trimmed.startsWith('<rss');
  }

  bool _looksRss(String value) {
    final lower = value.trimLeft().toLowerCase();
    return lower.startsWith('<rss') || lower.startsWith('<feed');
  }

  bool _looksPdf(String value, String? contentType) {
    final content = contentType?.toLowerCase() ?? '';
    return content.contains('pdf') || value.startsWith('%PDF');
  }

  bool _looksHtml(String value, String? contentType) {
    final content = contentType?.toLowerCase() ?? '';
    final lower = value.trimLeft().toLowerCase();
    return content.contains('html') ||
        lower.startsWith('<!doctype html') ||
        lower.startsWith('<html');
  }

  bool _hasCsvHeader(String value) {
    final lines = value
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2 || !lines.first.contains(',')) return false;
    final headers = lines.first
        .split(',')
        .map((header) => header.trim().toLowerCase())
        .toList(growable: false);
    const known = {
      'roadname',
      'streetname',
      'street',
      'road',
      'location',
      'highway',
      'restriction',
      'restrictiontype',
      'type',
      'description',
      'summary',
      'legaltext',
      'latitude',
      'longitude',
      'lat',
      'lon',
      'lng',
      'x',
      'y',
    };
    return headers.any(known.contains);
  }
}

class AieConnectorDecision {
  const AieConnectorDecision({
    required this.connectorType,
    required this.parserType,
    required this.documentType,
    required this.expectedFormat,
    required this.detectedFormat,
    required this.valid,
    required this.geometrySupported,
    this.reasonForFailure,
    this.suggestedAction,
    this.diagnostics = const {},
  });

  final AieConnectorType connectorType;
  final AieParserType parserType;
  final AieDocumentType documentType;
  final String expectedFormat;
  final String detectedFormat;
  final bool valid;
  final bool geometrySupported;
  final String? reasonForFailure;
  final String? suggestedAction;
  final Map<String, Object?> diagnostics;
}

class AieConnectorValidation {
  const AieConnectorValidation.success()
      : valid = true,
        reasonForFailure = null,
        suggestedAction = null;

  const AieConnectorValidation.failure({
    required this.reasonForFailure,
    required this.suggestedAction,
  }) : valid = false;

  final bool valid;
  final String? reasonForFailure;
  final String? suggestedAction;
}
