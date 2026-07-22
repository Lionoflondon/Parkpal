import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/parkpal_platform_routes.dart';
import '../../app/parkpal_theme.dart';
import '../history/parking_history_entry.dart';
import '../history/parking_history_service.dart';
import '../parkpal_atlas/parkpal_atlas_models.dart';
import '../parkpal_atlas/parkpal_atlas_service.dart';

class CustomerDashboardScreen extends StatefulWidget {
  const CustomerDashboardScreen({
    required this.onNavigate,
    this.historyService,
    this.atlasService,
    this.auth,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ParkingHistoryService? historyService;
  final ParkPalAtlasService? atlasService;
  final FirebaseAuth? auth;

  @override
  State<CustomerDashboardScreen> createState() =>
      _CustomerDashboardScreenState();
}

class _CustomerDashboardScreenState extends State<CustomerDashboardScreen> {
  late Future<_DashboardData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_DashboardData> _load() async {
    final historyService = widget.historyService ?? ParkingHistoryService();
    final atlasService = widget.atlasService ?? ParkPalAtlasService();
    final results = await Future.wait<Object>([
      historyService.fetchRecent(limit: 5),
      atlasService.fetchNationalSummary(),
      atlasService.fetchRoadsNeedingReview(limit: 3),
    ]);
    return _DashboardData(
      history: results[0] as List<ParkingHistoryEntry>,
      atlas: results[1] as AtlasSummary,
      roadsNeedingReview: results[2] as List<ParkPalAtlasRoadProfile>,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _safeUser();
    final firstName = _displayName(user);

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _data = _load());
        await _data;
      },
      child: FutureBuilder<_DashboardData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _DashboardData.empty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 128),
            children: [
              _DashboardHero(
                firstName: firstName,
                isLoading: snapshot.connectionState == ConnectionState.waiting,
                onFindParking: () =>
                    widget.onNavigate(ParkPalPlatformRoutes.find),
              ),
              const SizedBox(height: 18),
              _MetricGrid(data: data),
              const SizedBox(height: 18),
              _QuickActions(onNavigate: widget.onNavigate),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 780;
                  final recent = _RecentChecksCard(
                    history: data.history,
                    onNavigate: widget.onNavigate,
                  );
                  final atlas = _AtlasReadinessCard(
                    summary: data.atlas,
                    roads: data.roadsNeedingReview,
                    onNavigate: widget.onNavigate,
                  );
                  if (!wide) {
                    return Column(
                        children: [recent, const SizedBox(height: 18), atlas]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: recent),
                      const SizedBox(width: 18),
                      Expanded(child: atlas),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    final email = user?.email;
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'there';
  }

  User? _safeUser() {
    try {
      return (widget.auth ?? FirebaseAuth.instance).currentUser;
    } catch (_) {
      return null;
    }
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.firstName,
    required this.isLoading,
    required this.onFindParking,
  });

  final String firstName;
  final bool isLoading;
  final VoidCallback onFindParking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: parkPalGlassDecoration(opacity: 0.95, radius: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IrisBadge(isLoading: isLoading),
              const Spacer(),
              Text(
                'myparkpal.co.uk',
                style: ParkPalText.mono(
                  color: ParkPalColors.mutedTwo,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Good to see you, $firstName.',
            style: ParkPalText.display(
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your ParkPal dashboard brings together parking checks, evidence records and clear parking guidance without leaving the customer platform.',
            style: ParkPalText.body(
              color: ParkPalColors.muted,
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onFindParking,
            icon: const Icon(Icons.search_rounded),
            label: const Text('Can I park here?'),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.data});

  final _DashboardData data;

  @override
  Widget build(BuildContext context) {
    final checks = data.history.length;
    final evidenceRecords =
        data.history.where((entry) => entry.sourceUsed != 'none').length;
    final confidence = _confidenceLabel(data);
    final alerts = _customerAlertCount(data);
    final cards = [
      _MetricCard(
        label: 'Parking checks',
        value: '$checks',
        icon: Icons.fact_check_rounded,
        tone: ParkPalColors.green700,
      ),
      _MetricCard(
        label: 'Evidence records',
        value: '$evidenceRecords',
        icon: Icons.folder_copy_rounded,
        tone: ParkPalColors.irisBlue,
      ),
      _MetricCard(
        label: 'Parking confidence',
        value: confidence,
        icon: Icons.verified_user_rounded,
        tone: ParkPalColors.safeGreen,
      ),
      _MetricCard(
        label: 'Live alerts',
        value: '$alerts',
        icon: Icons.notifications_active_rounded,
        tone: alerts == 0 ? ParkPalColors.safeGreen : ParkPalColors.amber,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        return GridView.count(
          crossAxisCount: wide ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: wide ? 1.25 : 1.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }

  String _confidenceLabel(_DashboardData data) {
    final road =
        data.roadsNeedingReview.isEmpty ? null : data.roadsNeedingReview.first;
    if (road == null) return 'Ready';
    if (road.status == AtlasRoadStatus.verified && road.verifiedSigns > 0) {
      return 'High';
    }
    if (road.status == AtlasRoadStatus.conflict ||
        road.status == AtlasRoadStatus.needs_refresh ||
        road.status == AtlasRoadStatus.awaiting_verification) {
      return 'Medium';
    }
    return 'Low';
  }

  int _customerAlertCount(_DashboardData data) {
    return data.roadsNeedingReview
        .where((road) =>
            road.status == AtlasRoadStatus.conflict ||
            road.status == AtlasRoadStatus.needs_refresh)
        .length;
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onNavigate});

  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Find Parking', Icons.search_rounded, ParkPalPlatformRoutes.find),
      ('Live Map', Icons.map_rounded, ParkPalPlatformRoutes.map),
      (
        'IRIS Assistant',
        Icons.auto_awesome_rounded,
        ParkPalPlatformRoutes.iris
      ),
      ('Reports', Icons.flag_rounded, ParkPalPlatformRoutes.reports),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.9, radius: 28),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final action in actions)
            OutlinedButton.icon(
              onPressed: () => onNavigate(action.$3),
              icon: Icon(action.$2),
              label: Text(action.$1),
            ),
        ],
      ),
    );
  }
}

class _RecentChecksCard extends StatelessWidget {
  const _RecentChecksCard({
    required this.history,
    required this.onNavigate,
  });

  final List<ParkingHistoryEntry> history;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Recent checks',
      actionLabel: 'Find parking',
      onAction: () => onNavigate(ParkPalPlatformRoutes.find),
      child: history.isEmpty
          ? const _EmptyState(
              icon: Icons.search_rounded,
              title: 'No parking checks yet',
              body: 'Search a road to start building your Evidence Vault.',
            )
          : Column(
              children: [
                for (final entry in history) _HistoryRow(entry: entry),
              ],
            ),
    );
  }
}

class _AtlasReadinessCard extends StatelessWidget {
  const _AtlasReadinessCard({
    required this.summary,
    required this.roads,
    required this.onNavigate,
  });

  final AtlasSummary summary;
  final List<ParkPalAtlasRoadProfile> roads;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Atlas Intelligence',
      actionLabel: 'Open map',
      onAction: () => onNavigate(ParkPalPlatformRoutes.map),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ConfidenceExplainer(roads: roads),
          const SizedBox(height: 16),
          Text(
            _atlasCopy(summary),
            style: ParkPalText.body(color: ParkPalColors.muted, height: 1.45),
          ),
          if (roads.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Useful nearby alerts',
              style: ParkPalText.body(
                color: ParkPalColors.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final road in roads)
              Text(
                '• ${_customerRoadCopy(road)}',
                style: ParkPalText.body(color: ParkPalColors.muted),
              ),
          ],
        ],
      ),
    );
  }

  String _atlasCopy(AtlasSummary summary) {
    if (summary.totalKnownRoads == 0) {
      return 'Atlas is ready to explain parking decisions as verified signs, council information and community evidence become available.';
    }
    if (summary.conflicts > 0) {
      return 'Some nearby information needs extra care. ParkPal will tell you when confidence is limited.';
    }
    if (summary.staleRecords > 0) {
      return 'Some parking information may have changed recently. Always check the sign in front of you.';
    }
    return 'Atlas combines council information, verified signs and community confirmations to explain parking rules clearly.';
  }

  String _customerRoadCopy(ParkPalAtlasRoadProfile road) {
    return switch (road.status) {
      AtlasRoadStatus.conflict =>
        '${road.roadName}: check signs carefully before parking.',
      AtlasRoadStatus.needs_refresh =>
        '${road.roadName}: rules may have changed recently.',
      AtlasRoadStatus.awaiting_verification =>
        '${road.roadName}: evidence is being confirmed.',
      AtlasRoadStatus.unmapped =>
        '${road.roadName}: ParkPal has limited information.',
      AtlasRoadStatus.verified =>
        '${road.roadName}: parking information is verified.',
      AtlasRoadStatus.partially_mapped =>
        '${road.roadName}: some restrictions are known.',
    };
  }
}

class _ConfidenceExplainer extends StatelessWidget {
  const _ConfidenceExplainer({required this.roads});

  final List<ParkPalAtlasRoadProfile> roads;

  @override
  Widget build(BuildContext context) {
    final road = roads.isEmpty ? null : roads.first;
    final confidence = _confidence(road);
    final color = switch (confidence) {
      'High' => ParkPalColors.safeGreen,
      'Medium' => ParkPalColors.amber,
      _ => ParkPalColors.mutedTwo,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parking Confidence: $confidence',
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _why(road),
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _confidence(ParkPalAtlasRoadProfile? road) {
    if (road == null) return 'Low';
    if (road.status == AtlasRoadStatus.verified && road.verifiedSigns > 0) {
      return 'High';
    }
    if (road.status == AtlasRoadStatus.conflict ||
        road.status == AtlasRoadStatus.needs_refresh ||
        road.status == AtlasRoadStatus.awaiting_verification) {
      return 'Medium';
    }
    return 'Low';
  }

  String _why(ParkPalAtlasRoadProfile? road) {
    if (road == null) {
      return 'Search or select a road to see why ParkPal is confident.';
    }
    if (road.status == AtlasRoadStatus.verified && road.verifiedSigns > 0) {
      return "We're highly confident because this area has verified sign evidence and council information.";
    }
    if (road.status == AtlasRoadStatus.conflict) {
      return 'Confidence is limited because recent evidence does not fully agree. Check nearby signs before parking.';
    }
    if (road.status == AtlasRoadStatus.needs_refresh) {
      return 'Confidence is medium because rules may have changed recently.';
    }
    return 'Confidence is limited until ParkPal has more verified evidence for this road.';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: tone, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: ParkPalText.display(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: ParkPalColors.ink,
                ),
              ),
              Text(
                label,
                style: ParkPalText.body(
                  color: ParkPalColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: ParkPalText.display(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: ParkPalColors.ink,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final ParkingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = parkPalStatusColor(entry.resultStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.queryText,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  entry.ruleSummary.isEmpty
                      ? entry.resultStatus
                      : entry.ruleSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(entry.confidence * 100).round().clamp(0, 100)}%',
            style: ParkPalText.mono(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ParkPalColors.mint50,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(body, style: ParkPalText.body(color: ParkPalColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IrisBadge extends StatelessWidget {
  const _IrisBadge({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: parkPalIridescentBorderGradient(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isLoading ? 'SYNCING' : 'POWERED BY IRIS',
        style: ParkPalText.mono(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.history,
    required this.atlas,
    required this.roadsNeedingReview,
  });

  final List<ParkingHistoryEntry> history;
  final AtlasSummary atlas;
  final List<ParkPalAtlasRoadProfile> roadsNeedingReview;

  static const empty = _DashboardData(
    history: [],
    atlas: AtlasSummary(
      totalKnownRoads: 0,
      verifiedRoads: 0,
      unmappedRoads: 0,
      conflicts: 0,
      staleRecords: 0,
      activeMissions: 0,
      coveragePercent: 0,
      pciScore: 0,
    ),
    roadsNeedingReview: [],
  );
}
