import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/parkpal_firebase_options.dart';

class ParkPalAdminCollections {
  const ParkPalAdminCollections._();

  static const councils = 'parkpal_councils';
  static const signs = 'parkpal_signs';
  static const roads = 'parkpal_roads';
  static const checks = 'parkpal_queries';
  static const evidence = 'parkpalEvidenceRecords';
  static const appealSupport = 'parkpalAppealSupportCases';
  static const reports = 'parkpal_reports';
  static const irisReview = 'parkpalIrisReviewQueue';
  static const contributors = 'parkpal_contributors';
  static const alerts = 'parkpalAdminAlerts';
  static const adminUsers = 'parkpalAdminUsers';
  static const operationalSettings = 'parkpalOperationalSettings';
  static const atlasIntelligenceSources = 'parkpal_aie_sources';
  static const atlasIntelligenceImportLogs = 'parkpal_aie_import_logs';
  static const atlasIntelligenceConflicts = 'parkpal_aie_conflicts';
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

class ParkPalAdminPasswordResult {
  const ParkPalAdminPasswordResult({
    required this.success,
    required this.message,
    this.requiresSignIn = false,
  });

  final bool success;
  final String message;
  final bool requiresSignIn;
}

class ParkPalAdminMetrics {
  const ParkPalAdminMetrics({
    required this.totalParkingChecks,
    required this.reviewNeededChecks,
    required this.verifiedSigns,
    required this.councilRulesLoaded,
    required this.evidenceRecords,
    required this.appealSupportCases,
    required this.activeUsers,
    required this.alerts,
  });

  final int totalParkingChecks;
  final int reviewNeededChecks;
  final int verifiedSigns;
  final int councilRulesLoaded;
  final int evidenceRecords;
  final int appealSupportCases;
  final int activeUsers;
  final int alerts;

  static const empty = ParkPalAdminMetrics(
    totalParkingChecks: 0,
    reviewNeededChecks: 0,
    verifiedSigns: 0,
    councilRulesLoaded: 0,
    evidenceRecords: 0,
    appealSupportCases: 0,
    activeUsers: 0,
    alerts: 0,
  );
}

class ParkPalOperationalSettingsResult {
  const ParkPalOperationalSettingsResult({
    required this.data,
    required this.loaded,
    this.message,
  });

  final Map<String, Object?> data;
  final bool loaded;
  final String? message;
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

  Future<String?> currentAdminEmail() async {
    final auth = await this.auth();
    return auth?.currentUser?.email;
  }

  Future<void> signOut() async {
    final auth = await this.auth();
    await auth?.signOut();
  }

  Future<ParkPalAdminPasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final auth = await this.auth();
      final user = auth?.currentUser;
      final email = user?.email;
      if (user == null || email == null || email.isEmpty) {
        return const ParkPalAdminPasswordResult(
          success: false,
          message: 'Session expired; sign in again.',
          requiresSignIn: true,
        );
      }

      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
      return const ParkPalAdminPasswordResult(
        success: true,
        message: 'Password updated.',
      );
    } on FirebaseAuthException catch (error) {
      return ParkPalAdminPasswordResult(
        success: false,
        message: _friendlyPasswordError(error),
        requiresSignIn: error.code == 'requires-recent-login',
      );
    } catch (_) {
      return const ParkPalAdminPasswordResult(
        success: false,
        message: 'Unknown Firebase Auth error.',
      );
    }
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
        _count(firestore, ParkPalAdminCollections.checks),
        _count(
          firestore,
          ParkPalAdminCollections.checks,
          field: 'resultStatus',
          values: const ['Unknown', 'unknown', 'review_needed'],
        ),
        _count(
          firestore,
          ParkPalAdminCollections.signs,
          field: 'verificationStatus',
          value: 'verified',
        ),
        _count(firestore, ParkPalAdminCollections.councils),
        _count(firestore, ParkPalAdminCollections.evidence),
        _count(firestore, ParkPalAdminCollections.appealSupport),
        _count(firestore, ParkPalAdminCollections.contributors),
        _count(firestore, ParkPalAdminCollections.alerts),
      ]);
      return ParkPalAdminMetrics(
        totalParkingChecks: results[0],
        reviewNeededChecks: results[1],
        verifiedSigns: results[2],
        councilRulesLoaded: results[3],
        evidenceRecords: results[4],
        appealSupportCases: results[5],
        activeUsers: results[6],
        alerts: results[7],
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

  Future<ParkPalOperationalSettingsResult> loadOperationalSettings() async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) {
        return const ParkPalOperationalSettingsResult(
          data: {},
          loaded: false,
          message: 'Unable to load settings. Please try again.',
        );
      }
      final doc = firestore
          .collection(ParkPalAdminCollections.operationalSettings)
          .doc('default');
      final snapshot = await doc.get();
      if (!snapshot.exists) {
        final defaults = _defaultOperationalSettings();
        await doc.set({
          ...defaults,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': (_auth ?? FirebaseAuth.instance).currentUser?.email ??
              'ParkPal Admin',
        });
        return ParkPalOperationalSettingsResult(data: defaults, loaded: true);
      }
      return ParkPalOperationalSettingsResult(
        data: {
          ..._defaultOperationalSettings(),
          'id': snapshot.id,
          ...?snapshot.data(),
        },
        loaded: true,
      );
    } catch (_) {
      return const ParkPalOperationalSettingsResult(
        data: {},
        loaded: false,
        message: 'Unable to load settings. Please try again.',
      );
    }
  }

  Future<bool> saveOperationalSetting(String field, Object? value) async {
    try {
      final firestore = await _safeFirestore();
      if (firestore == null) return false;
      await firestore
          .collection(ParkPalAdminCollections.operationalSettings)
          .doc('default')
          .set({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': (_auth ?? FirebaseAuth.instance).currentUser?.email ??
            'ParkPal Admin',
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

  String _friendlyPasswordError(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-credential' || 'wrong-password' => 'Incorrect current password.',
      'weak-password' => 'Password too weak.',
      'requires-recent-login' => 'Session expired; sign in again.',
      'network-request-failed' => 'Network error.',
      _ => 'Unknown Firebase Auth error.',
    };
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
    List<Object?>? values,
  }) async {
    Query<Map<String, dynamic>> query = firestore.collection(collection);
    if (field != null && values != null) {
      query = query.where(field, whereIn: values);
    } else if (field != null) {
      query = query.where(field, isEqualTo: value);
    }
    final snapshot = await query.count().get();
    return snapshot.count ?? 0;
  }

  Map<String, Object?> _defaultOperationalSettings() {
    return {
      'maximumParkingDurationMinutes': 120,
      'gracePeriodMinutes': 10,
      'cancellationRules': 'No booking flow in ParkPal. Reserved for future.',
      'bookingExtensionsEnabled': false,
      'autoReleaseExpiredBookings': false,
      'stripeStatus': 'not_configured',
      'refundPolicy': 'Manual review',
      'platformFeePercent': 0,
      'taxes': 'UK VAT rules pending',
      'defaultCurrency': 'GBP',
      'emailNotifications': true,
      'smsNotifications': false,
      'pushNotifications': false,
      'adminAlerts': true,
      'adminSessionTimeoutMinutes': 60,
      'requireMfa': false,
      'passwordPolicy': 'Minimum 7 characters',
      'auditLogging': true,
      'irisEnabled': true,
      'automaticAnomalyDetection': true,
      'occupancyPrediction': false,
      'fraudDetection': false,
      'firebaseStatus': 'connected',
      'googleMapsStatus': 'not_configured',
      'emailProviderStatus': 'not_configured',
    };
  }
}
