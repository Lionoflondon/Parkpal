import 'dart:async';

import 'package:geolocator/geolocator.dart';

class ParkPalLocationFix {
  const ParkPalLocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime capturedAt;

  String get compactLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  bool get isValid {
    if (latitude == 0 && longitude == 0) return false;
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }
}

enum ParkPalLocationFailure {
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  timeout,
  unavailable,
}

class ParkPalLocationResult {
  const ParkPalLocationResult._({this.fix, this.failure});

  const ParkPalLocationResult.success(ParkPalLocationFix fix)
      : this._(fix: fix);

  const ParkPalLocationResult.failure(ParkPalLocationFailure failure)
      : this._(failure: failure);

  final ParkPalLocationFix? fix;
  final ParkPalLocationFailure? failure;

  bool get isSuccess => fix != null;

  String get customerMessage {
    return switch (failure) {
      ParkPalLocationFailure.serviceDisabled =>
        'Enable location services to use GPS parking checks.',
      ParkPalLocationFailure.permissionDenied =>
        'ParkPal needs location access to check parking near you.',
      ParkPalLocationFailure.permissionDeniedForever =>
        'Location access is blocked. Enable it in browser or device settings.',
      ParkPalLocationFailure.timeout =>
        'ParkPal could not get your location in time. Try again.',
      ParkPalLocationFailure.unavailable =>
        'GPS lookup is not available on this device or browser.',
      null => '',
    };
  }
}

class ParkPalCurrentLocationService {
  const ParkPalCurrentLocationService();

  Future<ParkPalLocationResult> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const ParkPalLocationResult.failure(
          ParkPalLocationFailure.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const ParkPalLocationResult.failure(
          ParkPalLocationFailure.permissionDenied,
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const ParkPalLocationResult.failure(
          ParkPalLocationFailure.permissionDeniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 18),
        ),
      );
      final fix = ParkPalLocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
      );

      if (!fix.isValid) {
        return const ParkPalLocationResult.failure(
          ParkPalLocationFailure.unavailable,
        );
      }

      return ParkPalLocationResult.success(fix);
    } on TimeoutException {
      return const ParkPalLocationResult.failure(
        ParkPalLocationFailure.timeout,
      );
    } catch (_) {
      return const ParkPalLocationResult.failure(
        ParkPalLocationFailure.unavailable,
      );
    }
  }
}
