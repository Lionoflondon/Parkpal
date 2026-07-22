import 'package:flutter/material.dart';

import '../../app/parkpal_platform_routes.dart';
import '../../app/parkpal_theme.dart';
import '../parkpal_atlas/parkpal_atlas_models.dart';
import '../parkpal_atlas/parkpal_atlas_service.dart';

class CustomerAtlasScreen extends StatefulWidget {
  const CustomerAtlasScreen({
    required this.onNavigate,
    this.atlasService,
    super.key,
  });

  final ValueChanged<String> onNavigate;
  final ParkPalAtlasService? atlasService;

  @override
  State<CustomerAtlasScreen> createState() => _CustomerAtlasScreenState();
}

class _CustomerAtlasScreenState extends State<CustomerAtlasScreen> {
  late Future<_CustomerMapData> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<_CustomerMapData> _load() async {
    final atlasService = widget.atlasService ?? ParkPalAtlasService();
    final results = await Future.wait<Object>([
      atlasService.fetchNationalSummary(),
      atlasService.fetchRoadsNeedingReview(limit: 8),
    ]);
    return _CustomerMapData(
      summary: results[0] as AtlasSummary,
      roads: results[1] as List<ParkPalAtlasRoadProfile>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _data = _load());
        await _data;
      },
      child: FutureBuilder<_CustomerMapData>(
        future: _data,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _CustomerMapData.empty;
          final road = data.primaryRoad;
          return ListView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 128),
            children: [
              _MapHero(
                confidence: data.confidenceLabel,
                onFind: () => widget.onNavigate(ParkPalPlatformRoutes.find),
              ),
              const SizedBox(height: 18),
              _LiveMapPanel(data: data),
              const SizedBox(height: 18),
              _ParkingDecisionSheet(
                road: road,
                confidence: data.confidenceLabel,
                onReport: () =>
                    widget.onNavigate(ParkPalPlatformRoutes.reports),
                onAskIris: () => widget.onNavigate(ParkPalPlatformRoutes.iris),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 820;
                  final evidence = _EvidenceCard(road: road);
                  final area = _AreaSummaryCard(data: data);
                  if (!wide) {
                    return Column(
                      children: [evidence, const SizedBox(height: 18), area],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: evidence),
                      const SizedBox(width: 18),
                      Expanded(child: area),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              _LiveAlertsCard(data: data),
            ],
          );
        },
      ),
    );
  }
}

class _MapHero extends StatelessWidget {
  const _MapHero({
    required this.confidence,
    required this.onFind,
  });

  final String confidence;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ParkPalColors.green900,
            ParkPalColors.navy,
            ParkPalColors.irisBlue.withValues(alpha: 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(38),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
            blurRadius: 34,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATLAS INTELLIGENCE',
            style: ParkPalText.mono(
              color: ParkPalColors.irisCyan,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Live Map',
            style: ParkPalText.display(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Understand parking rules, confidence and evidence before you leave your vehicle.',
            style: ParkPalText.body(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroPill(Icons.verified_user_rounded, 'Confidence $confidence'),
              const _HeroPill(Icons.traffic_rounded, 'Verified signs'),
              const _HeroPill(Icons.account_balance_rounded, 'Council info'),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onFind,
            icon: const Icon(Icons.travel_explore_rounded),
            label: const Text('Check a road'),
          ),
        ],
      ),
    );
  }
}

class _LiveMapPanel extends StatelessWidget {
  const _LiveMapPanel({required this.data});

  final _CustomerMapData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: parkPalGlassDecoration(opacity: 0.94, radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parking intelligence map',
            style: ParkPalText.display(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap a road to see whether parking appears allowed, what restrictions apply, and how confident ParkPal is.',
            style: ParkPalText.body(color: ParkPalColors.muted, height: 1.45),
          ),
          const SizedBox(height: 22),
          Stack(
            children: [
              Container(
                height: 330,
                decoration: BoxDecoration(
                  color: ParkPalColors.midnight,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: CustomPaint(
                  painter: _CustomerMapPainter(data: data),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: 18,
                top: 18,
                child: _MapFloatingChip(
                  icon: Icons.my_location_rounded,
                  label: 'Current area',
                  value: data.areaName,
                ),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: _MapLegend(confidence: data.confidenceLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ParkingDecisionSheet extends StatelessWidget {
  const _ParkingDecisionSheet({
    required this.road,
    required this.confidence,
    required this.onReport,
    required this.onAskIris,
  });

  final ParkPalAtlasRoadProfile? road;
  final String confidence;
  final VoidCallback onReport;
  final VoidCallback onAskIris;

  @override
  Widget build(BuildContext context) {
    final name = road?.roadName ?? 'Select a road';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: parkPalGlassDecoration(opacity: 0.96, radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: ParkPalColors.green700,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.local_parking_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parking here', style: ParkPalText.mono(fontSize: 11)),
                    Text(
                      name,
                      style: ParkPalText.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: ParkPalColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _ConfidenceBadge(confidence),
            ],
          ),
          const SizedBox(height: 18),
          _DecisionRow(
            icon: Icons.traffic_rounded,
            label: 'Restrictions',
            value: _restrictionCopy(road),
          ),
          _DecisionRow(
            icon: Icons.schedule_rounded,
            label: 'Time limits',
            value: _timeLimitCopy(road),
          ),
          _DecisionRow(
            icon: Icons.badge_rounded,
            label: 'Permit requirements',
            value: _permitCopy(road),
          ),
          _DecisionRow(
            icon: Icons.payments_rounded,
            label: 'Payment requirements',
            value: _paymentCopy(road),
          ),
          _DecisionRow(
            icon: Icons.near_me_rounded,
            label: 'Nearby parking',
            value: 'Use IRIS to compare nearby roads before leaving.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAskIris,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Ask IRIS'),
              ),
              OutlinedButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.report_problem_rounded),
                label: const Text('Report issue'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _restrictionCopy(ParkPalAtlasRoadProfile? road) {
    if (road == null) return 'Choose a road to see restriction details.';
    return switch (road.status) {
      AtlasRoadStatus.verified =>
        'Parking information is verified for this road.',
      AtlasRoadStatus.conflict =>
        'Some evidence disagrees. Check the sign before parking.',
      AtlasRoadStatus.needs_refresh =>
        'Rules may have changed recently. Check the sign before parking.',
      AtlasRoadStatus.awaiting_verification =>
        'ParkPal has partial evidence and is waiting for confirmation.',
      AtlasRoadStatus.partially_mapped =>
        'Some parking rules are known, but ParkPal needs more evidence here.',
      AtlasRoadStatus.unmapped =>
        'ParkPal does not yet have reliable parking data here.',
    };
  }

  String _timeLimitCopy(ParkPalAtlasRoadProfile? road) {
    if (road == null) return 'Time limits appear after a road is selected.';
    return road.verifiedSigns > 0
        ? 'Check the selected rule card for active hours and maximum stay.'
        : 'No verified time limit is available yet.';
  }

  String _permitCopy(ParkPalAtlasRoadProfile? road) {
    if (road == null) return 'Permit details appear after a road is selected.';
    return road.councilRecords > 0
        ? 'Permit or resident-zone rules may apply. Confirm with the sign.'
        : 'No permit requirement has been confirmed yet.';
  }

  String _paymentCopy(ParkPalAtlasRoadProfile? road) {
    if (road == null) return 'Payment details appear after a road is selected.';
    return road.councilRecords > 0
        ? 'Payment rules depend on the marked bay and time of day.'
        : 'No payment requirement has been confirmed yet.';
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.road});

  final ParkPalAtlasRoadProfile? road;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Evidence',
      child: Column(
        children: [
          _EvidenceRow(
            icon: Icons.traffic_rounded,
            label: 'Verified signs',
            value: '${road?.verifiedSigns ?? 0}',
          ),
          _EvidenceRow(
            icon: Icons.photo_camera_rounded,
            label: 'Recent photos',
            value: road?.fieldVerifiedRecords == null
                ? 'None yet'
                : '${road!.fieldVerifiedRecords}',
          ),
          _EvidenceRow(
            icon: Icons.how_to_reg_rounded,
            label: 'Community confirmations',
            value: road?.fieldVerifiedRecords == null
                ? 'None yet'
                : '${road!.fieldVerifiedRecords}',
          ),
          _EvidenceRow(
            icon: Icons.account_balance_rounded,
            label: 'Council information',
            value: road?.councilRecords == null ? 'Not available' : 'Available',
          ),
          _EvidenceRow(
            icon: Icons.verified_rounded,
            label: 'Last verified',
            value: _dateLabel(road?.lastFieldVerificationAt),
          ),
        ],
      ),
    );
  }
}

class _AreaSummaryCard extends StatelessWidget {
  const _AreaSummaryCard({required this.data});

  final _CustomerMapData data;

  @override
  Widget build(BuildContext context) {
    final road = data.primaryRoad;
    return _Panel(
      title: 'Area summary',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _AreaChip(Icons.local_parking_rounded, 'Parking available',
              data.parkingAvailable),
          _AreaChip(Icons.badge_rounded, 'Permit restrictions',
              road?.councilRecords != null && road!.councilRecords > 0),
          _AreaChip(Icons.local_shipping_rounded, 'Loading bays',
              road?.totalParkingAssets != null && road!.totalParkingAssets > 1),
          _AreaChip(Icons.accessible_rounded, 'Disabled bays', false),
          _AreaChip(Icons.ev_station_rounded, 'Electric charging', false),
          _AreaChip(Icons.home_work_rounded, 'Resident zones',
              road?.councilRecords != null && road!.councilRecords > 0),
          _AreaChip(Icons.schedule_rounded, 'Time restrictions',
              road?.verifiedSigns != null && road!.verifiedSigns > 0),
          _AreaChip(Icons.near_me_rounded, 'Nearby alternatives', true),
        ],
      ),
    );
  }
}

class _LiveAlertsCard extends StatelessWidget {
  const _LiveAlertsCard({required this.data});

  final _CustomerMapData data;

  @override
  Widget build(BuildContext context) {
    final alerts = data.customerAlerts;
    return _Panel(
      title: 'Live alerts',
      child: alerts.isEmpty
          ? const _EmptyMessage(
              icon: Icons.notifications_none_rounded,
              title: 'No live parking alerts nearby',
              body:
                  'Temporary suspensions, road closures and newly verified signs will appear here when relevant.',
            )
          : Column(
              children: [
                for (final alert in alerts)
                  _AlertRow(icon: alert.icon, text: alert.text),
              ],
            ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: parkPalGlassDecoration(opacity: 0.92, radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: ParkPalText.display(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: ParkPalColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
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
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.irisBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: ParkPalText.body(
                color: ParkPalColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(value, style: ParkPalText.body(color: ParkPalColors.muted)),
        ],
      ),
    );
  }
}

class _AreaChip extends StatelessWidget {
  const _AreaChip(this.icon, this.label, this.available);

  final IconData icon;
  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? ParkPalColors.safeGreen : ParkPalColors.mutedTwo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: available ? ParkPalColors.greenBg : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: ParkPalText.body(
              color: ParkPalColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParkPalColors.amberBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ParkPalColors.amberLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: ParkPalText.body(
                color: ParkPalColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        children: [
          Icon(icon, color: ParkPalColors.irisBlue),
          const SizedBox(width: 12),
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
                Text(
                  body,
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
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Text(
            label,
            style: ParkPalText.mono(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge(this.confidence);

  final String confidence;

  @override
  Widget build(BuildContext context) {
    final color = switch (confidence) {
      'High' => ParkPalColors.safeGreen,
      'Medium' => ParkPalColors.amber,
      _ => ParkPalColors.mutedTwo,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        confidence,
        style: ParkPalText.mono(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _MapFloatingChip extends StatelessWidget {
  const _MapFloatingChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ParkPalColors.green700),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: ParkPalText.mono(fontSize: 10)),
              Text(value, style: ParkPalText.body(fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.confidence});

  final String confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegendDot('Parking known', ParkPalColors.safeGreen),
          _LegendDot('Check restrictions', ParkPalColors.amber),
          _LegendDot('Limited confidence', ParkPalColors.mutedTwo),
          const SizedBox(height: 5),
          Text(
            'Confidence: $confidence',
            style: ParkPalText.mono(
              color: ParkPalColors.ink,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: ParkPalText.body(fontSize: 12)),
        ],
      ),
    );
  }
}

class _CustomerMapPainter extends CustomPainter {
  const _CustomerMapPainter({required this.data});

  final _CustomerMapData data;

  @override
  void paint(Canvas canvas, Size size) {
    final asphalt = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF111827);
    final roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.18);
    final activeRoad = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = _confidenceColor(data.confidenceLabel).withValues(alpha: 0.86);
    final bayPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = ParkPalColors.irisCyan.withValues(alpha: 0.74);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(30),
      ),
      asphalt,
    );

    for (final y in [0.24, 0.42, 0.61, 0.78]) {
      canvas.drawLine(
        Offset(size.width * 0.09, size.height * y),
        Offset(size.width * 0.91, size.height * (y + 0.04)),
        roadPaint,
      );
    }
    canvas.drawLine(
      Offset(size.width * 0.18, size.height * 0.12),
      Offset(size.width * 0.74, size.height * 0.86),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.12, size.height * 0.56),
      Offset(size.width * 0.86, size.height * 0.38),
      activeRoad,
    );

    for (var i = 0; i < 5; i++) {
      final left = size.width * (0.19 + i * 0.11);
      final top = size.height * (0.49 - i * 0.025);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, 34, 18),
          const Radius.circular(6),
        ),
        bayPaint,
      );
    }

    final pin = Paint()
      ..style = PaintingStyle.fill
      ..color = ParkPalColors.safeGreen;
    final center = Offset(size.width * 0.56, size.height * 0.44);
    canvas.drawCircle(center, 15, pin);
    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  }

  Color _confidenceColor(String confidence) {
    return switch (confidence) {
      'High' => ParkPalColors.safeGreen,
      'Medium' => ParkPalColors.amber,
      _ => ParkPalColors.mutedTwo,
    };
  }

  @override
  bool shouldRepaint(covariant _CustomerMapPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

class _CustomerAlert {
  const _CustomerAlert(this.icon, this.text);

  final IconData icon;
  final String text;
}

class _CustomerMapData {
  const _CustomerMapData({
    required this.summary,
    required this.roads,
  });

  final AtlasSummary summary;
  final List<ParkPalAtlasRoadProfile> roads;

  ParkPalAtlasRoadProfile? get primaryRoad {
    if (roads.isEmpty) return null;
    return roads.first;
  }

  String get areaName {
    final road = primaryRoad;
    if (road == null) return 'Nearby roads';
    return road.borough.isNotEmpty ? road.borough : road.council;
  }

  String get confidenceLabel {
    final road = primaryRoad;
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

  bool get parkingAvailable {
    final road = primaryRoad;
    if (road == null) return false;
    return road.status == AtlasRoadStatus.verified ||
        road.status == AtlasRoadStatus.partially_mapped;
  }

  List<_CustomerAlert> get customerAlerts {
    final road = primaryRoad;
    if (road == null) return const [];
    final alerts = <_CustomerAlert>[];
    if (road.status == AtlasRoadStatus.needs_refresh) {
      alerts.add(const _CustomerAlert(
        Icons.refresh_rounded,
        'Rules here may have changed recently. Check the sign before parking.',
      ));
    }
    if (road.status == AtlasRoadStatus.conflict) {
      alerts.add(const _CustomerAlert(
        Icons.report_problem_rounded,
        'Reported information disagrees for this road. Treat guidance as limited.',
      ));
    }
    if (road.lastFieldVerificationAt != null) {
      alerts.add(const _CustomerAlert(
        Icons.verified_rounded,
        'A parking sign has been recently verified nearby.',
      ));
    }
    return alerts;
  }

  static const empty = _CustomerMapData(
    summary: AtlasSummary(
      totalKnownRoads: 0,
      verifiedRoads: 0,
      unmappedRoads: 0,
      conflicts: 0,
      staleRecords: 0,
      activeMissions: 0,
      coveragePercent: 0,
      pciScore: 0,
    ),
    roads: [],
  );
}

String _dateLabel(DateTime? value) {
  if (value == null) return 'Not yet';
  final now = DateTime.now();
  final age = now.difference(value);
  if (age.inDays == 0) return 'Today';
  if (age.inDays == 1) return 'Yesterday';
  if (age.inDays < 30) return '${age.inDays} days ago';
  return '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';
}
