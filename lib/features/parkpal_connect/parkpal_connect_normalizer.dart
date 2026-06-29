import 'dart:convert';

import 'parkpal_connect_source.dart';

class ParkPalConnectRecord {
  const ParkPalConnectRecord({
    required this.externalRecordId,
    required this.streetName,
    required this.borough,
    required this.council,
    required this.latitude,
    required this.longitude,
    required this.sourceName,
    required this.sourceUrl,
    required this.importBatchId,
    this.postcode,
    this.restrictionType,
    this.activeDays = const [],
    this.activeHours,
    this.maxStayMinutes,
    this.parkingAllowed,
    this.loadingAllowed,
    this.permitRequired,
    this.redRoute,
    this.busLane,
    this.schoolStreet,
    this.sourceUpdatedAt,
    this.rawRecord = const {},
  });

  final String externalRecordId;
  final String streetName;
  final String borough;
  final String council;
  final String? postcode;
  final double latitude;
  final double longitude;
  final String? restrictionType;
  final List<String> activeDays;
  final String? activeHours;
  final int? maxStayMinutes;
  final bool? parkingAllowed;
  final bool? loadingAllowed;
  final bool? permitRequired;
  final bool? redRoute;
  final bool? busLane;
  final bool? schoolStreet;
  final String sourceName;
  final String sourceUrl;
  final DateTime? sourceUpdatedAt;
  final String importBatchId;
  final Map<String, Object?> rawRecord;
}

class ParkPalConnectNormalizer {
  const ParkPalConnectNormalizer();

  List<ParkPalConnectRecord> parseRaw({
    required ParkPalConnectSource source,
    required String rawData,
    required String importBatchId,
  }) {
    return switch (source.sourceType) {
      ParkPalConnectSourceType.csv => _parseCsv(source, rawData, importBatchId),
      ParkPalConnectSourceType.json =>
        _parseJson(source, rawData, importBatchId),
      ParkPalConnectSourceType.geojson =>
        _parseGeoJson(source, rawData, importBatchId),
      ParkPalConnectSourceType.api =>
        _parseJson(source, rawData, importBatchId),
    };
  }

  List<ParkPalConnectRecord> _parseJson(
    ParkPalConnectSource source,
    String rawData,
    String importBatchId,
  ) {
    final decoded = jsonDecode(rawData);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['records'] is List
            ? decoded['records'] as List
            : const [];

    return rows
        .whereType<Map>()
        .map((row) => _normaliseMap(source, row, importBatchId))
        .whereType<ParkPalConnectRecord>()
        .toList(growable: false);
  }

  List<ParkPalConnectRecord> _parseGeoJson(
    ParkPalConnectSource source,
    String rawData,
    String importBatchId,
  ) {
    final decoded = jsonDecode(rawData);
    if (decoded is! Map || decoded['features'] is! List) return const [];

    return (decoded['features'] as List)
        .whereType<Map>()
        .map((feature) {
          final properties = feature['properties'];
          final geometry = feature['geometry'];
          final coordinates = geometry is Map ? geometry['coordinates'] : null;
          if (properties is! Map ||
              coordinates is! List ||
              coordinates.length < 2) {
            return null;
          }
          return _normaliseMap(
            source,
            {
              ...properties.cast<String, Object?>(),
              'longitude': coordinates[0],
              'latitude': coordinates[1],
            },
            importBatchId,
          );
        })
        .whereType<ParkPalConnectRecord>()
        .toList(growable: false);
  }

  List<ParkPalConnectRecord> _parseCsv(
    ParkPalConnectSource source,
    String rawData,
    String importBatchId,
  ) {
    final lines = rawData
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.length < 2) return const [];

    final headers = _splitCsvLine(lines.first)
        .map((header) => header.trim())
        .toList(growable: false);

    return lines
        .skip(1)
        .map((line) {
          final values = _splitCsvLine(line);
          final row = <String, Object?>{};
          for (var i = 0; i < headers.length && i < values.length; i++) {
            row[headers[i]] = values[i].trim();
          }
          return _normaliseMap(source, row, importBatchId);
        })
        .whereType<ParkPalConnectRecord>()
        .toList(growable: false);
  }

  ParkPalConnectRecord? _normaliseMap(
    ParkPalConnectSource source,
    Map<Object?, Object?> row,
    String importBatchId,
  ) {
    final latitude = _doubleValue(row, ['latitude', 'lat', 'y']);
    final longitude = _doubleValue(row, ['longitude', 'lng', 'lon', 'x']);
    final streetName =
        _stringValue(row, ['streetName', 'street', 'road', 'roadName']);
    if (latitude == null || longitude == null || streetName == null) {
      return null;
    }
    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final externalRecordId =
        _stringValue(row, ['id', 'recordId', 'externalId']) ??
            _stableHash('$streetName|$latitude|$longitude|${source.sourceId}');

    return ParkPalConnectRecord(
      externalRecordId: externalRecordId,
      streetName: streetName,
      borough: _stringValue(row, ['borough']) ?? source.borough,
      council: _stringValue(row, ['council']) ?? source.council,
      postcode: _stringValue(row, ['postcode', 'postcodeArea', 'area']),
      latitude: latitude,
      longitude: longitude,
      restrictionType:
          _stringValue(row, ['restrictionType', 'restriction', 'type']),
      activeDays: _listValue(row, ['activeDays', 'days']),
      activeHours: _stringValue(row, ['activeHours', 'hours', 'timeWindow']),
      maxStayMinutes: _intValue(row, ['maxStayMinutes', 'maxStay']),
      parkingAllowed: _boolValue(row, ['parkingAllowed', 'parking']),
      loadingAllowed: _boolValue(row, ['loadingAllowed', 'loading']),
      permitRequired: _boolValue(row, ['permitRequired', 'permit']),
      redRoute: _boolValue(row, ['redRoute']),
      busLane: _boolValue(row, ['busLane']),
      schoolStreet: _boolValue(row, ['schoolStreet']),
      sourceName: source.sourceName,
      sourceUrl: source.sourceUrl,
      sourceUpdatedAt: _dateValue(row, ['sourceUpdatedAt', 'updatedAt']),
      importBatchId: importBatchId,
      rawRecord: row.cast<String, Object?>(),
    );
  }

  List<String> _splitCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (final codeUnit in line.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  String? _stringValue(Map<Object?, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  double? _doubleValue(Map<Object?, Object?> row, List<String> keys) {
    final value = _stringValue(row, keys);
    return value == null ? null : double.tryParse(value);
  }

  int? _intValue(Map<Object?, Object?> row, List<String> keys) {
    final value = _stringValue(row, keys);
    return value == null ? null : int.tryParse(value);
  }

  bool? _boolValue(Map<Object?, Object?> row, List<String> keys) {
    final value = _stringValue(row, keys)?.toLowerCase();
    if (value == null) return null;
    if (['true', 'yes', 'y', '1'].contains(value)) return true;
    if (['false', 'no', 'n', '0'].contains(value)) return false;
    return null;
  }

  DateTime? _dateValue(Map<Object?, Object?> row, List<String> keys) {
    final value = _stringValue(row, keys);
    return value == null ? null : DateTime.tryParse(value);
  }

  List<String> _listValue(Map<Object?, Object?> row, List<String> keys) {
    final value = _stringValue(row, keys);
    if (value == null) return const [];
    return value
        .split(RegExp(r'[;,|]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _stableHash(String input) {
    var hash = 0;
    for (final codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
