import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Fetch custom claim role from the Firebase ID token
  Future<String?> getUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      // Force refresh (true) to ensure updated claims are loaded
      IdTokenResult tokenResult = await user.getIdTokenResult(true);
      return tokenResult.claims?['role'] as String?;
    }
    return null;
  }
}
