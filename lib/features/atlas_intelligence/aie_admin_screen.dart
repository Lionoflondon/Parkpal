import 'package:flutter/material.dart';

import '../../admin/parkpal_admin_theme.dart';
import 'aie_import_engine.dart';
import 'aie_models.dart';

class AieAdminScreen extends StatefulWidget {
  const AieAdminScreen({super.key});

  @override
  State<AieAdminScreen> createState() => _AieAdminScreenState();
}

class _AieAdminScreenState extends State<AieAdminScreen> {
  final _engine = AieImportEngine();
  final _sourceName = TextEditingController();
  final _sourceId = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _council = TextEditingController();
  final _rawData = TextEditingController();
  AieSourceType _sourceType = AieSourceType.councilParkingPage;
  AieDocumentType _documentType = AieDocumentType.csv;
  Future<AieDashboardSummary>? _summary;
  Future<List<AieSource>>? _sources;
  AieImportResult? _lastResult;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _sourceName.dispose();
    _sourceId.dispose();
    _sourceUrl.dispose();
    _council.dispose();
    _rawData.dispose();
    super.dispose();
  }

  void _refresh() {
    _summary = _engine.fetchDashboardSummary();
    _sources = _engine.fetchSources();
  }

  Future<void> _runImport() async {
    if (_sourceId.text.trim().isEmpty ||
        _sourceUrl.text.trim().isEmpty ||
        _council.text.trim().isEmpty ||
        _rawData.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Source ID, URL, council and raw data are required.'),
        ),
      );
      return;
    }

    setState(() => _importing = true);
    final source = AieSource(
      sourceId: _sourceId.text.trim(),
      sourceName: _sourceName.text.trim().isEmpty
          ? _sourceId.text.trim()
          : _sourceName.text.trim(),
      sourceUrl: _sourceUrl.text.trim(),
      council: _council.text.trim(),
      sourceType: _sourceType,
      documentType: _documentType,
      importStatus: AieImportStatus.queued,
      version: 0,
      confidence: 1,
      enabled: true,
    );
    final result = await _engine.importOfficialSource(
      source: source,
      rawData: _rawData.text,
      requestedBy: 'ParkPal Admin',
    );
    if (!mounted) return;
    setState(() {
      _lastResult = result;
      _importing = false;
      _refresh();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AIE import ${result.status.name}.')),
    );
  }

  Future<void> _retryFromLog(Map<String, Object?> log) async {
    final diagnostics = (log['diagnostics'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final selectedParser = diagnostics['selectedParser']?.toString();
    final fetchUrl = log['fetchUrl']?.toString();
    setState(() {
      _sourceId.text = log['sourceId']?.toString() ?? _sourceId.text;
      _sourceName.text = log['sourceId']?.toString() ?? _sourceName.text;
      _sourceUrl.text = log['canonicalSourceUrl']?.toString() ??
          log['sourceUrl']?.toString() ??
          fetchUrl ??
          _sourceUrl.text;
      _council.text = log['council']?.toString() ?? _council.text;
      _rawData.text = fetchUrl ?? _sourceUrl.text;
      if (selectedParser != null) {
        _documentType = AieDocumentType.values.firstWhere(
          (value) => value.name == selectedParser,
          orElse: () => _documentType,
        );
      }
    });
    await _runImport();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AieDashboardSummary>(
      future: _summary,
      builder: (context, snapshot) {
        final summary = snapshot.data ?? AieDashboardSummary.empty;
        return ListView(
          children: [
            Text('Atlas Intelligence Engine', style: adminHeading(size: 46)),
            const SizedBox(height: 8),
            Text(
              'Authoritative official-source intelligence for discovery, import, IRIS structuring, Atlas versioning, conflicts, missions and Evidence Vault distribution.',
              style: adminBody(color: ParkPalAdminColors.muted),
            ),
            const SizedBox(height: 24),
            _ArchitectureCard(),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _MetricTile(
                  label: 'Connected councils',
                  value: '${summary.connectedCouncils}',
                ),
                _MetricTile(
                    label: 'Import queue', value: '${summary.importQueue}'),
                _MetricTile(
                  label: 'Failed imports',
                  value: '${summary.failedImports}',
                  accent: ParkPalAdminColors.red,
                ),
                _MetricTile(
                    label: 'Import logs', value: '${summary.importLogs}'),
                _MetricTile(
                  label: 'Pending conflicts',
                  value: '${summary.pendingConflicts}',
                  accent: ParkPalAdminColors.amber,
                ),
                _MetricTile(
                  label: 'Pending verification',
                  value: '${summary.pendingVerification}',
                ),
                _MetricTile(
                    label: 'Stale roads', value: '${summary.staleRoads}'),
                _MetricTile(
                  label: 'Mission queue',
                  value: '${summary.missionQueue}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _ImportPanel(
              sourceName: _sourceName,
              sourceId: _sourceId,
              sourceUrl: _sourceUrl,
              council: _council,
              rawData: _rawData,
              sourceType: _sourceType,
              documentType: _documentType,
              importing: _importing,
              onSourceTypeChanged: (value) =>
                  setState(() => _sourceType = value),
              onDocumentTypeChanged: (value) =>
                  setState(() => _documentType = value),
              onImport: _runImport,
            ),
            if (_lastResult != null) ...[
              const SizedBox(height: 18),
              _LastResultCard(result: _lastResult!, onRetry: _runImport),
            ],
            const SizedBox(height: 24),
            _Section(
              title: 'Connected councils',
              child: FutureBuilder<List<AieSource>>(
                future: _sources,
                builder: (context, snapshot) {
                  final sources = snapshot.data ?? const <AieSource>[];
                  if (sources.isEmpty) {
                    return const _EmptyPanel(
                      'No AIE sources connected yet. Add an official source above and run a manual import.',
                    );
                  }
                  return Column(
                    children: [
                      for (final source in sources) _SourceRow(source: source),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _TwoColumnLists(summary: summary, onRetryLog: _retryFromLog),
          ],
        );
      },
    );
  }
}

class _ArchitectureCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Official Sources',
      'Source Connectors',
      'Import Engine',
      'Parser Engine',
      'IRIS Knowledge Engine',
      'Atlas Knowledge Graph',
      'Evidence Vault • Mission Engine • Public API',
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AIE pipeline', style: adminHeading(size: 30)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < steps.length; i++)
                Chip(
                  label: Text('${i + 1}. ${steps[i]}'),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({
    required this.sourceName,
    required this.sourceId,
    required this.sourceUrl,
    required this.council,
    required this.rawData,
    required this.sourceType,
    required this.documentType,
    required this.importing,
    required this.onSourceTypeChanged,
    required this.onDocumentTypeChanged,
    required this.onImport,
  });

  final TextEditingController sourceName;
  final TextEditingController sourceId;
  final TextEditingController sourceUrl;
  final TextEditingController council;
  final TextEditingController rawData;
  final AieSourceType sourceType;
  final AieDocumentType documentType;
  final bool importing;
  final ValueChanged<AieSourceType> onSourceTypeChanged;
  final ValueChanged<AieDocumentType> onDocumentTypeChanged;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Manual official-source import', style: adminHeading(size: 32)),
          const SizedBox(height: 8),
          Text(
            'AIE does not scrape here. Paste official data from council pages, TROs, CPZ data, JSON, CSV, XML, RSS or GeoJSON — or paste the official file download URL. Checksum detection ensures unchanged sources are skipped.',
            style: adminBody(color: ParkPalAdminColors.muted),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SizedField(controller: sourceName, label: 'Source name'),
              _SizedField(controller: sourceId, label: 'Source ID'),
              _SizedField(controller: sourceUrl, label: 'Official URL'),
              _SizedField(controller: council, label: 'Council'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Dropdown<AieSourceType>(
                label: 'Source type',
                value: sourceType,
                values: AieSourceType.values,
                labelFor: aieSourceTypeLabel,
                onChanged: onSourceTypeChanged,
              ),
              _Dropdown<AieDocumentType>(
                label: 'Document type',
                value: documentType,
                values: AieDocumentType.values,
                labelFor: (value) => value.name.toUpperCase(),
                onChanged: onDocumentTypeChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: rawData,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Paste official data or download URL',
              helperText:
                  'Paste CSV/JSON/XML/GeoJSON content, or paste the official download URL. Atlas will fetch and validate it.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: importing ? null : onImport,
            icon: importing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(importing ? 'Importing…' : 'Run AIE import'),
          ),
        ],
      ),
    );
  }
}

class _TwoColumnLists extends StatelessWidget {
  const _TwoColumnLists({required this.summary, required this.onRetryLog});

  final AieDashboardSummary summary;
  final Future<void> Function(Map<String, Object?> log) onRetryLog;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 900;
        final logs = _Section(
          title: 'Import logs',
          child: summary.recentLogs.isEmpty
              ? const _EmptyPanel('No import logs yet.')
              : Column(
                  children: [
                    for (final log in summary.recentLogs)
                      _MapRow(
                        title:
                            log['sourceId']?.toString() ?? log['id'].toString(),
                        subtitle: _logSubtitle(log),
                        onTap: () => _showImportDetails(context, log),
                      ),
                  ],
                ),
        );
        final changes = _Section(
          title: 'Change history',
          child: summary.recentChanges.isEmpty
              ? const _EmptyPanel('No detected changes yet.')
              : Column(
                  children: [
                    for (final change in summary.recentChanges)
                      _MapRow(
                        title: change['roadName']?.toString() ??
                            change['id'].toString(),
                        subtitle: change['changeSummary']?.toString() ??
                            change['changeType']?.toString() ??
                            'Change recorded',
                      ),
                  ],
                ),
        );
        if (stacked) {
          return Column(children: [logs, const SizedBox(height: 16), changes]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: logs),
            const SizedBox(width: 16),
            Expanded(child: changes),
          ],
        );
      },
    );
  }

  String _logSubtitle(Map<String, Object?> log) {
    final diagnostics = (log['diagnostics'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final messages = (log['messages'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .join(' • ') ??
        '';
    final fetchUrl = log['fetchUrl']?.toString();
    final failureStage = diagnostics['failureStage']?.toString();
    final failureLabel = diagnostics['failureLabel']?.toString();
    return [
      if (failureStage != null && failureStage.isNotEmpty)
        'stage: $failureStage',
      failureLabel ?? '${log['status'] ?? 'unknown'}',
      'imported ${log['imported'] ?? 0}',
      'failed ${log['failed'] ?? 0}',
      if (fetchUrl != null && fetchUrl.isNotEmpty) 'fetch: $fetchUrl',
      if (messages.isNotEmpty) messages,
    ].join(' • ');
  }

  void _showImportDetails(BuildContext context, Map<String, Object?> log) {
    showDialog<void>(
      context: context,
      builder: (context) => _ImportDetailsDialog(
        log: log,
        onRetry: () async {
          Navigator.of(context).pop();
          await onRetryLog(log);
        },
      ),
    );
  }
}

class _LastResultCard extends StatelessWidget {
  const _LastResultCard({required this.result, required this.onRetry});

  final AieImportResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _MiniStat(label: 'Status', value: result.status.name),
              _MiniStat(label: 'Imported', value: '${result.imported}'),
              _MiniStat(label: 'Changed', value: '${result.changed}'),
              _MiniStat(label: 'Skipped', value: '${result.skipped}'),
              _MiniStat(label: 'Failed', value: '${result.failed}'),
              _MiniStat(label: 'Conflicts', value: '${result.conflicts}'),
              _MiniStat(label: 'Missions', value: '${result.missionsCreated}'),
            ],
          ),
          if (result.messages.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final message in result.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  message,
                  style: adminBody(
                    color: result.failed > 0
                        ? ParkPalAdminColors.red
                        : ParkPalAdminColors.muted,
                    size: 12,
                  ),
                ),
              ),
          ],
          if (result.failed > 0) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('Retry import'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.accent = ParkPalAdminColors.cyan,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: adminGlassDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: adminBody(color: ParkPalAdminColors.muted)),
            const SizedBox(height: 10),
            Text(value, style: adminHeading(size: 34).copyWith(color: accent)),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final AieSource source;

  @override
  Widget build(BuildContext context) {
    return _MapRow(
      title: source.sourceName ?? source.sourceId,
      subtitle:
          '${source.council} • ${aieSourceTypeLabel(source.sourceType)} • ${source.importStatus.name} • v${source.version}',
    );
  }
}

class _MapRow extends StatelessWidget {
  const _MapRow({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ParkPalAdminColors.glassBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.hub_outlined, color: ParkPalAdminColors.cyan),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: adminBody(weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: adminBody(color: ParkPalAdminColors.muted, size: 12),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: ParkPalAdminColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}

class _ImportDetailsDialog extends StatelessWidget {
  const _ImportDetailsDialog({required this.log, required this.onRetry});

  final Map<String, Object?> log;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final diagnostics = (log['diagnostics'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final messages = (log['messages'] as List?)
            ?.map((value) => value.toString())
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
    final failed = (log['failed'] as num?)?.toInt() ?? 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: adminGlassDecoration(),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import details', style: adminHeading(size: 36)),
                const SizedBox(height: 8),
                Text(
                  log['sourceId']?.toString() ?? log['id']?.toString() ?? '',
                  style: adminBody(color: ParkPalAdminColors.muted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MiniStat(label: 'Status', value: '${log['status']}'),
                    _MiniStat(label: 'Imported', value: '${log['imported']}'),
                    _MiniStat(label: 'Failed', value: '${log['failed']}'),
                    _MiniStat(label: 'Skipped', value: '${log['skipped']}'),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailsGrid(items: {
                  'Failure stage': diagnostics['failureStage'],
                  'Failure label': diagnostics['failureLabel'],
                  'Source ID': diagnostics['sourceId'] ?? log['sourceId'],
                  'Source name': diagnostics['sourceName'],
                  'Original source URL':
                      diagnostics['originalSourceUrl'] ?? log['sourceUrl'],
                  'Constructed URL': diagnostics['constructedUrl'],
                  'Authority': diagnostics['authority'],
                  'Dataset ID': diagnostics['datasetId'],
                  'Host': diagnostics['host'],
                  'Selected export format': diagnostics['selectedExportFormat'],
                  'Available export formats':
                      diagnostics['availableExportFormats'],
                  'Fetched URL': log['fetchUrl'] ?? diagnostics['fetchUrl'],
                  'HTTP status': diagnostics['httpStatus'],
                  'Final redirected URL': diagnostics['finalUrl'],
                  'Content type':
                      log['contentType'] ?? diagnostics['contentType'],
                  'Response size': diagnostics['responseSize'],
                  'Selected parser': diagnostics['selectedParser'],
                  'Parser error': diagnostics['parserError'],
                  'Exception type': diagnostics['exceptionType'],
                  'Exception message': diagnostics['exceptionMessage'],
                  'Timestamp':
                      diagnostics['diagnosticsTimestamp'] ?? log['createdAt'],
                }),
                if (diagnostics['stackTrace'] != null) ...[
                  const SizedBox(height: 18),
                  Text('Stack trace',
                      style: adminBody(weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: ParkPalAdminColors.glassBorder),
                    ),
                    child: Text(
                      diagnostics['stackTrace'].toString(),
                      style: adminBody(
                        color: ParkPalAdminColors.muted,
                        size: 12,
                      ),
                    ),
                  ),
                ],
                if (messages.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Messages', style: adminBody(weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final message in messages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        message,
                        style: adminBody(
                          color: failed > 0
                              ? ParkPalAdminColors.red
                              : ParkPalAdminColors.muted,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 18),
                Text(
                  'First 300 chars',
                  style: adminBody(weight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ParkPalAdminColors.glassBorder),
                  ),
                  child: Text(
                    diagnostics['responsePreview']?.toString() ??
                        'No response preview recorded.',
                    style: adminBody(
                      color: ParkPalAdminColors.muted,
                      size: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_outlined),
                        label: const Text('Retry import'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.items});

  final Map<String, Object?> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final entry in items.entries)
          SizedBox(
            width: 350,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ParkPalAdminColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: adminBody(
                      color: ParkPalAdminColors.muted,
                      size: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.value?.toString() ?? 'Not recorded',
                    style: adminBody(weight: FontWeight.w800, size: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: adminGlassDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: adminHeading(size: 30)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: adminBody(color: ParkPalAdminColors.muted));
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _SizedField extends StatelessWidget {
  const _SizedField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in values)
            DropdownMenuItem<T>(
              value: item,
              child: Text(labelFor(item), overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}
