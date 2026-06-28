import 'package:test/test.dart';

import 'package:parkpal/data/firestore_collections.dart';
import 'package:parkpal/data/storage_paths.dart';

void main() {
  test('core collection names are stable', () {
    expect(ParkPalCollections.signs, 'parkpal_signs');
    expect(ParkPalCollections.roads, 'parkpal_roads');
    expect(ParkPalCollections.zones, 'parkpal_zones');
    expect(ParkPalCollections.reports, 'parkpal_reports');
    expect(ParkPalCollections.contributors, 'parkpal_contributors');
    expect(ParkPalCollections.queries, 'parkpal_queries');
    expect(ParkPalCollections.councils, 'parkpal_councils');
  });

  test('storage paths match the agreed Firebase layout', () {
    expect(
      ParkPalStoragePaths.signOriginal('sign-123'),
      'parkpal/signs/sign-123/original.jpg',
    );
    expect(
      ParkPalStoragePaths.signThumbnail('sign-123'),
      'parkpal/signs/sign-123/thumb.jpg',
    );
    expect(
      ParkPalStoragePaths.reportPhoto('report-123'),
      'parkpal/reports/report-123/photo.jpg',
    );
  });
}
