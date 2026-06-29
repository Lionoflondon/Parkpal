import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';
import 'parking_history_entry.dart';

class ParkingHistoryService {
  ParkingHistoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  Future<List<ParkingHistoryEntry>> fetchRecent({int limit = 20}) async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      final auth = _auth ?? FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) return const [];

      final firestore = _firestore ?? FirebaseFirestore.instance;
      final snapshot = await firestore
          .collection(ParkPalCollections.queries)
          .where('userId', isEqualTo: user.uid)
          .orderBy('queriedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ParkingHistoryEntry.fromMap(doc.id, doc.data()))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
