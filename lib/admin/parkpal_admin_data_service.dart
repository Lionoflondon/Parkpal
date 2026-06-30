import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class ParkPalAdminCollections {
  const ParkPalAdminCollections._();

  static const partners = 'parkpalPartners';
  static const locations = 'parkpalLocations';
  static const bookings = 'parkpalBookings';
  static const members = 'parkpalMembers';
  static const payments = 'parkpalPayments';
  static const supportTickets = 'parkpalSupportTickets';
  static const adminUsers = 'parkpalAdminUsers';
}

class ParkPalAdminMetrics {
  const ParkPalAdminMetrics({
    required this.liveBookings,
    required this.availableSpaces,
    required this.revenueToday,
    required this.partnerApplications,
    required this.alerts,
  });

  final int liveBookings;
  final int availableSpaces;
  final double revenueToday;
  final int partnerApplications;
  final int alerts;

  static const empty = ParkPalAdminMetrics(
    liveBookings: 0,
    availableSpaces: 0,
    revenueToday: 0,
    partnerApplications: 0,
    alerts: 0,
  );
}

class ParkPalAdminDataService {
  ParkPalAdminDataService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  Future<FirebaseAuth?> auth() async {
    try {
      await _ensureFirebase();
      return _auth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<String?> currentAdminRole() async {
    try {
      final auth = await this.auth();
      final user = auth?.currentUser;
      if (user == null) return null;
      final firestore = await _safeFirestore();
      if (firestore == null) return null;
      final doc = await firestore
          .collection(ParkPalAdminCollections.adminUsers)
          .doc(user.uid)
          .get();
      final role = doc.data()?['role'] as String?;
      if (const ['superAdmin', 'admin', 'support', 'partnerManager']
          .contains(role)) {
        return role;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ParkPalAdminMetrics> fetchDashboardMetrics() async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return ParkPalAdminMetrics.empty;
      final results = await Future.wait<int>([
        _count(
          firestore,
          ParkPalAdminCollections.bookings,
          field: 'status',
          value: 'active',
        ),
        _sumInt(
            firestore, ParkPalAdminCollections.locations, 'availableSpaces'),
        _count(
          firestore,
          ParkPalAdminCollections.partners,
          field: 'status',
          value: 'pending',
        ),
        _count(
          firestore,
          ParkPalAdminCollections.supportTickets,
          field: 'priority',
          value: 'urgent',
        ),
      ]);
      final revenue = await _sumDouble(
        firestore,
        ParkPalAdminCollections.payments,
        'amountToday',
      );
      return ParkPalAdminMetrics(
        liveBookings: results[0],
        availableSpaces: results[1],
        revenueToday: revenue,
        partnerApplications: results[2],
        alerts: results[3],
      );
    } catch (_) {
      return ParkPalAdminMetrics.empty;
    }
  }

  Future<List<Map<String, Object?>>> fetchModuleRows(String collection) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return const [];
      final snapshot = await firestore.collection(collection).limit(12).get();
      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      await _ensureFirebase();
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  Future<int> _count(
    FirebaseFirestore firestore,
    String collection, {
    String? field,
    Object? value,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (field != null) query = query.where(field, isEqualTo: value);
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Future<int> _sumInt(
    FirebaseFirestore firestore,
    String collection,
    String field,
  ) async {
    final snapshot = await firestore.collection(collection).limit(50).get();
    return snapshot.docs.fold<int>(
      0,
      (total, doc) => total + ((doc.data()[field] as num?)?.toInt() ?? 0),
    );
  }

  Future<double> _sumDouble(
    FirebaseFirestore firestore,
    String collection,
    String field,
  ) async {
    final snapshot = await firestore.collection(collection).limit(50).get();
    return snapshot.docs.fold<double>(
      0,
      (total, doc) => total + ((doc.data()[field] as num?)?.toDouble() ?? 0),
    );
  }
}
