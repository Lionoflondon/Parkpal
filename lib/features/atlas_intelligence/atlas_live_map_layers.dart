import '../parkpal_atlas/parkpal_atlas_models.dart';

enum AtlasLiveMapLayer {
  parkingRestrictions,
  controlledZones,
  temporarySuspensions,
  roadworks,
  pioneerReports,
  verifiedEvidence,
  confidenceOverlay,
  dataFreshness,
  irisRecommendations,
}

enum AtlasLiveMapFilter {
  verified,
  needsReview,
  updatedToday,
  importFailures,
  conflicts,
}

class AtlasMapLayerState {
  const AtlasMapLayerState({
    this.enabledLayers = const {
      AtlasLiveMapLayer.parkingRestrictions,
      AtlasLiveMapLayer.controlledZones,
      AtlasLiveMapLayer.verifiedEvidence,
      AtlasLiveMapLayer.confidenceOverlay,
      AtlasLiveMapLayer.dataFreshness,
      AtlasLiveMapLayer.irisRecommendations,
    },
    this.activeFilters = const {},
  });

  final Set<AtlasLiveMapLayer> enabledLayers;
  final Set<AtlasLiveMapFilter> activeFilters;

  AtlasMapLayerState toggleLayer(AtlasLiveMapLayer layer) {
    final next = {...enabledLayers};
    next.contains(layer) ? next.remove(layer) : next.add(layer);
    return AtlasMapLayerState(
      enabledLayers: next,
      activeFilters: activeFilters,
    );
  }

  AtlasMapLayerState toggleFilter(AtlasLiveMapFilter filter) {
    final next = {...activeFilters};
    next.contains(filter) ? next.remove(filter) : next.add(filter);
    return AtlasMapLayerState(
      enabledLayers: enabledLayers,
      activeFilters: next,
    );
  }

  bool shows(ParkPalAtlasRoadProfile road, {DateTime? now}) {
    if (activeFilters.isEmpty) return true;
    final today = now ?? DateTime.now();
    return activeFilters.every((filter) {
      return switch (filter) {
        AtlasLiveMapFilter.verified => road.status == AtlasRoadStatus.verified,
        AtlasLiveMapFilter.needsReview =>
          road.status == AtlasRoadStatus.awaiting_verification ||
              road.status == AtlasRoadStatus.needs_refresh ||
              road.status == AtlasRoadStatus.partially_mapped,
        AtlasLiveMapFilter.updatedToday =>
          _sameDay(road.updatedAt ?? road.lastCouncilSyncAt, today),
        AtlasLiveMapFilter.importFailures =>
          road.status == AtlasRoadStatus.needs_refresh && road.pciScore < 50,
        AtlasLiveMapFilter.conflicts =>
          road.status == AtlasRoadStatus.conflict || road.conflicts > 0,
      };
    });
  }

  List<ParkPalAtlasRoadProfile> visibleRoads(
    Iterable<ParkPalAtlasRoadProfile> roads, {
    DateTime? now,
  }) {
    return roads.where((road) => shows(road, now: now)).toList(growable: false);
  }

  static bool _sameDay(DateTime? value, DateTime today) {
    if (value == null) return false;
    return value.year == today.year &&
        value.month == today.month &&
        value.day == today.day;
  }
}

class IrisMapRecommendation {
  const IrisMapRecommendation({
    required this.roadId,
    required this.roadName,
    required this.reason,
    required this.priority,
  });

  final String roadId;
  final String roadName;
  final String reason;
  final int priority;
}

class AtlasLiveMapIntelligence {
  const AtlasLiveMapIntelligence();

  List<IrisMapRecommendation> recommendationsFor(
    Iterable<ParkPalAtlasRoadProfile> roads,
  ) {
    final recommendations = <IrisMapRecommendation>[];
    for (final road in roads) {
      final priority = _priority(road);
      if (priority == 0) continue;
      recommendations.add(IrisMapRecommendation(
        roadId: road.roadId,
        roadName: road.roadName,
        reason: _reason(road),
        priority: priority,
      ));
    }
    recommendations.sort((a, b) => b.priority.compareTo(a.priority));
    return recommendations;
  }

  int _priority(ParkPalAtlasRoadProfile road) {
    var priority = 0;
    if (road.status == AtlasRoadStatus.unmapped) priority += 5;
    if (road.status == AtlasRoadStatus.conflict || road.conflicts > 0) {
      priority += 7;
    }
    if (road.status == AtlasRoadStatus.needs_refresh || road.staleRecords > 0) {
      priority += 3;
    }
    if (road.verifiedSigns == 0 || road.coveragePercent < 50) priority += 2;
    if (road.pciScore < 60) priority += 1;
    return priority.clamp(0, 10);
  }

  String _reason(ParkPalAtlasRoadProfile road) {
    if (road.status == AtlasRoadStatus.conflict || road.conflicts > 0) {
      return 'Resolve conflicting Atlas evidence before confident answers.';
    }
    if (road.status == AtlasRoadStatus.unmapped) {
      return 'No verified parking intelligence is available for this road.';
    }
    if (road.status == AtlasRoadStatus.needs_refresh || road.staleRecords > 0) {
      return 'Refresh stale official or field evidence.';
    }
    if (road.verifiedSigns == 0) {
      return 'Add verified sign evidence to improve confidence.';
    }
    return 'Improve road confidence and coverage.';
  }
}
