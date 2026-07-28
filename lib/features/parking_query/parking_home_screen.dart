import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/parkpal_theme.dart';
import '../history/parking_history_entry.dart';
import '../history/parking_history_service.dart';
import '../parking_intelligence/current_location_service.dart';
import 'parking_lookup_result.dart';
import 'parking_query_service.dart';
import 'parking_report_service.dart';

class ParkingHomeScreen extends StatefulWidget {
  const ParkingHomeScreen({this.onOpenScan, this.onOpenHistory, super.key});

  final VoidCallback? onOpenScan;
  final VoidCallback? onOpenHistory;

  @override
  State<ParkingHomeScreen> createState() => _ParkingHomeScreenState();
}

class _ParkingHomeScreenState extends State<ParkingHomeScreen> {
  final _controller = TextEditingController();
  final _service = ParkingQueryService();
  final _historyService = ParkingHistoryService();
  final _locationService = const ParkPalCurrentLocationService();

  ParkingLookupResult? _result;
  Future<List<ParkingHistoryEntry>>? _recentHistory;
  bool _isLoading = false;
  bool _isGpsLoading = false;
  String? _error;
  String? _gpsStatus;

  @override
  void initState() {
    super.initState();
    _recentHistory = _historyService.fetchRecent(limit: 3);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a road or location to check.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _result = result;
        _recentHistory = _historyService.fetchRecent(limit: 3);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'ParkPal could not complete this search. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchWithGps() async {
    setState(() {
      _isGpsLoading = true;
      _error = null;
      _gpsStatus = 'Getting your location…';
    });

    try {
      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (!location.isSuccess || location.fix == null) {
        setState(() {
          _gpsStatus = null;
          _error = location.customerMessage;
        });
        return;
      }

      final fix = location.fix!;
      setState(() {
        _gpsStatus =
            'GPS captured ${fix.compactLabel} • accuracy ${fix.accuracyMeters.round()}m';
      });
      final result = await _service.searchNearby(fix);
      if (!mounted) return;
      setState(() {
        _result = result;
        _recentHistory = _historyService.fetchRecent(limit: 3);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _gpsStatus = null;
        _error = 'ParkPal could not complete the GPS check. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _HomeBackdrop(),
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
          children: [
            const _ParkPalHeader(),
            const SizedBox(height: 28),
            _HeroPanel(
              controller: _controller,
              isLoading: _isLoading,
              isGpsLoading: _isGpsLoading,
              error: _error,
              gpsStatus: _gpsStatus,
              onSearch: _search,
              onGpsSearch: _searchWithGps,
              onOpenHistory: widget.onOpenHistory,
            ),
            const SizedBox(height: 18),
            _IrisScanCard(onTap: widget.onOpenScan),
            const SizedBox(height: 18),
            const _IntelligenceMapPreview(),
            if (_result != null) ...[
              const SizedBox(height: 18),
              ParkingResultCard(result: _result!),
            ],
            const SizedBox(height: 24),
            _RecentHistorySection(history: _recentHistory),
            const SizedBox(height: 24),
            const _TrustFooter(),
          ],
        ),
      ],
    );
  }
}

class ParkingResultCard extends StatelessWidget {
  const ParkingResultCard({required this.result, super.key});

  final ParkingLookupResult result;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusCopy(result.canPark);
    final statusColor = parkPalStatusColor(statusLabel);
    final confidence = (result.confidenceScore * 100).round().clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.78),
            statusColor.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: parkPalGlassDecoration(opacity: 0.96, radius: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PremiumIcon(
                  icon: _statusIcon(result.canPark),
                  color: statusColor,
                  background: parkPalStatusBg(statusLabel),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: ParkPalText.display(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: ParkPalColors.ink,
                        ),
                      ),
                      Text(
                        'Parking here',
                        style: ParkPalText.mono(
                          color: ParkPalColors.mutedTwo,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: result.riskLevel),
              ],
            ),
            const SizedBox(height: 18),
            _CustomerConfidencePanel(result: result, statusColor: statusColor),
            const SizedBox(height: 16),
            Text(
              result.ruleSummary,
              style: ParkPalText.body(
                color: ParkPalColors.ink,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _ResultMetricGrid(result: result),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'IRIS confidence',
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '$confidence%',
                  style: ParkPalText.mono(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: confidence / 100,
                minHeight: 9,
                color: statusColor,
                backgroundColor: ParkPalColors.lineSoft,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              result.evidenceReason,
              style: ParkPalText.body(
                color: ParkPalColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _SafetyNotice(result: result, color: statusColor),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReportIssueDialog(context),
                    icon: const Icon(Icons.report_problem_rounded),
                    label: const Text('Report issue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReportIssueDialog(BuildContext context) async {
    final controller = TextEditingController();
    var submitting = false;
    final messenger = ScaffoldMessenger.of(context);

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Report an issue'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell ParkPal what looks wrong. Reports are reviewed before changing parking intelligence.',
                    style: ParkPalText.body(
                      color: ParkPalColors.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    minLines: 3,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Example: the sign says permit holders only.',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          final ok = await ParkingReportService().submitIssue(
                            description: controller.text,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(ok);
                        },
                  child: submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();

    if (submitted == true) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
    } else if (submitted == null) {
      return;
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not submit report. Please try again.'),
        ),
      );
    }
  }

  IconData _statusIcon(CanParkStatus status) {
    return switch (status) {
      CanParkStatus.yes => Icons.check_rounded,
      CanParkStatus.no => Icons.close_rounded,
      CanParkStatus.unknown => Icons.priority_high_rounded,
    };
  }

  String _statusCopy(CanParkStatus status) {
    return switch (status) {
      CanParkStatus.yes => 'Safe to park',
      CanParkStatus.no => 'Do not park',
      CanParkStatus.unknown => 'Check restrictions',
    };
  }
}

class _CustomerConfidencePanel extends StatelessWidget {
  const _CustomerConfidencePanel({
    required this.result,
    required this.statusColor,
  });

  final ParkingLookupResult result;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parking confidence: ${result.confidenceLabel}',
                  style: ParkPalText.body(
                    color: ParkPalColors.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _confidenceCopy(result),
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
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

  String _confidenceCopy(ParkingLookupResult result) {
    if (result.canPark == CanParkStatus.unknown) {
      return 'We need verified street or council evidence before giving a clear answer.';
    }
    return 'This answer is based on ${result.evidenceSourceLabel.toLowerCase()} and the current ParkPal intelligence available for this location.';
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice({required this.result, required this.color});

  final ParkingLookupResult result;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ParkPalColors.cream.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_rounded, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.customerSafetyNote,
              style: ParkPalText.body(
                color: ParkPalColors.muted,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.controller,
    required this.isLoading,
    required this.isGpsLoading,
    required this.error,
    required this.gpsStatus,
    required this.onSearch,
    required this.onGpsSearch,
    required this.onOpenHistory,
  });

  final TextEditingController controller;
  final bool isLoading;
  final bool isGpsLoading;
  final String? error;
  final String? gpsStatus;
  final VoidCallback onSearch;
  final VoidCallback onGpsSearch;
  final VoidCallback? onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: parkPalGlassDecoration(opacity: 0.94, radius: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Certainty before\nyou walk away.',
            style: ParkPalText.display(
              fontSize: 43,
              fontWeight: FontWeight.w800,
              color: ParkPalColors.ink,
              height: 0.98,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Search a road and ParkPal checks verified signs, road rules, zones, council intelligence and trusted reports.',
            style: ParkPalText.body(
              color: ParkPalColors.muted,
              fontSize: 15,
              height: 1.48,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: ParkPalText.body(
              color: ParkPalColors.ink,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: 'Kensington Road',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                tooltip: 'Clear',
                onPressed: controller.clear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            onSubmitted: (_) => onSearch(),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            _InlineMessage(
              icon: Icons.error_rounded,
              color: ParkPalColors.red,
              text: error!,
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onSearch,
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.route_rounded),
              label: Text(isLoading ? 'Checking ParkPal…' : 'Can I park here?'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading || isGpsLoading ? null : onGpsSearch,
                  icon: isGpsLoading
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.near_me_rounded),
                  label: Text(isGpsLoading ? 'Locating…' : 'Use GPS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenHistory,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('Vault'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            gpsStatus ??
                'GPS uses your measured device location and only returns a clear answer when nearby ParkPal evidence exists.',
            style: ParkPalText.body(
              color: ParkPalColors.mutedTwo,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ParkPalHeader extends StatelessWidget {
  const _ParkPalHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _ParkPalLogoMark(),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ParkPal',
              style: ParkPalText.display(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: ParkPalColors.ink,
              ),
            ),
            Text(
              'Know before you park',
              style: ParkPalText.mono(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ParkPalColors.mutedTwo,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: ParkPalColors.midnight,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: ParkPalColors.irisBlue.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: ParkPalColors.irisCyan,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'IRIS',
                style: ParkPalText.mono(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParkPalLogoMark extends StatelessWidget {
  const _ParkPalLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: ParkPalColors.midnight,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: ParkPalColors.irisBlue.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) =>
              parkPalIridescentBorderGradient().createShader(bounds),
          child: Text(
            'P',
            style: ParkPalText.display(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _IrisScanCard extends StatelessWidget {
  const _IrisScanCard({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Ink(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            gradient: parkPalIridescentBorderGradient(),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: ParkPalColors.green900.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ParkPalColors.green900, ParkPalColors.midnight],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const _ScanLensIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'POWERED BY IRIS',
                        style: ParkPalText.mono(
                          color: ParkPalColors.irisCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign intelligence',
                        style: ParkPalText.display(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Report signs with GPS, search manually, and let Atlas combine verified parking evidence.',
                        style: ParkPalText.body(
                          color: Colors.white.withValues(alpha: 0.74),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntelligenceMapPreview extends StatelessWidget {
  const _IntelligenceMapPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            ParkPalColors.mint100,
            ParkPalColors.irisCyan.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(34),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MapPreviewPainter())),
            Positioned(
              left: 16,
              top: 16,
              child: _MapChip(
                icon: Icons.layers_rounded,
                label: 'Atlas preview',
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: _MapChip(
                icon: Icons.verified_rounded,
                label: 'Verified only',
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: ParkPalColors.lineSoft),
                ),
                child: Row(
                  children: [
                    const _PremiumIcon(
                      icon: Icons.local_parking_rounded,
                      color: ParkPalColors.safeGreen,
                      background: ParkPalColors.greenBg,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Beautiful maps will display live parking intelligence once map services are connected.',
                        style: ParkPalText.body(
                          color: ParkPalColors.muted,
                          fontSize: 13,
                          height: 1.32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetricGrid extends StatelessWidget {
  const _ResultMetricGrid({required this.result});

  final ParkingLookupResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ResultMetric(
                label: 'Time window',
                value: result.timeWindow,
                icon: Icons.schedule_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ResultMetric(
                label: 'Paid / free',
                value: result.paymentRequiredLabel,
                icon: Icons.payments_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ResultMetric(
                label: 'Leave by',
                value: result.leaveByTime,
                icon: Icons.timer_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ResultMetric(
                label: 'Evidence',
                value: result.evidenceSourceLabel,
                icon: Icons.fact_check_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultMetric extends StatelessWidget {
  const _ResultMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ParkPalColors.cream.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ParkPalColors.green700, size: 19),
          const SizedBox(height: 10),
          Text(
            label,
            style: ParkPalText.mono(
              color: ParkPalColors.mutedTwo,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ParkPalText.body(
              color: ParkPalColors.ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection({required this.history});

  final Future<List<ParkingHistoryEntry>>? history;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ParkingHistoryEntry>>(
      future: history,
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const <ParkingHistoryEntry>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingCard(label: 'Loading recent checks');
        }
        if (entries.isEmpty) {
          return const _EmptyRecentCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent checks',
                  style: ParkPalText.display(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ParkPalColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  'Evidence Vault',
                  style: ParkPalText.mono(
                    color: ParkPalColors.mutedTwo,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentHistoryCard(entry: entry),
              ),
          ],
        );
      },
    );
  }
}

class _RecentHistoryCard extends StatelessWidget {
  const _RecentHistoryCard({required this.entry});

  final ParkingHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final summary =
        entry.ruleSummary.isEmpty ? entry.resultStatus : entry.ruleSummary;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: parkPalGlassDecoration(opacity: 0.86, radius: 24),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 44,
            decoration: BoxDecoration(
              color: parkPalStatusColor(entry.resultStatus),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.queryText,
                  style: ParkPalText.body(
                    fontWeight: FontWeight.w800,
                    color: ParkPalColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ParkPalText.body(
                    color: ParkPalColors.muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(entry.confidence * 100).round()}%',
            style: ParkPalText.mono(
              color: ParkPalColors.mutedTwo,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: const BoxDecoration(color: ParkPalColors.cream),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -120,
              child: _GlowOrb(
                color: ParkPalColors.mint100.withValues(alpha: 0.85),
                size: 260,
              ),
            ),
            Positioned(
              top: 210,
              left: -150,
              child: _GlowOrb(
                color: ParkPalColors.irisCyan.withValues(alpha: 0.15),
                size: 260,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _MapPreviewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF9FAF7), Color(0xFFE8F1EA), Color(0xFFFDFBF6)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = ParkPalColors.lineSoft
      ..strokeWidth = 25
      ..strokeCap = StrokeCap.round;

    final roads = [
      [
        Offset(-20, size.height * .30),
        Offset(size.width * .92, size.height * .18),
      ],
      [
        Offset(size.width * .08, size.height + 18),
        Offset(size.width * .38, -18),
      ],
      [
        Offset(size.width * .62, size.height + 20),
        Offset(size.width * .88, -20),
      ],
      [
        Offset(-10, size.height * .74),
        Offset(size.width + 10, size.height * .62),
      ],
    ];

    for (final road in roads) {
      canvas.drawLine(road[0], road[1], roadEdge);
      canvas.drawLine(road[0], road[1], roadPaint);
    }

    final dashPaint = Paint()
      ..color = ParkPalColors.mutedTwo.withValues(alpha: 0.26)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final x = size.width * .06 + (i * size.width * .13);
      canvas.drawLine(
        Offset(x, size.height * .70),
        Offset(x + 18, size.height * .68),
        dashPaint,
      );
    }

    _drawPin(
      canvas,
      Offset(size.width * .38, size.height * .42),
      ParkPalColors.safeGreen,
    );
    _drawPin(
      canvas,
      Offset(size.width * .70, size.height * .28),
      ParkPalColors.amber,
    );
    _drawPin(
      canvas,
      Offset(size.width * .58, size.height * .68),
      ParkPalColors.red,
    );

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = ParkPalColors.irisBlue.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(size.width * .38, size.height * .42), 38, ring);
  }

  void _drawPin(Canvas canvas, Offset center, Color color) {
    final shadow = Paint()
      ..color = ParkPalColors.midnight.withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(center.translate(0, 8), 13, shadow);

    final paint = Paint()..color = color;
    canvas.drawCircle(center, 13, paint);
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLensIcon extends StatelessWidget {
  const _ScanLensIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ParkPalColors.glassBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                border: Border.all(color: ParkPalColors.irisCyan, width: 2),
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const Icon(
            Icons.center_focus_strong_rounded,
            color: Colors.white,
            size: 26,
          ),
        ],
      ),
    );
  }
}

class _MapChip extends StatelessWidget {
  const _MapChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ParkPalColors.lineSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: ParkPalColors.green700),
          const SizedBox(width: 6),
          Text(
            label,
            style: ParkPalText.mono(
              color: ParkPalColors.ink,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumIcon extends StatelessWidget {
  const _PremiumIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = parkPalStatusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: ParkPalText.mono(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: ParkPalText.body(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.8, radius: 24),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(label, style: ParkPalText.body(color: ParkPalColors.muted)),
        ],
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: parkPalGlassDecoration(opacity: 0.82, radius: 24),
      child: Row(
        children: [
          const _PremiumIcon(
            icon: Icons.receipt_long_rounded,
            color: ParkPalColors.green700,
            background: ParkPalColors.mint100,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Your Evidence Vault starts once you search a road while signed in.',
              style: ParkPalText.body(color: ParkPalColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustFooter extends StatelessWidget {
  const _TrustFooter();

  @override
  Widget build(BuildContext context) {
    return Text(
      'ParkPal guidance is informational. Always check the sign in front of you.',
      textAlign: TextAlign.center,
      style: ParkPalText.body(
        color: ParkPalColors.mutedTwo,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
