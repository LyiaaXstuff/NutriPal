import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/name_rules.dart';

void main() {
  group('NameRules.validate', () {
    test('letters and spaces are accepted', () {
      expect(NameRules.validate('Audrylyia'), isNull);
      expect(NameRules.validate('Siti Aisyah'), isNull);
      expect(NameRules.validate('  Audry   Lyia  '), isNull);
      expect(NameRules.validate('Zoë'), isNull);
      expect(NameRules.validate('美玲'), isNull);
    });

    test("apostrophes and hyphens between letters are accepted", () {
      expect(NameRules.validate("Nur'ain"), isNull);
      expect(NameRules.validate('Nur’ain'), isNull);
      expect(NameRules.validate('Siti-Aisyah'), isNull);
      expect(NameRules.validate("Mary-Jane O'Neil"), isNull);
    });

    test('misplaced apostrophes and hyphens are rejected', () {
      expect(NameRules.validate('-Siti'), contains('between letters'));
      expect(NameRules.validate('Siti-'), contains('between letters'));
      expect(NameRules.validate("Nur''ain"), contains('between letters'));
      expect(NameRules.validate('Siti - Aisyah'), contains('between letters'));
    });

    test('numbers, symbols and emoji are rejected', () {
      expect(NameRules.validate('Audry123'), isNotNull);
      expect(NameRules.validate('Audry_99'), isNotNull);
      expect(NameRules.validate('Nur@Ain'), isNotNull);
      expect(NameRules.validate('Audry 😊'), isNotNull);
    });

    test('empty, too short and too long', () {
      expect(NameRules.validate('   '), 'Please enter your name or nickname.');
      expect(NameRules.validate('A'), contains('at least'));
      expect(NameRules.validate('A' * 31), contains('at most'));
    });

    test('normalize trims, collapses spaces and straightens apostrophes', () {
      expect(NameRules.normalize('  Audry   Lyia  '), 'Audry Lyia');
      expect(NameRules.normalize('Nur’ain'), "Nur'ain");
    });
  });

  group('NameRules.inputFormatters', () {
    String type(String text) {
      TextEditingValue value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );

      for (final TextInputFormatter formatter in NameRules.inputFormatters) {
        value = formatter.formatEditUpdate(TextEditingValue.empty, value);
      }

      return value.text;
    }

    test('numbers and symbols cannot be typed or pasted', () {
      expect(type('Audry123!@#'), 'Audry');
      expect(type('Siti_Aisyah 2'), 'SitiAisyah ');
      expect(type("Nur'ain-1!"), "Nur'ain-");
    });
  });
}
