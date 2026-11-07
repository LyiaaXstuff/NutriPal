import 'package:flutter/services.dart';

// =======================================================
// NAME / NICKNAME RULES
// =======================================================
//
// A name or nickname may contain letters, single spaces,
// and an apostrophe or hyphen between letters (Nur'ain,
// Siti-Aisyah). No numbers, other symbols or emoji.
//
// "Letters" includes accented and non-Latin letters
// (Zoë, 美玲, முருகன்), so every user can write their name.
//
// Used by the profile setup form and My Account:
//   - inputFormatters stop numbers and symbols as they are
//     typed (or pasted)
//   - validate() checks the final value before saving
// =======================================================

class NameRules {
  NameRules._();

  static const int minLetters = 2;
  static const int maxLength = 30;

  // \p{L} = any letter, \p{M} = accent marks that belong to
  // a letter (needed for Tamil, Hindi...).
  // ' and ’ (the curly apostrophe some keyboards type) and -.
  static final RegExp _allowedCharacter =
      RegExp(r"[\p{L}\p{M} '’-]", unicode: true);

  static final RegExp _onlyAllowedCharacters =
      RegExp(r"^[\p{L}\p{M} '-]+$", unicode: true);

  // Words separated by single spaces; inside a word an
  // apostrophe or hyphen must sit between two letters.
  static final RegExp _validName = RegExp(
    r"^[\p{L}\p{M}]+(?:['-][\p{L}\p{M}]+)*(?: [\p{L}\p{M}]+(?:['-][\p{L}\p{M}]+)*)*$",
    unicode: true,
  );

  static final RegExp _letter = RegExp(r'\p{L}', unicode: true);

  /// Blocks numbers, symbols and emoji while typing.
  static List<TextInputFormatter> get inputFormatters => <TextInputFormatter>[
        FilteringTextInputFormatter.allow(_allowedCharacter),
        LengthLimitingTextInputFormatter(maxLength),
      ];

  /// Trims, turns repeated spaces into one and uses the
  /// plain apostrophe: "  Nur’ain   Lyia " -> "Nur'ain Lyia".
  static String normalize(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('’', "'");

  /// Problem with the name, or null when it is valid.
  static String? validate(String value) {
    final String name = normalize(value);

    if (name.isEmpty) {
      return 'Please enter your name or nickname.';
    }

    if (!_onlyAllowedCharacters.hasMatch(name)) {
      return "Name or nickname can only contain letters, spaces, ' and - "
          '(no numbers or other symbols).';
    }

    if (!_validName.hasMatch(name)) {
      return "An apostrophe (') or hyphen (-) must be between letters, "
          "for example Nur'ain or Siti-Aisyah.";
    }

    if (_letter.allMatches(name).length < minLetters) {
      return 'Name or nickname must have at least $minLetters letters.';
    }

    if (name.length > maxLength) {
      return 'Name or nickname can have at most $maxLength characters.';
    }

    return null;
  }
}
