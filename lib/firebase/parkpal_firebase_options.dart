import 'package:firebase_core/firebase_core.dart';

class ParkPalFirebaseOptions {
  const ParkPalFirebaseOptions._();

  static const _environment = String.fromEnvironment(
    'PARKPAL_ENV',
    defaultValue: 'production',
  );

  static FirebaseOptions get current {
    if (_environment != 'staging') return web;
    const projectId = String.fromEnvironment('PARKPAL_STAGING_PROJECT_ID');
    const apiKey = String.fromEnvironment('PARKPAL_STAGING_FIREBASE_API_KEY');
    const appId = String.fromEnvironment('PARKPAL_STAGING_FIREBASE_APP_ID');
    const messagingSenderId = String.fromEnvironment('PARKPAL_STAGING_FIREBASE_SENDER_ID');
    const authDomain = String.fromEnvironment('PARKPAL_STAGING_FIREBASE_AUTH_DOMAIN');
    const storageBucket = String.fromEnvironment('PARKPAL_STAGING_FIREBASE_STORAGE_BUCKET');
    if ([projectId, apiKey, appId, messagingSenderId, authDomain, storageBucket]
        .any((value) => value.isEmpty) || !projectId.startsWith('parkpal-')) {
      throw StateError('Complete the isolated ParkPal staging Firebase configuration before starting the app.');
    }
    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain,
      storageBucket: storageBucket,
    );
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyC9BFRVS1njHVmso670xBxQI9PJ3ZCOl6Y',
    appId: '1:662337727090:web:c525da2e8eaece9ebab0eb',
    messagingSenderId: '662337727090',
    projectId: 'parkpal-prod',
    authDomain: 'parkpal-prod.firebaseapp.com',
    storageBucket: 'parkpal-prod.firebasestorage.app',
  );
}
