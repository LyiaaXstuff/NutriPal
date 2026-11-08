import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/progress_dialog.dart';
import 'home_screen.dart';
import 'user_profile_form.dart';

// =======================================================
// AFTER SIGN-IN (email login, Google login, verified email)
// =======================================================
//
// Loads the user's saved profile from Firestore, then:
//
//   profile found        -> Home, with their health areas
//   setup not finished   -> profile setup forms (saved to
//                           Firestore when they finish)
//   could not load       -> stay signed out, with a message
//                           (never open Home with an empty
//                           profile, which could later
//                           overwrite the saved one)
//
// Returns true when the next screen was opened.
// =======================================================

Future<bool> openHomeAfterSignIn(BuildContext context) async {
  final NavigatorState navigator = Navigator.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

  // Do not carry an old message (such as a wrong
  // password) into the next screen.
  messenger.clearSnackBars();

  final ProfileSetupData? profile;

  try {
    profile = await runWithProgress<ProfileSetupData?>(
      context,
      UserProfileService.load,
    );
  } on UserProfileException catch (error) {
    await AuthService.signOut();

    messenger.showSnackBar(
      SnackBar(
        content: Text(error.message),
        backgroundColor: const Color(0xFF4B2E83),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return false;
  }

  if (!navigator.mounted) return false;

  navigator.pushAndRemoveUntil(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          profile == null ? const UserProfileForm() : HomeScreen(data: profile),
    ),
    (Route<dynamic> route) => false,
  );

  if (profile == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text("Let's finish setting up your profile."),
        backgroundColor: Color(0xFF4B2E83),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  return true;
}
