import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/firestore_collections.dart';
import '../../data/models/model_helpers.dart';
import '../../data/models/parkpal_models.dart';
import '../../data/storage_paths.dart';

enum SignCaptureFailureReason {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
}

class SignCaptureOutcome {
  const SignCaptureOutcome._({
    required this.isSuccess,
    this.latitude,
    this.longitude,
    this.gpsAccuracyMeters,
    this.gpsCapturedAt,
    this.failureReason,
  });

  const SignCaptureOutcome.success({
    required double latitude,
    required double longitude,
    required double gpsAccuracyMeters,
    required DateTime gpsCapturedAt,
  }) : this._(
          isSuccess: true,
          latitude: latitude,
          longitude: longitude,
          gpsAccuracyMeters: gpsAccuracyMeters,
          gpsCapturedAt: gpsCapturedAt,
        );

  const SignCaptureOutcome.failure(SignCaptureFailureReason reason)
      : this._(
          isSuccess: false,
          failureReason: reason,
        );

  final bool isSuccess;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyMeters;
  final DateTime? gpsCapturedAt;
  final SignCaptureFailureReason? failureReason;
}

class SignCaptureService {
  SignCaptureService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage;

  static const maxGpsAccuracyMeters = 20.0;
  static const maxGpsAge = Duration(minutes: 2);

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;
  final FirebaseStorage? _storage;

  Future<SignCaptureOutcome> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const SignCaptureOutcome.failure(
          SignCaptureFailureReason.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const SignCaptureOutcome.failure(
          SignCaptureFailureReason.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const SignCaptureOutcome.failure(
          SignCaptureFailureReason.permissionDeniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 20),
        ),
      );

      return SignCaptureOutcome.success(
        latitude: position.latitude,
        longitude: position.longitude,
        gpsAccuracyMeters: position.accuracy,
        gpsCapturedAt: position.timestamp,
      );
    } on TimeoutException {
      return const SignCaptureOutcome.failure(SignCaptureFailureReason.timeout);
    } catch (_) {
      return const SignCaptureOutcome.failure(SignCaptureFailureReason.timeout);
    }
  }

  Future<bool> submit({
    required XFile photo,
    required double latitude,
    required double longitude,
    required double gpsAccuracyMeters,
    required DateTime gpsCapturedAt,
    required String streetName,
    required String borough,
    required String council,
    required String postcode,
    String? restrictionType,
    String? activeHours,
    List<String> activeDays = const [],
    int? maxStayMinutes,
    bool? parkingAllowed,
    bool? loadingAllowed,
    bool? permitRequired,
    bool? redRoute,
    bool? busLane,
    bool? schoolStreet,
    String? notes,
  }) async {
    try {
      if (!_hasValidGps(
        latitude: latitude,
        longitude: longitude,
        gpsAccuracyMeters: gpsAccuracyMeters,
        gpsCapturedAt: gpsCapturedAt,
      )) {
        return false;
      }

      final firestore = await _safeFirestore();
      final auth = await _safeAuth();
      final storage = await _safeStorage();
      if (firestore == null || auth == null || storage == null) return false;

      final user = await _ensureUser(auth);
      if (user == null) return false;

      final signId = firestore.collection(ParkPalCollections.signs).doc().id;
      final originalPath = ParkPalStoragePaths.signOriginal(signId);
      final thumbnailPath = ParkPalStoragePaths.signThumbnail(signId);
      final bytes = await photo.readAsBytes();

      final originalRef = storage.ref(originalPath);
      final thumbnailRef = storage.ref(thumbnailPath);
      await originalRef.putData(
          bytes, SettableMetadata(contentType: photo.mimeType));
      // TODO: Generate real thumbnail in a later pass.
      await thumbnailRef.putData(
          bytes, SettableMetadata(contentType: photo.mimeType));

      final originalPhotoUrl = await originalRef.getDownloadURL();
      final thumbnailPhotoUrl = await thumbnailRef.getDownloadURL();

      final sign = ParkPalSign(
        signId: signId,
        photoUrl: originalPhotoUrl,
        thumbnailUrl: thumbnailPhotoUrl,
        capturedByUserId: user.uid,
        capturedByRole: CapturedByRole.pioneer,
        capturedAt: FieldValue.serverTimestamp(),
        geoPoint: ParkPalGeoPoint(latitude: latitude, longitude: longitude),
        latitude: latitude,
        longitude: longitude,
        streetName: streetName.trim(),
        borough: borough.trim(),
        council: council.trim(),
        postcode: postcode.trim(),
        rawText: notes?.trim(),
        restrictionType: restrictionType,
        activeDays: activeDays,
        activeHours: activeHours?.trim(),
        maxStayMinutes: maxStayMinutes,
        loadingAllowed: loadingAllowed,
        parkingAllowed: parkingAllowed,
        permitRequired: permitRequired,
        redRoute: redRoute,
        busLane: busLane,
        schoolStreet: schoolStreet,
        verificationStatus: VerificationStatus.pending,
        source: SignSource.user_photo,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      );

      await firestore.collection(ParkPalCollections.signs).doc(signId).set({
        ...sign.toJson(),
        'originalPhotoUrl': originalPhotoUrl,
        'thumbnailPhotoUrl': thumbnailPhotoUrl,
        'gpsAccuracyMeters': gpsAccuracyMeters,
        'gpsCapturedAt': Timestamp.fromDate(gpsCapturedAt),
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<FirebaseFirestore?> _safeFirestore() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return _firestore ?? FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<FirebaseAuth?> _safeAuth() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return _auth ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  Future<FirebaseStorage?> _safeStorage() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return _storage ?? FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  Future<User?> _ensureUser(FirebaseAuth auth) async {
    if (auth.currentUser != null) return auth.currentUser;
    final credential = await auth.signInAnonymously();
    return credential.user;
  }

  bool _hasValidGps({
    required double latitude,
    required double longitude,
    required double gpsAccuracyMeters,
    required DateTime gpsCapturedAt,
  }) {
    if (latitude == 0 && longitude == 0) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (gpsAccuracyMeters > maxGpsAccuracyMeters) return false;
    if (DateTime.now().difference(gpsCapturedAt).abs() > maxGpsAge) {
      return false;
    }
    return true;
  }
}
