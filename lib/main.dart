import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/parkpal_app.dart';
import 'firebase/parkpal_firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: ParkPalFirebaseOptions.current);
  if (const String.fromEnvironment('PARKPAL_ENV') == 'staging') {
    const siteKey = String.fromEnvironment('PARKPAL_STAGING_APPCHECK_SITE_KEY');
    if (!kIsWeb || siteKey.isEmpty) {
      throw StateError('ParkPal staging web App Check site key and web target are required.');
    }
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider(siteKey),
    );
  }
  runApp(const ParkPalApp());
}
