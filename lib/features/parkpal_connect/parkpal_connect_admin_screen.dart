import 'package:flutter/material.dart';

import 'parkpal_connect_import_service.dart';
import 'parkpal_connect_source.dart';

class ParkPalConnectAdminScreen extends StatefulWidget {
  const ParkPalConnectAdminScreen({super.key});

  @override
  State<ParkPalConnectAdminScreen> createState() =>
      _ParkPalConnectAdminScreenState();
}

class _ParkPalConnectAdminScreenState extends State<ParkPalConnectAdminScreen> {
  final _service = ParkPalConnectImportService();
  final _sourceNameController = TextEditingController();
  final _councilController = TextEditingController();
  final _boroughController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  final _licenceController = TextEditingController();
  ParkPalConnectSourceType _sourceType = ParkPalConnectSourceType.csv;
  ParkPalConnectImportResult _lastResult = ParkPalConnectImportResult.empty;
  bool _importing = false;

  @override
  void dispose() {
    _sourceNameController.dispose();
    _councilController.dispose();
    _boroughController.dispose();
    _sourceUrlController.dispose();
    _licenceController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final sourceName = _sourceNameController.text.trim();
    final source = ParkPalConnectSource(
      sourceId:
          _stableId(sourceName.isEmpty ? 'parkpal-connect-source' : sourceName),
      sourceName: sourceName,
      council: _councilController.text.trim(),
      borough: _boroughController.text.trim(),
      sourceType: _sourceType,
      sourceUrl: _sourceUrlController.text.trim(),
      licence: _licenceController.text.trim(),
    );

    final result = await _service.importFromSource(source: source);
    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _importing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ParkPal Connect')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _sourceNameController,
            decoration: const InputDecoration(labelText: 'Source name'),
          ),
          TextField(
            controller: _councilController,
            decoration: const InputDecoration(labelText: 'Council'),
          ),
          TextField(
            controller: _boroughController,
            decoration: const InputDecoration(labelText: 'Borough'),
          ),
          DropdownButtonFormField<ParkPalConnectSourceType>(
            initialValue: _sourceType,
            decoration: const InputDecoration(labelText: 'Source type'),
            items: [
              for (final type in ParkPalConnectSourceType.values)
                DropdownMenuItem(value: type, child: Text(type.name)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _sourceType = value);
            },
          ),
          TextField(
            controller: _sourceUrlController,
            decoration: const InputDecoration(labelText: 'Source URL'),
          ),
          TextField(
            controller: _licenceController,
            decoration: const InputDecoration(labelText: 'Licence'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _importing ? null : _import,
            child: Text(_importing ? 'Importing…' : 'Import'),
          ),
          const SizedBox(height: 20),
          _ImportResultCard(result: _lastResult),
        ],
      ),
    );
  }

  String _stableId(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }
}

class _ImportResultCard extends StatelessWidget {
  const _ImportResultCard({required this.result});

  final ParkPalConnectImportResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last import result',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Imported: ${result.imported}'),
            Text('Skipped: ${result.skipped}'),
            Text('Failed: ${result.failed}'),
            Text('Conflicts: ${result.conflicts}'),
          ],
        ),
      ),
    );
  }
}
