import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/parkpal_firebase_options.dart';

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

class ParkPalAdminAccess {
  const ParkPalAdminAccess({
    required this.allowed,
    this.role,
    this.bootstrapped = false,
    this.reason = 'not_authorised',
    this.message = 'This account is not authorised for ParkPal Admin.',
  });

  final bool allowed;
  final String? role;
  final bool bootstrapped;
  final String reason;
  final String message;
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
  static const _allowedRoles = [
    'superAdmin',
    'admin',
    'support',
    'reviewer',
    'pioneerManager',
    'atlasManager',
  ];

  Future<FirebaseAuth?> auth() async {
    try {
      await _ensureFirebase();
      return _auth ?? FirebaseAuth.instance;
    } catch (error, stackTrace) {
      _logAdminFailure('firebase_auth_init_failed', error, stackTrace);
      return null;
    }
  }

  Future<String?> currentAdminRole() async {
    final access = await currentAdminAccess();
    return access.role;
  }

  Future<ParkPalAdminAccess> currentAdminAccess() async {
    try {
      final auth = await this.auth();
      final user = auth?.currentUser;
      if (user == null) {
        return const ParkPalAdminAccess(
          allowed: false,
          reason: 'not_signed_in',
          message: 'Sign in to continue to ParkPal Admin.',
        );
      }
      final firestore = await _safeFirestore();
      if (firestore == null) {
        return const ParkPalAdminAccess(
          allowed: false,
          reason: 'firestore_unavailable',
          message: 'ParkPal Admin could not connect to Firestore.',
        );
      }
      return await _resolveAdminAccess(firestore, user);
    } catch (error, stackTrace) {
      _logAdminFailure('admin_access_check_failed', error, stackTrace);
      return ParkPalAdminAccess(
        allowed: false,
        reason: 'admin_access_check_failed',
        message: _friendlyError(error),
      );
    }
  }

  Future<ParkPalAdminAccess> _resolveAdminAccess(
    FirebaseFirestore firestore,
    User user,
  ) async {
    final admins = firestore.collection(ParkPalAdminCollections.adminUsers);
    final existingAdmins = await admins.limit(1).get();
    final adminRef = admins.doc(user.uid);

    if (existingAdmins.docs.isEmpty) {
      await adminRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'role': 'superAdmin',
        'status': 'active',
        'createdBy': 'bootstrap',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      return const ParkPalAdminAccess(
        allowed: true,
        role: 'superAdmin',
        bootstrapped: true,
        reason: 'bootstrap_created',
        message: 'First Super Admin created.',
      );
    }

    final doc = await adminRef.get();
    if (!doc.exists) {
      return const ParkPalAdminAccess(
        allowed: false,
        reason: 'admin_doc_missing',
        message: 'Admin access not granted for this account.',
      );
    }

    final data = doc.data();
    final role = data?['role'] as String?;
    final status = data?['status'] as String?;
    if (status == 'active' && _allowedRoles.contains(role)) {
      await adminRef.set({
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return ParkPalAdminAccess(
        allowed: true,
        role: role,
        reason: 'admin_access_granted',
        message: 'Admin access granted.',
      );
    }

    return ParkPalAdminAccess(
      allowed: false,
      reason: 'admin_role_inactive_or_invalid',
      message: status == 'active'
          ? 'Admin access not granted for this account role.'
          : 'This ParkPal Admin account is not active.',
    );
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
    } catch (error, stackTrace) {
      _logAdminFailure('firestore_init_failed', error, stackTrace);
      return null;
    }
  }

  Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email or password is incorrect.',
        'user-disabled' => 'This Firebase Auth user has been disabled.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled for ParkPal Admin.',
        _ => 'Could not sign in to ParkPal Admin.',
      };
    }
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' =>
          'Admin access not granted, or Firestore rules are blocking this account.',
        'unavailable' => 'ParkPal Firestore is temporarily unavailable.',
        _ => 'ParkPal Admin could not verify this account.',
      };
    }
    return 'ParkPal Admin could not verify this account.';
  }

  void _logAdminFailure(
    String reason,
    Object error,
    StackTrace stackTrace,
  ) {
    // ignore: avoid_print
    print('ParkPal Admin login failure [$reason]: $error');
    // ignore: avoid_print
    print(stackTrace);
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
