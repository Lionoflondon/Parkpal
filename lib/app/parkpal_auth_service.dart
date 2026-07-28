import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase/parkpal_firebase_options.dart';

class ParkPalAuthService {
  ParkPalAuthService({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;
  static bool _localPersistenceConfigured = false;

  Future<FirebaseAuth> auth() async {
    if (_auth != null) return _auth;

    try {
      Firebase.app();
    } catch (_) {
      await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
    }

    final firebaseAuth = FirebaseAuth.instance;
    if (kIsWeb && !_localPersistenceConfigured) {
      await firebaseAuth.setPersistence(Persistence.LOCAL);
      _localPersistenceConfigured = true;
    }
    return firebaseAuth;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final firebaseAuth = await auth();
    return firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createAccount({
    required String email,
    required String password,
  }) async {
    final firebaseAuth = await auth();
    return firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    final firebaseAuth = await auth();
    await firebaseAuth.signOut();
  }

  Stream<User?> authStateChanges() async* {
    final firebaseAuth = await auth();
    yield* firebaseAuth.authStateChanges();
  }
}
