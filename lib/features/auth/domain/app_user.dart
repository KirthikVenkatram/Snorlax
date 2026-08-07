import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class AppUser {
  const AppUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  factory AppUser.fromFirebaseUser(fb_auth.User user) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }
}
