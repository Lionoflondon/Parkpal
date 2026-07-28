import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../data/firestore_collections.dart';

class ParkingReportService {
  ParkingReportService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  Future<bool> submitIssue({
    required String description,
    String? streetName,
    String? council,
  }) async {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return false;

    try {
      final firestore = await _safeFirestore();
      final auth = await _safeAuth();
      if (firestore == null || auth == null) return false;

      final user = await _ensureUser(auth);
      if (user == null) return false;

      final doc = firestore.collection(ParkPalCollections.reports).doc();
      await doc.set({
        'reportId': doc.id,
        'userId': user.uid,
        'reportType': 'wrong_interpretation',
        'description': trimmed,
        if (streetName != null && streetName.trim().isNotEmpty)
          'streetName': streetName.trim(),
        if (council != null && council.trim().isNotEmpty)
          'council': council.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<FirebaseAuth?> _safeAuth() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return _auth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<User?> _ensureUser(FirebaseAuth auth) async {
    try {
      return auth.currentUser ?? (await auth.signInAnonymously()).user;
    } catch (_) {
      return null;
    }
  }
}
