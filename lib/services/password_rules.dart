// =======================================================
// PASSWORD RULES
// =======================================================
//
// The rules a new NutriPal password must meet. Pure Dart
// (no Flutter, no Firebase) so the screen can show them as
// a live checklist and they can be unit tested.
// =======================================================

class PasswordRule {
  final String label;
  final bool met;

  const PasswordRule(this.label, this.met);
}

class PasswordRules {
  PasswordRules._();

  static const int minLength = 8;

  /// Checklist shown under the "New password" field.
  static List<PasswordRule> check(String password) {
    return <PasswordRule>[
      PasswordRule(
        'At least $minLength characters',
        password.length >= minLength,
      ),
      PasswordRule(
        'An uppercase letter (A-Z)',
        RegExp('[A-Z]').hasMatch(password),
      ),
      PasswordRule(
        'A lowercase letter (a-z)',
        RegExp('[a-z]').hasMatch(password),
      ),
      PasswordRule(
        'A number (0-9)',
        RegExp('[0-9]').hasMatch(password),
      ),
    ];
  }

  static bool isStrong(String password) =>
      check(password).every((PasswordRule rule) => rule.met);

  /// First problem with the form, or null when it can be
  /// submitted.
  static String? validate({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      return 'Please complete all fields.';
    }

    if (!isStrong(newPassword)) {
      return 'Your new password does not meet all the requirements.';
    }

    if (newPassword == currentPassword) {
      return 'Your new password must be different from your current password.';
    }

    if (newPassword != confirmPassword) {
      return 'New passwords do not match.';
    }

    return null;
  }
}
