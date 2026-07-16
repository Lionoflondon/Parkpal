import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase/parkpal_firebase_options.dart';

class ParkPalAuthService {
  ParkPalAuthService({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  Future<FirebaseAuth> auth() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
    }
    return _auth ?? FirebaseAuth.instance;
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
