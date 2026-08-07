import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../domain/app_user.dart';

class AuthRepository {
  // (kept as a regular assignment, not an initializing formal, so the
  // public parameter name stays `firebaseAuth` while the backing field
  // stays private as `_firebaseAuth`)
  AuthRepository({
    required fb_auth.FirebaseAuth firebaseAuth,
    GoogleSignIn? googleSignIn,
    // ignore: prefer_initializing_formals
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInitialization;

  Future<void> _ensureGoogleSignInInitialized() {
    return _googleSignInInitialization ??= _googleSignIn.initialize();
  }

  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(
          (user) => user == null ? null : AppUser.fromFirebaseUser(user),
        );
  }

  Future<AppUser?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    try {
      final googleAccount = await _googleSignIn.authenticate();
      final idToken = googleAccount.authentication.idToken;
      final credential = fb_auth.GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      return user == null ? null : AppUser.fromFirebaseUser(user);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // user cancelled
      }
      rethrow;
    }
  }

  Future<AppUser?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final oauthCredential = fb_auth.OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(oauthCredential);
    final user = userCredential.user;
    return user == null ? null : AppUser.fromFirebaseUser(user);
  }

  Future<void> signOut() async {
    if (_googleSignInInitialization != null) {
      await _googleSignIn.signOut();
    }
    await _firebaseAuth.signOut();
  }
}
