import 'package:shared_preferences/shared_preferences.dart';

// =======================================================
// ONBOARDING SERVICE
// =======================================================
//
// Remembers on this phone whether the onboarding pages
// have already been shown, so:
//   new user       Splash -> Onboarding -> Login
//   existing user  Splash -> Login
//
// "Seen" is saved when the Login screen first opens
// (after Get Started or Skip), so someone who closes the
// app half-way through onboarding sees it again.
//
// Stored on the phone only: uninstalling the app or
// clearing its data shows onboarding again.
// =======================================================

class OnboardingService {
  OnboardingService._();

  static const String _seenKey = 'nutripal.onboarding_seen.v1';

  /// True when onboarding was already shown on this phone.
  /// Returns false if the setting cannot be read, so a new
  /// user is never sent past onboarding by mistake.
  static Future<bool> hasSeen() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Saves that onboarding has been shown.
  static Future<void> markSeen() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {
      // Not saved: onboarding simply shows once more.
    }
  }
}
