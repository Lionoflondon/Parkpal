import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase/parkpal_firebase_options.dart';

typedef ParkPalAuthTrace = void Function(String message);

class ParkPalAuthService {
  ParkPalAuthService({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;
  static bool _localPersistenceConfigured = false;

  Future<FirebaseAuth> auth({ParkPalAuthTrace? trace}) async {
    if (_auth != null) return _auth;

    _trace(
      trace,
      'auth(): starting. '
      'targetProject=${ParkPalFirebaseOptions.web.projectId}, '
      'authDomain=${ParkPalFirebaseOptions.web.authDomain}',
    );
    if (kDebugMode) {
      debugPrint(
        'ParkPal auth init: '
        'targetProject=${ParkPalFirebaseOptions.web.projectId}, '
        'authDomain=${ParkPalFirebaseOptions.web.authDomain}',
      );
    }

    FirebaseApp app;
    try {
      app = Firebase.app();
      _trace(
        trace,
        'auth(): Firebase already initialized. '
        'project=${app.options.projectId}, '
        'appId=${app.options.appId}',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal auth init skipped: project=${app.options.projectId}, '
          'appId=${app.options.appId}',
        );
      }
    } catch (error) {
      _trace(trace, 'auth(): Firebase.initializeApp starting');
      app = await Firebase.initializeApp(options: ParkPalFirebaseOptions.web);
      _trace(
        trace,
        'auth(): Firebase.initializeApp complete. '
        'project=${app.options.projectId}, '
        'appId=${app.options.appId}',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal auth init complete: project=${app.options.projectId}, '
          'appId=${app.options.appId}',
        );
      }
    }

    _trace(trace, 'auth(): requesting FirebaseAuth.instance');
    final firebaseAuth = FirebaseAuth.instance;
    if (kIsWeb && !_localPersistenceConfigured) {
      _trace(trace, 'auth(): setting Persistence.LOCAL');
      if (kDebugMode) {
        debugPrint('ParkPal auth persistence: setting Persistence.LOCAL');
      }
      try {
        await firebaseAuth.setPersistence(Persistence.LOCAL);
        _localPersistenceConfigured = true;
        _trace(trace, 'auth(): Persistence.LOCAL succeeded');
        if (kDebugMode) {
          debugPrint('ParkPal auth persistence: Persistence.LOCAL succeeded');
        }
      } catch (error, stackTrace) {
        _trace(
          trace,
          'auth(): Persistence.LOCAL threw ${error.runtimeType}: $error',
        );
        if (kDebugMode) {
          debugPrint(
            'ParkPal auth persistence exception: '
            'type=${error.runtimeType}, value=$error',
          );
          debugPrint('ParkPal auth persistence stack trace: $stackTrace');
        }
        rethrow;
      }
    } else {
      _trace(
        trace,
        'auth(): Persistence.LOCAL skipped. '
        'kIsWeb=$kIsWeb configured=$_localPersistenceConfigured',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal auth persistence: skipped '
          'kIsWeb=$kIsWeb configured=$_localPersistenceConfigured',
        );
      }
    }

    _trace(
      trace,
      'auth(): currentUser before sign-in = '
      '${_debugUser(firebaseAuth.currentUser)}',
    );
    if (kDebugMode) {
      debugPrint(
        'ParkPal auth currentUser before sign-in: '
        '${_debugUser(firebaseAuth.currentUser)}',
      );
    }
    return firebaseAuth;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
    ParkPalAuthTrace? trace,
  }) async {
    _trace(trace, 'signIn(): requesting auth()');
    final firebaseAuth = await auth(trace: trace);
    _trace(
      trace,
      'signIn(): signInWithEmailAndPassword reached. '
      'email=${email.trim()}, '
      'currentUserBefore=${_debugUser(firebaseAuth.currentUser)}',
    );
    if (kDebugMode) {
      debugPrint(
        'ParkPal sign-in reached: email=${email.trim()}, '
        'currentUserBefore=${_debugUser(firebaseAuth.currentUser)}',
      );
    }
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      _trace(
        trace,
        'signIn(): UserCredential returned. '
        'credentialUser=${_debugUser(credential.user)}, '
        'currentUserAfter=${_debugUser(firebaseAuth.currentUser)}',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal sign-in returned UserCredential: '
          'credentialUser=${_debugUser(credential.user)}, '
          'currentUserAfter=${_debugUser(firebaseAuth.currentUser)}',
        );
      }
      return credential;
    } on FirebaseAuthException catch (error, stackTrace) {
      _trace(
        trace,
        'signIn(): FirebaseAuthException thrown. '
        'code=${error.code}, message=${error.message}, '
        'runtimeType=${error.runtimeType}',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal sign-in FirebaseAuthException: '
          'code=${error.code}, message=${error.message}, '
          'runtimeType=${error.runtimeType}',
        );
        debugPrint(
            'ParkPal sign-in FirebaseAuthException stack trace: $stackTrace');
      }
      rethrow;
    } catch (error, stackTrace) {
      _trace(
        trace,
        'signIn(): raw exception thrown. '
        'runtimeType=${error.runtimeType}, value=$error',
      );
      if (kDebugMode) {
        debugPrint(
          'ParkPal sign-in raw exception: '
          'runtimeType=${error.runtimeType}, value=$error',
        );
        debugPrint('ParkPal sign-in raw stack trace: $stackTrace');
      }
      rethrow;
    }
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
    await for (final user in firebaseAuth.authStateChanges()) {
      if (kDebugMode) {
        debugPrint('ParkPal auth state listener fired: ${_debugUser(user)}');
      }
      yield user;
    }
  }

  String _debugUser(User? user) {
    if (user == null) return 'null';
    return 'uid=${user.uid}, email=${user.email}, anonymous=${user.isAnonymous}';
  }

  void _trace(ParkPalAuthTrace? trace, String message) {
    trace?.call(message);
  }
}
