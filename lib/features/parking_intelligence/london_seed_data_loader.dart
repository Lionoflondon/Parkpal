import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/firestore_collections.dart';

class LondonSeedDataLoader {
  LondonSeedDataLoader({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<int> loadSmallLondonSeed() async {
    const records = [
      {
        'roadId': 'seed_kensington_road',
        'streetName': 'Kensington Road',
        'normalizedStreetName': 'kensington road',
        'borough': 'Kensington and Chelsea',
        'council': 'Royal Borough of Kensington and Chelsea',
        'country': 'UK',
        'parkingRisk': 'medium',
        'defaultSummary':
            'Seed record only. Check signs for bay-level restrictions.',
        'confidenceScore': 0.7,
      },
      {
        'roadId': 'seed_oxford_street',
        'streetName': 'Oxford Street',
        'normalizedStreetName': 'oxford street',
        'borough': 'Westminster',
        'council': 'Westminster City Council',
        'country': 'UK',
        'parkingRisk': 'high',
        'defaultSummary':
            'Seed record only. High-demand central London restriction area.',
        'confidenceScore': 0.7,
      },
    ];

    for (final record in records) {
      await _firestore
          .collection(ParkPalCollections.roads)
          .doc(record['roadId']! as String)
          .set({
        ...record,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return records.length;
  }
}
