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
    required this.pendingPartners,
    required this.activePartners,
    required this.activeLocations,
    required this.availableSpaces,
    required this.revenueToday,
    required this.partnerApplications,
    required this.alerts,
  });

  final int liveBookings;
  final int pendingPartners;
  final int activePartners;
  final int activeLocations;
  final int availableSpaces;
  final double revenueToday;
  final int partnerApplications;
  final int alerts;

  static const empty = ParkPalAdminMetrics(
    liveBookings: 0,
    pendingPartners: 0,
    activePartners: 0,
    activeLocations: 0,
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
        _count(
          firestore,
          ParkPalAdminCollections.partners,
          field: 'status',
          value: 'pending',
        ),
        _count(
          firestore,
          ParkPalAdminCollections.partners,
          field: 'status',
          value: 'active',
        ),
        _count(
          firestore,
          ParkPalAdminCollections.locations,
          field: 'active',
          value: true,
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
        pendingPartners: results[1],
        activePartners: results[2],
        activeLocations: results[3],
        availableSpaces: results[4],
        revenueToday: revenue,
        partnerApplications: results[5],
        alerts: results[6],
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

  Future<bool> updatePartnerStatus({
    required String partnerId,
    required String status,
    required String onboardingStatus,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return false;
      await firestore
          .collection(ParkPalAdminCollections.partners)
          .doc(partnerId)
          .set({
        'status': status,
        'onboardingStatus': onboardingStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveLocation({
    String? locationId,
    required Map<String, Object?> data,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return false;
      final collection =
          firestore.collection(ParkPalAdminCollections.locations);
      final document = locationId == null || locationId.isEmpty
          ? collection.doc()
          : collection.doc(locationId);
      await document.set({
        ...data,
        'locationId': document.id,
        'updatedAt': FieldValue.serverTimestamp(),
        if (locationId == null || locationId.isEmpty)
          'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateLocationActive({
    required String locationId,
    required bool active,
  }) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return false;
      await firestore
          .collection(ParkPalAdminCollections.locations)
          .doc(locationId)
          .set({
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
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
