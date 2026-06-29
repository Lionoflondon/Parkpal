import 'package:flutter/material.dart';

import '../sign_capture/sign_capture_screen.dart';
import 'parking_lookup_result.dart';
import 'parking_query_service.dart';

class ParkingHomeScreen extends StatefulWidget {
  const ParkingHomeScreen({this.onOpenScan, super.key});

  final VoidCallback? onOpenScan;

  @override
  State<ParkingHomeScreen> createState() => _ParkingHomeScreenState();
}

class _ParkingHomeScreenState extends State<ParkingHomeScreen> {
  final _controller = TextEditingController();
  final _locationFocusNode = FocusNode();
  final _service = ParkingQueryService();

  ParkingLookupResult? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _locationFocusNode.dispose();
    super.dispose();
  }

  void _focusManualLocation() {
    _locationFocusNode.requestFocus();
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.search(_controller.text);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _result = ParkingLookupResult.unknown();
        _error = 'ParkPal could not complete this search. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Know before you park.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check whether ParkPal has enough parking-rule evidence for this location.',
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.my_location),
          label: const Text('Current location — coming soon'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SignCaptureScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_a_photo),
          label: const Text("Add a sign you've seen"),
        ),
        OutlinedButton.icon(
          onPressed: widget.onOpenScan,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Scan or upload sign'),
        ),
        OutlinedButton.icon(
          onPressed: _focusManualLocation,
          icon: const Icon(Icons.edit_location_alt_outlined),
          label: const Text('Manual location entry'),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          focusNode: _locationFocusNode,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Road or location',
            hintText: 'e.g. Kensington Road',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _isLoading ? null : _search,
          child: _isLoading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Can I park here?'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        ParkingResultCard(result: _result ?? ParkingLookupResult.unknown()),
        const SizedBox(height: 24),
        const Text(
          'ParkPal guidance is informational. Always check street signs before parking.',
          style: TextStyle(fontSize: 12),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parking status: ${result.canParkLabel}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _ResultRow(label: 'Rule summary', value: result.ruleSummary),
            _ResultRow(label: 'Time limit', value: result.timeWindow),
            _ResultRow(label: 'Paid/free', value: result.paymentRequiredLabel),
            _ResultRow(label: 'Risk warning', value: result.riskLevel),
            _ResultRow(label: 'Leave-by time', value: result.leaveByTime),
            _ResultRow(
              label: 'Confidence score',
              value: result.confidenceScore.toStringAsFixed(2),
            ),
            _ResultRow(
              label: 'Evidence source',
              value: result.evidenceSourceLabel,
            ),
            _ResultRow(label: 'Evidence reason', value: result.evidenceReason),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );
  }
}
