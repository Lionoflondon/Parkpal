enum ParkPalConnectSourceType { csv, json, geojson, api }

class ParkPalConnectSource {
  const ParkPalConnectSource({
    required this.sourceId,
    required this.sourceName,
    required this.council,
    required this.borough,
    required this.sourceType,
    required this.sourceUrl,
    required this.licence,
    this.lastFetchedAt,
    this.enabled = true,
  });

  final String sourceId;
  final String sourceName;
  final String council;
  final String borough;
  final ParkPalConnectSourceType sourceType;
  final String sourceUrl;
  final String licence;
  final DateTime? lastFetchedAt;
  final bool enabled;

  Map<String, Object?> toJson() => {
        'sourceId': sourceId,
        'sourceName': sourceName,
        'council': council,
        'borough': borough,
        'sourceType': sourceType.name,
        'sourceUrl': sourceUrl,
        'licence': licence,
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
        'enabled': enabled,
      };
}
