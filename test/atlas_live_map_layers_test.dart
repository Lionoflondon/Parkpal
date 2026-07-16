import 'package:flutter_test/flutter_test.dart';
import 'package:parkpal/features/atlas_intelligence/atlas_live_map_layers.dart';
import 'package:parkpal/features/parkpal_atlas/parkpal_atlas_models.dart';

void main() {
  group('AtlasMapLayerState', () {
    test('filters roads without changing route or UI state', () {
      final state =
          const AtlasMapLayerState().toggleFilter(AtlasLiveMapFilter.conflicts);

      final visible = state.visibleRoads([
        _road('verified', AtlasRoadStatus.verified),
        _road('conflict', AtlasRoadStatus.conflict, conflicts: 1),
      ]);

      expect(visible.map((road) => road.roadId), ['conflict']);
    });

    test('tracks updated today filter', () {
      final today = DateTime(2026, 7, 16, 12);
      final state = const AtlasMapLayerState()
          .toggleFilter(AtlasLiveMapFilter.updatedToday);

      final visible = state.visibleRoads([
        _road('old', AtlasRoadStatus.verified,
            updatedAt: today.subtract(const Duration(days: 1))),
        _road('today', AtlasRoadStatus.verified, updatedAt: today),
      ], now: today);

      expect(visible.map((road) => road.roadId), ['today']);
    });
  });

  group('AtlasLiveMapIntelligence', () {
    test('prioritises conflicts and unmapped roads for IRIS recommendations',
        () {
      const intelligence = AtlasLiveMapIntelligence();

      final recommendations = intelligence.recommendationsFor([
        _road('healthy', AtlasRoadStatus.verified, pciScore: 95),
        _road('unmapped', AtlasRoadStatus.unmapped, pciScore: 0),
        _road('conflict', AtlasRoadStatus.conflict, conflicts: 2, pciScore: 40),
      ]);

      expect(recommendations.first.roadId, 'conflict');
      expect(recommendations.map((item) => item.roadId), contains('unmapped'));
      expect(
        recommendations.first.reason,
        contains('conflicting Atlas evidence'),
      );
    });
  });
}

ParkPalAtlasRoadProfile _road(
  String id,
  AtlasRoadStatus status, {
  int conflicts = 0,
  int staleRecords = 0,
  int verifiedSigns = 1,
  double coveragePercent = 80,
  double pciScore = 80,
  DateTime? updatedAt,
}) {
  return ParkPalAtlasRoadProfile(
    roadId: id,
    roadName: 'Road $id',
    borough: 'Camden',
    council: 'Camden Council',
    city: 'London',
    country: 'UK',
    totalParkingAssets: 3,
    verifiedSigns: verifiedSigns,
    councilRecords: 1,
    fieldVerifiedRecords: 1,
    conflicts: conflicts,
    staleRecords: staleRecords,
    activeMissions: 0,
    coveragePercent: coveragePercent,
    pciScore: pciScore,
    status: status,
    updatedAt: updatedAt,
  );
}
