import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/password_rules.dart';

void main() {
  group('PasswordRules', () {
    test('a strong password meets every rule', () {
      expect(PasswordRules.isStrong('NutriPal2026'), isTrue);
      expect(
        PasswordRules.check('NutriPal2026').every((PasswordRule r) => r.met),
        isTrue,
      );
    });

    test('weak passwords are rejected', () {
      expect(PasswordRules.isStrong('Short1'), isFalse); // too short
      expect(PasswordRules.isStrong('nutripal2026'), isFalse); // no uppercase
      expect(PasswordRules.isStrong('NUTRIPAL2026'), isFalse); // no lowercase
      expect(PasswordRules.isStrong('NutriPalApp'), isFalse); // no number
    });

    test('form validation', () {
      expect(
        PasswordRules.validate(
          currentPassword: '',
          newPassword: 'NutriPal2026',
          confirmPassword: 'NutriPal2026',
        ),
        'Please complete all fields.',
      );

      expect(
        PasswordRules.validate(
          currentPassword: 'OldPass123',
          newPassword: 'weak',
          confirmPassword: 'weak',
        ),
        contains('requirements'),
      );

      expect(
        PasswordRules.validate(
          currentPassword: 'NutriPal2026',
          newPassword: 'NutriPal2026',
          confirmPassword: 'NutriPal2026',
        ),
        contains('different'),
      );

      expect(
        PasswordRules.validate(
          currentPassword: 'OldPass123',
          newPassword: 'NutriPal2026',
          confirmPassword: 'NutriPal2027',
        ),
        'New passwords do not match.',
      );

      expect(
        PasswordRules.validate(
          currentPassword: 'OldPass123',
          newPassword: 'NutriPal2026',
          confirmPassword: 'NutriPal2026',
        ),
        isNull,
      );
    });
  });
}
