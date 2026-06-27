typedef JsonMap = Map<String, Object?>;

JsonMap compact(JsonMap json) {
  return Map.fromEntries(json.entries.where((entry) => entry.value != null));
}

List<String> stringList(Object? value) {
  if (value is Iterable) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}

List<T> enumList<T extends Enum>(
  Object? value,
  List<T> values,
) {
  if (value is! Iterable) return const [];

  return value
      .whereType<String>()
      .map((item) => values.byNameOrNull(item))
      .whereType<T>()
      .toList(growable: false);
}

extension EnumByNameOrNull<T extends Enum> on List<T> {
  T? byNameOrNull(String name) {
    for (final value in this) {
      if (value.name == name) return value;
    }
    return null;
  }
}

class ParkPalGeoPoint {
  const ParkPalGeoPoint({
    required this.latitude,
    required this.longitude,
  });

  factory ParkPalGeoPoint.fromJson(Object? value) {
    if (value is Map) {
      return ParkPalGeoPoint(
        latitude: (value['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (value['longitude'] as num?)?.toDouble() ?? 0,
      );
    }
    return const ParkPalGeoPoint(latitude: 0, longitude: 0);
  }

  final double latitude;
  final double longitude;

  JsonMap toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class ParkPalGeoBounds {
  const ParkPalGeoBounds({
    required this.northEast,
    required this.southWest,
  });

  factory ParkPalGeoBounds.fromJson(Object? value) {
    if (value is Map) {
      return ParkPalGeoBounds(
        northEast: ParkPalGeoPoint.fromJson(value['northEast']),
        southWest: ParkPalGeoPoint.fromJson(value['southWest']),
      );
    }
    return const ParkPalGeoBounds(
      northEast: ParkPalGeoPoint(latitude: 0, longitude: 0),
      southWest: ParkPalGeoPoint(latitude: 0, longitude: 0),
    );
  }

  final ParkPalGeoPoint northEast;
  final ParkPalGeoPoint southWest;

  JsonMap toJson() => {
        'northEast': northEast.toJson(),
        'southWest': southWest.toJson(),
      };
}
