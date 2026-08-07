import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/features/auth/data/auth_repository.dart';

void main() {
  test('authStateChanges emits null when signed out', () async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    final result = await repository.authStateChanges().first;

    expect(result, isNull);
  });

  test('authStateChanges emits an AppUser when signed in', () async {
    final mockUser = MockUser(uid: 'uid-456', email: 'gym@example.com');
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    final result = await repository.authStateChanges().first;

    expect(result?.uid, 'uid-456');
  });

  test('signOut calls FirebaseAuth.signOut', () async {
    final mockUser = MockUser(uid: 'uid-789');
    final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);
    final repository = AuthRepository(firebaseAuth: mockAuth);

    await repository.signOut();

    expect(mockAuth.currentUser, isNull);
  });
}
