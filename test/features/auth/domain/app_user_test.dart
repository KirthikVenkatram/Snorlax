import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/auth/domain/app_user.dart';

void main() {
  test('AppUser.fromFirebaseUser maps uid, email, and displayName', () {
    final firebaseUser = MockUser(
      uid: 'uid-123',
      email: 'trainer@example.com',
      displayName: 'Ash Ketchum',
    );

    final appUser = AppUser.fromFirebaseUser(firebaseUser);

    expect(appUser.uid, 'uid-123');
    expect(appUser.email, 'trainer@example.com');
    expect(appUser.displayName, 'Ash Ketchum');
  });
}
