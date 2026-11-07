import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

// =======================================================
// AUTH SERVICE
// =======================================================
//
// Account actions backed by Firebase Authentication
// (project nutripal-fyp). Screens call these methods and
// show AuthServiceException.message to the user; they
// never talk to Firebase directly.
// =======================================================

class AuthServiceException implements Exception {
  final String message;

  const AuthServiceException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static User? get _user =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;

  /// Email of the signed-in user, or null.
  static String? get currentEmail => _user?.email;

  /// True when the signed-in user has an email + password
  /// login (not only Google sign-in).
  static bool get hasPasswordLogin =>
      _user?.providerData.any(
        (UserInfo info) => info.providerId == EmailAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// True when someone is signed in.
  static bool get isSignedIn => _user != null;

  // =====================================================
  // REGISTER (email + password)
  // =====================================================

  static Future<void> register({
    required String email,
    required String password,
  }) async {
    _requireFirebase();

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  // =====================================================
  // LOG IN (email + password)
  // =====================================================

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _requireFirebase();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error, signingIn: true));
    }
  }

  // =====================================================
  // GOOGLE (sign up and log in are the same action)
  // =====================================================
  //
  // Uses the phone's own Google account picker (Android
  // Credential Manager) and passes the Google ID token to
  // Firebase. The browser-based flow is not used: on many
  // Android browsers it fails with "missing initial state".
  //
  // Returns false when the user closed the account picker,
  // so the screen can stay quiet instead of showing an
  // error.
  // =====================================================

  // OAuth "web client" of project nutripal-fyp (client_type 3
  // in android/app/google-services.json). Not a secret: it
  // tells Google which Firebase project the ID token is for.
  static const String _googleServerClientId =
      '1071932117427-1aionfnrru1ag02eflt8bdnl6ahvvvqe.apps.googleusercontent.com';

  static bool _googleReady = false;

  static Future<void> _initGoogle() async {
    if (_googleReady) return;

    await GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId,
    );

    _googleReady = true;
  }

  static Future<bool> signInWithGoogle() async {
    _requireFirebase();

    try {
      await _initGoogle();

      final GoogleSignInAccount account =
          await GoogleSignIn.instance.authenticate();

      final String? idToken = account.authentication.idToken;

      if (idToken == null) {
        throw const AuthServiceException(
          'Google sign-in did not return an ID token. Please try again.',
        );
      }

      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );

      return true;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;

      throw AuthServiceException(
        'Google sign-in failed (${error.code.name}). Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }
  }

  // =====================================================
  // FORGOT PASSWORD (from the login screen)
  // =====================================================

  static Future<void> sendPasswordResetTo(String email) async {
    _requireFirebase();

    final String address = email.trim();

    if (address.isEmpty) {
      throw const AuthServiceException(
        'Enter your email address first, then tap Forgot Password.',
      );
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
    } on FirebaseAuthException catch (error) {
      // Do not reveal whether an account exists for this
      // email (Firebase may also hide it).
      if (error.code == 'user-not-found') return;

      throw AuthServiceException(_messageFor(error));
    }
  }

  // =====================================================
  // LOG OUT
  // =====================================================

  static Future<void> signOut() async {
    if (Firebase.apps.isEmpty) return;

    // Also forget the Google account, so the account picker
    // appears again next time.
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Not signed in with Google: nothing to do.
      }
    }

    await FirebaseAuth.instance.signOut();
  }

  // =====================================================
  // CHANGE PASSWORD
  // =====================================================
  //
  // Firebase only allows a password change shortly after
  // signing in, so the user is first re-authenticated with
  // the current password. This also proves that the
  // person holding the phone knows the old password.
  // =====================================================

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User user = _signedInUser();

    final String? email = user.email;

    if (email == null || email.isEmpty) {
      throw const AuthServiceException(
        'This account has no email address, so its password cannot be changed here.',
      );
    }

    if (!hasPasswordLogin) {
      throw const AuthServiceException(
        'You sign in with Google, so there is no NutriPal password to change. '
        'You can change your password in your Google account.',
      );
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: email,
          password: currentPassword,
        ),
      );

      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    } catch (_) {
      throw const AuthServiceException(
        'Your password could not be changed. Please try again.',
      );
    }
  }

  // =====================================================
  // FORGOT CURRENT PASSWORD
  // =====================================================

  static Future<String> sendPasswordReset() async {
    final User user = _signedInUser();

    final String? email = user.email;

    if (email == null || email.isEmpty) {
      throw const AuthServiceException(
        'This account has no email address to send a reset link to.',
      );
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }

    return email;
  }

  // =====================================================
  // HELPERS
  // =====================================================

  static void _requireFirebase() {
    if (Firebase.apps.isEmpty) {
      throw const AuthServiceException(
        'Account services are not available right now. Please try again later.',
      );
    }
  }

  static User _signedInUser() {
    _requireFirebase();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const AuthServiceException(
        'Please sign in again before changing your password.',
      );
    }

    return user;
  }

  static String _messageFor(
    FirebaseAuthException error, {
    bool signingIn = false,
  }) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return signingIn
            ? 'Incorrect email or password.'
            : 'Your current password is incorrect.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists for this email. Please log in instead.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a password. '
            'Please log in with your email and password.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled yet.';
      case 'weak-password':
        return 'Your new password is too weak. Please choose a stronger one.';
      case 'requires-recent-login':
        return 'For your security, please sign out and sign in again, then try once more.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your connection and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return signingIn
            ? 'Incorrect email or password.'
            : 'Please sign in again before changing your password.';
      case 'user-mismatch':
        return 'Please sign in again before changing your password.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}
