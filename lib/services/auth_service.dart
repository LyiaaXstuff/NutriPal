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

  // Firebase error code, or 'not-registered' /
  // 'already-registered' for the Google checks. Lets a
  // screen add a "Register" or "Log in" button.
  final String? code;

  const AuthServiceException(this.message, {this.code});

  /// True when the account does not exist (or the email /
  /// password do not match one).
  bool get suggestsRegister => const <String>{
        'not-registered',
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
      }.contains(code);

  /// True when the account already exists (Register screen).
  bool get suggestsLogin => const <String>{
        'already-registered',
        'email-already-in-use',
      }.contains(code);

  @override
  String toString() => message;
}

/// Which screen started Google sign-in.
enum GoogleAuthMode { login, register }

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

  /// True when the signed-in user signs in with Google.
  static bool get hasGoogleLogin =>
      _user?.providerData.any(
        (UserInfo info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
      ) ??
      false;

  /// Firebase uid of the signed-in user, or null.
  static String? get currentUserId => _user?.uid;

  /// True when someone is signed in.
  static bool get isSignedIn => _user != null;

  // =====================================================
  // REGISTER (email + password)
  // =====================================================
  //
  // Creates the account and emails a verification link.
  // The user stays signed in so the "Check your email"
  // screen can resend the link and check whether it was
  // tapped, but the app is not opened until the email is
  // verified.
  //
  // Returns false when the account was created but the
  // email could not be sent (for example no connection);
  // the user can tap Resend on the next screen.
  // =====================================================

  static Future<bool> register({
    required String email,
    required String password,
  }) async {
    _requireFirebase();

    final UserCredential result;

    try {
      result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error), code: error.code);
    }

    try {
      await result.user?.sendEmailVerification();
      return true;
    } catch (_) {
      return false;
    }
  }

  // =====================================================
  // LOG IN (email + password)
  // =====================================================
  //
  // Returns false when the password is right but the email
  // has not been verified yet. The user stays signed in so
  // the "Check your email" screen can resend the link; the
  // app itself is not opened.
  // =====================================================

  static Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _requireFirebase();

    final UserCredential result;

    try {
      result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        _messageFor(error, signingIn: true),
        code: error.code,
      );
    }

    return result.user?.emailVerified ?? false;
  }

  // =====================================================
  // EMAIL VERIFICATION
  // =====================================================
  //
  // Firebase sends a link (not a code). Tapping it marks
  // the email as verified on Firebase's side; the app sees
  // the change after reloading the user.
  // Google accounts are already verified by Google.
  // =====================================================

  /// True when the signed-in user has verified their email.
  static bool get isEmailVerified => _user?.emailVerified ?? false;

  /// Sends the verification link again.
  static Future<void> sendVerificationEmail() async {
    _requireFirebase();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const AuthServiceException(
        'Please log in again to get a new verification email.',
      );
    }

    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'too-many-requests') {
        throw const AuthServiceException(
          'A verification email was sent recently. '
          'Please wait a few minutes before asking for another.',
        );
      }

      throw AuthServiceException(_messageFor(error));
    }
  }

  /// Reloads the user from Firebase and returns true when
  /// the verification link has been tapped.
  static Future<bool> checkEmailVerified() async {
    _requireFirebase();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) return false;

    try {
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_messageFor(error));
    }

    final bool verified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (verified) {
      // Refresh the ID token so Cloud Functions see the
      // verified email straight away.
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
      } catch (_) {
        // The old token still works; it refreshes itself.
      }
    }

    return verified;
  }

  /// Deletes an account whose email was never verified
  /// (for example a mistyped address), then signs out, so
  /// the address can be registered again. Verified accounts
  /// are never touched here.
  static Future<void> discardUnverifiedAccount() async {
    if (Firebase.apps.isEmpty) return;

    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null && !user.emailVerified && hasPasswordLogin) {
      try {
        await user.delete();
      } catch (_) {
        // Could not delete (for example offline): the user
        // is still signed out below and can log in later.
      }
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Already signed out.
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
  //
  // Login and Register are kept apart. Firebase creates an
  // account the first time a Google account signs in, so:
  //   GoogleAuthMode.login     a new Google account is NOT
  //                            accepted: the account
  //                            Firebase just made is deleted
  //                            and the user is told to
  //                            register first.
  //   GoogleAuthMode.register  an existing account is not
  //                            set up again: the user is
  //                            told to log in instead.
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

  static Future<bool> signInWithGoogle({
    GoogleAuthMode mode = GoogleAuthMode.login,
  }) async {
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

      final UserCredential result =
          await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );

      final bool isNew = result.additionalUserInfo?.isNewUser ?? false;

      if (mode == GoogleAuthMode.login && isNew) {
        // Undo the account Firebase just created.
        try {
          await result.user?.delete();
        } catch (_) {
          // Could not delete: still signed out below.
        }

        await _forgetGoogle();

        throw const AuthServiceException(
          'There is no NutriPal account for this Google account yet. '
          'Please register first.',
          code: 'not-registered',
        );
      }

      if (mode == GoogleAuthMode.register && !isNew) {
        await _forgetGoogle();

        throw const AuthServiceException(
          'This Google account is already registered. '
          'Please log in instead.',
          code: 'already-registered',
        );
      }

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

  /// Signs out of Firebase and forgets the Google account,
  /// so the account picker appears again next time.
  static Future<void> _forgetGoogle() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Nothing to forget.
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // Already signed out.
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
  // DELETE ACCOUNT
  // =====================================================
  //
  // Permanently deletes the Firebase Authentication account.
  // Firebase only allows this shortly after signing in, so
  // the user confirms first:
  //   email + password  -> current password
  //   Google            -> pick the same Google account
  //
  // Returns false when the user closed the Google account
  // picker (nothing was deleted). On success the user is
  // signed out. Data stored on the phone is removed by the
  // screen (ScanHistoryService.deleteAllForUser).
  // =====================================================

  static Future<bool> deleteAccount({String? password}) async {
    _requireFirebase();

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw const AuthServiceException(
        'Please sign in again, then delete your account.',
      );
    }

    try {
      if (hasPasswordLogin) {
        final String? email = user.email;

        if (password == null || password.isEmpty) {
          throw const AuthServiceException(
            'Enter your password to confirm.',
          );
        }

        if (email == null || email.isEmpty) {
          throw const AuthServiceException(
            'This account has no email address. Please contact support.',
          );
        }

        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: email, password: password),
        );
      } else if (hasGoogleLogin) {
        await _initGoogle();

        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();

        final String? idToken = account.authentication.idToken;

        if (idToken == null) {
          throw const AuthServiceException(
            'Google did not confirm your account. Please try again.',
          );
        }

        await user.reauthenticateWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      await user.delete();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return false;

      throw AuthServiceException(
        'Google confirmation failed (${error.code.name}). Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-mismatch') {
        throw const AuthServiceException(
          'Please choose the Google account you use for NutriPal.',
        );
      }

      if (error.code == 'wrong-password' ||
          error.code == 'invalid-credential' ||
          error.code == 'invalid-login-credentials') {
        throw const AuthServiceException('Your password is incorrect.');
      }

      throw AuthServiceException(_messageFor(error));
    }

    // Forget the Google account and any session left over.
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        // Not signed in with Google: nothing to do.
      }
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // The user no longer exists; nothing to sign out.
    }

    return true;
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
