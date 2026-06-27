import 'package:flutter/material.dart';

import 'parking_lookup_result.dart';
import 'parking_query_service.dart';

class ParkingHomeScreen extends StatefulWidget {
  const ParkingHomeScreen({super.key});

  @override
  State<ParkingHomeScreen> createState() => _ParkingHomeScreenState();
}

class _ParkingHomeScreenState extends State<ParkingHomeScreen> {
  final _controller = TextEditingController();
  final _service = ParkingQueryService();

  ParkingLookupResult? _result;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('ParkPal')),
      body: SafeArea(
        child: ListView(
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
              'Enter a road or location to check ParkPal’s current parking intelligence.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
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
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.my_location),
              label: const Text('Use GPS location — coming soon'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            ParkingResultCard(result: _result ?? ParkingLookupResult.unknown()),
            const SizedBox(height: 24),
            const Text(
              'ParkPal guidance is informational. Always check street signs before parking.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
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
              'Can park: ${result.canParkLabel}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            _ResultRow(label: 'Rule summary', value: result.ruleSummary),
            _ResultRow(label: 'Time window', value: result.timeWindow),
            _ResultRow(
              label: 'Payment required',
              value: result.paymentRequiredLabel,
            ),
            _ResultRow(label: 'Risk level', value: result.riskLevel),
            _ResultRow(
              label: 'Confidence score',
              value: result.confidenceScore.toStringAsFixed(2),
            ),
            _ResultRow(
              label: 'Evidence source',
              value: result.evidenceSourceLabel,
            ),
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
