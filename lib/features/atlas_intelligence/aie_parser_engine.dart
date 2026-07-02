import 'dart:convert';

import 'aie_models.dart';

class AieParserEngine {
  const AieParserEngine();

  List<AieStructuredRestriction> parse({
    required AieSource source,
    required String rawData,
  }) {
    if (rawData.trim().isEmpty) return const [];
    try {
      return switch (source.documentType) {
        AieDocumentType.csv => _parseCsv(source, rawData),
        AieDocumentType.json => _parseJson(source, rawData),
        AieDocumentType.geojson => _parseGeoJson(source, rawData),
        AieDocumentType.xml || AieDocumentType.rss => _parseText(
            source,
            _stripTags(rawData),
          ),
        AieDocumentType.html => _parseText(source, _stripTags(rawData)),
        AieDocumentType.pdf || AieDocumentType.docx => _parseText(
            source,
            rawData,
          ),
      };
    } catch (_) {
      return const [];
    }
  }

  List<AieStructuredRestriction> _parseJson(AieSource source, String rawData) {
    final decoded = jsonDecode(rawData);
    final rows = decoded is List
        ? decoded
        : decoded is Map && decoded['features'] is List
            ? decoded['features'] as List
            : decoded is Map && decoded['records'] is List
                ? decoded['records'] as List
                : decoded is Map && decoded['data'] is List
                    ? decoded['data'] as List
                    : const [];
    return rows
        .whereType<Map>()
        .map((row) => _fromMap(source, row.cast<String, Object?>()))
        .whereType<AieStructuredRestriction>()
        .toList(growable: false);
  }

  List<AieStructuredRestriction> _parseGeoJson(
    AieSource source,
    String rawData,
  ) {
    final decoded = jsonDecode(rawData);
    if (decoded is! Map || decoded['features'] is! List) return const [];
    return (decoded['features'] as List)
        .whereType<Map>()
        .map((feature) {
          final properties =
              (feature['properties'] as Map?)?.cast<String, Object?>() ??
                  const <String, Object?>{};
          final geometry = feature['geometry'];
          final coordinates = geometry is Map ? geometry['coordinates'] : null;
          return _fromMap(source, {
            ...properties,
            if (coordinates is List && coordinates.length >= 2) ...{
              'longitude': coordinates[0],
              'latitude': coordinates[1],
            },
          });
        })
        .whereType<AieStructuredRestriction>()
        .toList(growable: false);
  }

  List<AieStructuredRestriction> _parseCsv(AieSource source, String rawData) {
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
          return _fromMap(source, row);
        })
        .whereType<AieStructuredRestriction>()
        .toList(growable: false);
  }

  List<AieStructuredRestriction> _parseText(AieSource source, String rawData) {
    final text = rawData.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return const [];
    final sentences = text
        .split(RegExp(r'(?<=[.!?;])\s+'))
        .where((part) => _looksLikeRestriction(part))
        .toList(growable: false);

    return sentences.map((sentence) {
      final roadName = _roadFromText(sentence) ?? 'Unknown road';
      final hours = _hoursFromText(sentence);
      final days = _daysFromText(sentence);
      final type = _restrictionType(sentence);
      return AieStructuredRestriction(
        ruleId: _stableHash('${source.sourceId}|$roadName|$type|$hours|$days'),
        roadName: roadName,
        council: source.council,
        restrictionType: type,
        activeDays: days,
        activeHours: hours ?? 'Unknown',
        startTime: _splitTime(hours, 0),
        endTime: _splitTime(hours, 1),
        parkingAllowed: _parkingAllowed(type),
        loadingAllowed: _loadingAllowed(sentence),
        permitRequired: _containsAny(sentence, ['permit', 'resident']),
        redRoute: _containsAny(sentence, ['red route']),
        busLane: _containsAny(sentence, ['bus lane']),
        schoolStreet: _containsAny(sentence, ['school street']),
        temporaryRestriction:
            _containsAny(sentence, ['temporary', 'suspension']),
        sourceId: source.sourceId,
        sourceUrl: source.sourceUrl,
        sourceText: sentence,
        raw: {'legalText': sentence},
      );
    }).toList(growable: false);
  }

  AieStructuredRestriction? _fromMap(
    AieSource source,
    Map<String, Object?> row,
  ) {
    final roadName = _string(row,
        ['roadName', 'streetName', 'street', 'road', 'location', 'highway']);
    if (roadName == null || roadName.trim().isEmpty) return null;

    final restrictionText = _string(row, [
          'restriction',
          'restrictionType',
          'type',
          'description',
          'summary',
          'legalText'
        ]) ??
        '';
    final hours = _string(row, ['activeHours', 'hours', 'timeWindow']) ??
        _hoursFromText(restrictionText) ??
        'Unknown';
    final restrictionType = _restrictionType(
      _string(row, ['restrictionType', 'type']) ?? restrictionText,
    );
    final lat = _double(row, ['latitude', 'lat', 'y']);
    final lng = _double(row, ['longitude', 'lng', 'lon', 'x']);

    return AieStructuredRestriction(
      ruleId: _string(row, ['ruleId', 'id', 'recordId', 'externalId']) ??
          _stableHash('${source.sourceId}|$roadName|$restrictionType|$hours'),
      roadName: roadName,
      council: _string(row, ['council']) ?? source.council,
      borough: _string(row, ['borough']),
      postcodeArea: _string(row, ['postcode', 'postcodeArea', 'area']),
      latitude: lat,
      longitude: lng,
      restrictionType: restrictionType,
      activeDays: _list(row, ['activeDays', 'days']).isEmpty
          ? _daysFromText(restrictionText)
          : _list(row, ['activeDays', 'days']),
      activeHours: hours,
      startTime: _splitTime(hours, 0),
      endTime: _splitTime(hours, 1),
      maxStayMinutes: _int(row, ['maxStayMinutes', 'maxStay']),
      parkingAllowed: _bool(row, ['parkingAllowed', 'parking']) ??
          _parkingAllowed(restrictionType),
      loadingAllowed: _bool(row, ['loadingAllowed', 'loading']),
      permitRequired: _bool(row, ['permitRequired', 'permit']) ??
          _containsAny(restrictionText, ['permit', 'resident']),
      redRoute: _bool(row, ['redRoute']) ??
          _containsAny(restrictionText, ['red route']),
      busLane: _bool(row, ['busLane']) ??
          _containsAny(restrictionText, ['bus lane']),
      schoolStreet: _bool(row, ['schoolStreet']) ??
          _containsAny(restrictionText, ['school street']),
      temporaryRestriction: _bool(row, ['temporaryRestriction']) ??
          _containsAny(restrictionText, ['temporary', 'suspension']),
      sourceId: source.sourceId,
      sourceUrl: source.sourceUrl,
      sourceText: restrictionText,
      raw: row,
    );
  }

  bool _looksLikeRestriction(String value) {
    return _containsAny(value, [
      'parking',
      'waiting',
      'loading',
      'permit',
      'suspension',
      'red route',
      'school street',
      'bus lane',
      'cpz',
    ]);
  }

  String _restrictionType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('no waiting') ||
        lower.contains('waiting prohibited') ||
        lower.contains('waiting restriction')) {
      return 'No Waiting';
    }
    if (lower.contains('no loading') || lower.contains('loading prohibited')) {
      return 'No Loading';
    }
    if (lower.contains('permit')) return 'Permit Parking';
    if (lower.contains('red route')) return 'Red Route';
    if (lower.contains('bus lane')) return 'Bus Lane';
    if (lower.contains('school street')) return 'School Street';
    if (lower.contains('suspension')) return 'Temporary Suspension';
    if (lower.contains('disabled')) return 'Disabled Bay';
    if (lower.contains('electric') || lower.contains('ev')) return 'EV Bay';
    if (lower.contains('loading')) return 'Loading Restriction';
    return value.trim().isEmpty ? 'Parking Restriction' : value.trim();
  }

  List<String> _daysFromText(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('mon-sat') || lower.contains('monday-saturday')) {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }
    if (lower.contains('mon-fri') || lower.contains('monday-friday')) {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    }
    if (lower.contains('daily') || lower.contains('every day')) {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
    final days = <String>[];
    const lookup = {
      'monday': 'Mon',
      'mon': 'Mon',
      'tuesday': 'Tue',
      'tue': 'Tue',
      'wednesday': 'Wed',
      'wed': 'Wed',
      'thursday': 'Thu',
      'thu': 'Thu',
      'friday': 'Fri',
      'fri': 'Fri',
      'saturday': 'Sat',
      'sat': 'Sat',
      'sunday': 'Sun',
      'sun': 'Sun',
    };
    for (final entry in lookup.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(lower) &&
          !days.contains(entry.value)) {
        days.add(entry.value);
      }
    }
    return days;
  }

  String? _hoursFromText(String value) {
    final match = RegExp(
      r'(\d{1,2}[:.]\d{2}|\d{1,2}\s?(?:am|pm))\s*[-–]\s*(\d{1,2}[:.]\d{2}|\d{1,2}\s?(?:am|pm))',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    return '${_normaliseTime(match.group(1)!)}-${_normaliseTime(match.group(2)!)}';
  }

  String? _splitTime(String? hours, int index) {
    final parts = hours?.split(RegExp(r'[-–]'));
    if (parts == null || parts.length <= index) return null;
    return parts[index].trim();
  }

  String _normaliseTime(String value) {
    final trimmed =
        value.toLowerCase().replaceAll(' ', '').replaceAll('.', ':');
    final amPm = RegExp(r'^(\d{1,2})(?::(\d{2}))?(am|pm)$').firstMatch(trimmed);
    if (amPm != null) {
      var hour = int.parse(amPm.group(1)!);
      final minute = amPm.group(2) ?? '00';
      final suffix = amPm.group(3)!;
      if (suffix == 'pm' && hour < 12) hour += 12;
      if (suffix == 'am' && hour == 12) hour = 0;
      return '${hour.toString().padLeft(2, '0')}:$minute';
    }
    final parts = trimmed.split(':');
    if (parts.length == 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return trimmed;
  }

  String? _roadFromText(String value) {
    final match = RegExp(
      r"\b(?:on|at|for)\s+([A-Z][A-Za-z0-9 .'-]+?(?:Road|Street|Lane|Avenue|Way|Drive|Close|Place|Square|High Street))\b",
    ).firstMatch(value);
    return match?.group(1)?.trim();
  }

  bool? _parkingAllowed(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('no waiting') ||
        lower.contains('no parking') ||
        lower.contains('prohibited') ||
        lower.contains('suspension')) {
      return false;
    }
    if (lower.contains('permit') ||
        lower.contains('bay') ||
        lower.contains('parking')) {
      return true;
    }
    return null;
  }

  bool? _loadingAllowed(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('no loading') || lower.contains('loading prohibited')) {
      return false;
    }
    if (lower.contains('loading')) return true;
    return null;
  }

  String _stripTags(String value) {
    return value
        .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
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

  String? _string(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  double? _double(Map<String, Object?> row, List<String> keys) {
    final value = _string(row, keys);
    return value == null ? null : double.tryParse(value);
  }

  int? _int(Map<String, Object?> row, List<String> keys) {
    final value = _string(row, keys);
    return value == null ? null : int.tryParse(value);
  }

  bool? _bool(Map<String, Object?> row, List<String> keys) {
    final value = _string(row, keys)?.toLowerCase();
    if (value == null) return null;
    if (['true', 'yes', 'y', '1', 'allowed'].contains(value)) return true;
    if (['false', 'no', 'n', '0', 'prohibited'].contains(value)) return false;
    return null;
  }

  List<String> _list(Map<String, Object?> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is List) return value.map((item) => item.toString()).toList();
      if (value is String && value.trim().isNotEmpty) {
        return value
            .split(RegExp(r'[,|;/]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  bool _containsAny(String value, List<String> terms) {
    final lower = value.toLowerCase();
    return terms.any(lower.contains);
  }

  String _stableHash(String value) {
    var hash = 0;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash.toRadixString(16);
  }
}
