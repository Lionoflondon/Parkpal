import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('customer Atlas UI does not expose operational pipeline language', () {
    const customerFiles = [
      'lib/features/atlas_intelligence/customer_atlas_screen.dart',
      'lib/features/dashboard/customer_dashboard_screen.dart',
      'lib/features/parking_query/parking_home_screen.dart',
      'lib/app/parkpal_public_shell.dart',
    ];
    const bannedPhrases = [
      'Import Logs',
      'Import logs',
      'Source Health',
      'source health',
      'Import Pipeline',
      'pipeline',
      'Atlas coverage',
      'Council import',
      'PCI',
      'Known roads',
      'Verified roads',
      'Import failures',
      'failed import',
      'Awaiting data',
      'Pending import',
      'Connector',
      'connector',
      'diagnostics',
      'Parser',
      'parser',
      'operational metrics',
      'conflict signals',
      'waiting for review',
      'source attribution',
    ];

    final combined =
        customerFiles.map((path) => File(path).readAsStringSync()).join('\n');

    for (final phrase in bannedPhrases) {
      expect(
        combined,
        isNot(contains(phrase)),
        reason: 'Customer UI should not expose "$phrase".',
      );
    }
  });
}
