// =======================================================
// NUTRIENT NAME NORMALIZER
// =======================================================
//
// Turns the nutrient name read from a label into one
// consistent English name that NutriPal's health rules can
// rely on:
//
//   "Natrium", "SODIUM", "Natrium / Sodium", "Sodlum"
//     -> "Sodium"
//
// Pipeline:
//
//   raw OCR name
//     -> clean OCR artefacts (bullets, *, stray brackets,
//        unit brackets, colons, extra spaces)
//     -> drop packaging text stuck in front, ONLY when the
//        rest is clearly a known nutrient ("HALAL Lemak")
//     -> look up known English / Bahasa Melayu names,
//        including bilingual "Natrium / Sodium"
//     -> correct only safe OCR spelling errors
//        ("Proteln", "Natriurn")
//     -> canonical name, or the cleaned original name if
//        the nutrient is not in the dictionary
//
// The dictionary is for NAMING ONLY. It never decides
// which nutrients exist: anything the parser extracts is
// kept, known or not ("Pantothenic Acid" stays
// "Pantothenic Acid").
//
// It never changes meaning: Total Sugars, Added Sugars,
// Carbohydrate, Total Fat, Saturated Fat and Cholesterol
// are separate entries and are never matched to each
// other.
//
// Pure Dart: no Flutter imports, unit-testable.
// =======================================================

class NormalizedNutrientName {
  // Exactly what was passed in.
  final String rawName;

  // Artefacts removed, label wording kept
  // ("Jumlah Gula / Total Sugars").
  final String cleanedName;

  // Canonical English name ("Total Sugars"), or the
  // cleaned name in Title Case when the nutrient is not in
  // the dictionary.
  final String canonicalName;

  // True when canonicalName came from the dictionary.
  final bool wasStandardized;

  // True when an OCR spelling error had to be corrected to
  // recognise the name.
  final bool wasCorrected;

  // True when stray characters from a script the phone
  // cannot read (Arabic, Thai...) were removed: "Protein / 3".
  final bool droppedUnreadableText;

  const NormalizedNutrientName({
    required this.rawName,
    required this.cleanedName,
    required this.canonicalName,
    required this.wasStandardized,
    required this.wasCorrected,
    this.droppedUnreadableText = false,
  });

  @override
  String toString() =>
      'NormalizedNutrientName($rawName -> $canonicalName'
      '${wasCorrected ? ', corrected' : ''})';
}

class NutrientNameNormalizer {
  NutrientNameNormalizer._();

  // =====================================================
  // PUBLIC API
  // =====================================================

  /// Canonical name only.
  static String normalize(String rawName) =>
      normalizeDetailed(rawName).canonicalName;

  /// Canonical name plus the cleaned label wording.
  static NormalizedNutrientName normalizeDetailed(String rawName) {
    final String fullyCleaned = clean(rawName);
    String cleaned = _withoutJunkSegments(fullyCleaned);
    final bool dropped = cleaned != fullyCleaned;

    _Match? match = _resolveWithSegments(cleaned);

    // Packaging text in front of a real nutrient name
    // ("MS1500 Asid Lemak Politidaktepu", "CARA Natrium"):
    // dropped only if what remains is a known nutrient.
    if (match == null) {
      final String? stripped = _withoutLeadingJunk(cleaned);

      if (stripped != null) {
        final _Match? strippedMatch = _resolveWithSegments(stripped);

        if (strippedMatch != null) {
          cleaned = stripped;
          match = strippedMatch;
        }
      }
    }

    if (match != null) {
      return NormalizedNutrientName(
        rawName: rawName,
        cleanedName: cleaned,
        canonicalName: match.canonical,
        wasStandardized: true,
        wasCorrected: match.corrected,
        droppedUnreadableText: dropped,
      );
    }

    return NormalizedNutrientName(
      rawName: rawName,
      cleanedName: cleaned,
      canonicalName: _titleCase(cleaned),
      wasStandardized: false,
      wasCorrected: false,
      droppedUnreadableText: dropped,
    );
  }

  // =====================================================
  // 1. CLEAN OCR ARTEFACTS
  // =====================================================

  static String clean(String raw) {
    String t = raw;

    // Unicode dashes / minus to "-".
    t = t.replaceAll(RegExp('[‐-―−]'), '-');

    // Bullets and footnote marks are never part of a name.
    t = t.replaceAll(RegExp('[•·●▪■◦*†‡^~_|]'), ' ');

    // Unit-only brackets: "(g)", "(mg)", "(kcal)".
    t = t.replaceAll(
      RegExp(
        r'[\(\[]\s*(?:g|mg|µg|μg|mcg|ug|kcal|kj|ml|iu|%)\s*[\)\]]',
        caseSensitive: false,
      ),
      ' ',
    );

    // "Omega3" -> "Omega 3".
    t = t.replaceAllMapped(
      RegExp(r'(omega)(\d)', caseSensitive: false),
      (Match m) => '${m[1]} ${m[2]}',
    );

    // "Omega-3", "Omega - 3" -> "Omega 3".
    t = t.replaceAllMapped(
      RegExp(r'([A-Za-z])\s*-\s*(\d)'),
      (Match m) => '${m[1]} ${m[2]}',
    );

    // "mono - unsaturated" -> "mono-unsaturated".
    t = t.replaceAll(RegExp(r'(?<=[A-Za-z])\s+-\s+(?=[A-Za-z])'), '-');

    // Sub-heading words in front of an indented row:
    // "comprising of monounsaturated fatty acid".
    t = t.replaceFirst(
      RegExp(
        r'^\s*(?:comprising(?:\s+of)?|consisting\s+of|of\s+which|including|'
        r'(?:yang\s+)?terdiri\s+daripada|antaranya|termasuk)\b[:\s]*',
        caseSensitive: false,
      ),
      '',
    );

    // Repeated punctuation: "::" -> ":".
    t = t.replaceAllMapped(RegExp(r'([:;,.])\1+'), (Match m) => m[1]!);

    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Edges: stray brackets and punctuation, repeated
    // until nothing changes.
    String previous;

    do {
      previous = t;
      t = _trimEdges(t);
    } while (t != previous);

    // "Natrium/Sodium", "Natrium  /  Sodium" -> " / ".
    t = t.replaceAll(RegExp(r'\s*/\s*'), ' / ');

    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  // =====================================================
  // UNREADABLE SECOND LANGUAGE
  // =====================================================
  //
  // ML Kit's Latin recogniser cannot read Arabic (or Thai,
  // Tamil...). The second-language half of a bilingual
  // name then comes out as a few stray characters:
  //
  //   "Protein / 3", "Fat / Y", "Cholesterol / Ds",
  //   "Magnesium / Ega", "Folic acid (Vitamin B9) / 44"
  //
  // A "/" part that is not a known name and has at most
  // three letters (or only digits) is such a fragment and
  // is dropped. Real names in a second language ("Lemak",
  // "Natrium", "Gula") are longer and are kept.
  // =====================================================

  static bool _isJunkSegment(String segment) {
    final String t = segment.trim();

    if (t.isEmpty) return true;

    // Text really written in another script (from the AI
    // reader, e.g. "بروتين") is kept.
    if (_otherScript.hasMatch(t)) return false;

    if (_resolve(t) != null) return false;

    final int letters = RegExp(r'[A-Za-z]').allMatches(t).length;

    return letters <= 3;
  }

  // Hebrew/Arabic, Tamil, Thai, Japanese kana, CJK, Hangul.
  static final RegExp _otherScript = RegExp(
    '[\u0590-\u08FF\u0B80-\u0BFF\u0E00-\u0E7F'
    '\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]',
  );

  static String _withoutJunkSegments(String cleaned) {
    final List<String> segments = cleaned.split(' / ');

    if (segments.length < 2) return cleaned;

    final List<String> kept =
        segments.where((String s) => !_isJunkSegment(s)).toList();

    // Nothing readable left: keep what was there.
    if (kept.isEmpty) return cleaned;

    return clean(kept.join(' / '));
  }

  static String _trimEdges(String text) {
    String t = text.trim();

    // "(Protein)", "[Vitamin B12]" fully wrapped.
    final RegExpMatch? wrapped =
        RegExp(r'^[\(\[\{]([^\(\)\[\]\{\}]*)[\)\]\}]$').firstMatch(t);

    if (wrapped != null) return wrapped.group(1)!.trim();

    // Unmatched opening bracket at the start: "(Natrium".
    if (RegExp(r'^[\(\[\{]').hasMatch(t) &&
        _count(t, RegExp(r'[\(\[\{]')) > _count(t, RegExp(r'[\)\]\}]'))) {
      return t.substring(1).trim();
    }

    // Unmatched closing bracket at the end: "Protein)".
    if (RegExp(r'[\)\]\}]$').hasMatch(t) &&
        _count(t, RegExp(r'[\)\]\}]')) > _count(t, RegExp(r'[\(\[\{]'))) {
      return t.substring(0, t.length - 1).trim();
    }

    // Leading / trailing punctuation: "- Sodium", ":Carbohydrate",
    // "Protein:", "Total Fat -".
    return t
        .replaceAll(RegExp(r'^[\s:;,.\-/=+>]+'), '')
        .replaceAll(RegExp(r'[\s:;,.\-/=+<]+$'), '');
  }

  static int _count(String text, RegExp pattern) =>
      pattern.allMatches(text).length;

  // =====================================================
  // 2. PACKAGING TEXT IN FRONT OF A NAME
  // =====================================================
  //
  // Up to three leading tokens that are clearly not part of
  // a nutrient name: codes with digits ("MS1500",
  // "D01-11/2012") or packaging words ("HALAL", "CARA").
  // Short nutrient codes such as "B12" are never junk.
  // =====================================================

  static const Set<String> _packagingWords = <String>{
    'halal',
    'cara',
    'hidangan',
    'ms',
    'jakim',
    'tm',
    'lot',
    'exp',
    'mfg',
    'bb',
    'dolphin',
    'friendly',
  };

  static bool _isJunkToken(String token) {
    final String t = token.toLowerCase();

    if (t == '/' || t == '-') return true;

    final String bare = t.replaceAll(RegExp(r'[^a-z0-9]'), '');

    // "HALAL", "CARA"
    if (_packagingWords.contains(bare)) return true;

    final bool hasDigit = RegExp(r'\d').hasMatch(t);

    // "B12", "D3", "3" are nutrient codes, not junk.
    final bool nutrientCode =
        RegExp(r'^[a-z]?\d{1,2}$').hasMatch(t.replaceAll(RegExp(r'[^a-z0-9]'), ''));

    return hasDigit && t.length >= 3 && !nutrientCode;
  }

  static String? _withoutLeadingJunk(String cleaned) {
    final List<String> tokens = cleaned.split(' ');

    int junk = 0;

    while (junk < tokens.length - 1 && junk < 3 && _isJunkToken(tokens[junk])) {
      junk++;
    }

    if (junk == 0) return null;

    return clean(tokens.sublist(junk).join(' '));
  }

  // =====================================================
  // 3. BILINGUAL NAMES ("Natrium / Sodium")
  // =====================================================

  static _Match? _resolveWithSegments(String cleaned) {
    if (cleaned.isEmpty) return null;

    final _Match? whole = _resolve(cleaned);

    if (whole != null) return whole;

    final List<String> segments = cleaned
        .split(' / ')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    if (segments.length < 2) return null;

    String? canonical;
    bool corrected = false;

    for (final String segment in segments) {
      final _Match? match = _resolve(segment);

      if (match == null) {
        // A real unknown word in one language: not
        // confident enough to standardise the whole name.
        if (RegExp(r'[A-Za-z]{3,}').hasMatch(segment)) return null;

        continue;
      }

      // The two languages disagree: keep the label wording
      // rather than pick one meaning.
      if (canonical != null && canonical != match.canonical) return null;

      canonical = match.canonical;
      corrected = corrected || match.corrected;
    }

    return canonical == null ? null : _Match(canonical, corrected);
  }

  // =====================================================
  // 4. ONE NAME -> CANONICAL
  // =====================================================

  static _Match? _resolve(String phrase) {
    final String key = _key(phrase);

    if (key.isEmpty) return null;

    // Exact dictionary entry.
    final String? exact = _aliasIndex[key];

    if (exact != null) return _Match(exact, false);

    // Vitamins by pattern: "Vitamin B 12", "Vit. C".
    final String? vitamin = _vitamin(key);

    if (vitamin != null) return _Match(vitamin, false);

    // "Thiamin (Vitamin B1)", "Folic acid Vitamin B9": the
    // name and the vitamin code must agree.
    final RegExpMatch? withCode =
        RegExp(r'^(.+?) (?:vitamin|vit) ([a-z]\d{0,2})$').firstMatch(key);

    if (withCode != null) {
      final _Match? base = _resolve(withCode[1]!);
      final String? code = _vitamin('vitamin ${withCode[2]}');

      // Same vitamin: keep the more specific printed name
      // ("Folic Acid (Vitamin B9)" stays Folic Acid).
      if (base != null &&
          code != null &&
          (base.canonical == code ||
              (_vitaminGroup[base.canonical] != null &&
                  _vitaminGroup[base.canonical] == _vitaminGroup[code]))) {
        return base;
      }
    }

    // OCR look-alike letters: l/1/I -> i, rn -> m, 0 -> o.
    final String skeleton = _skeleton(key);
    final String? lookAlike = _skeletonIndex[skeleton];

    if (lookAlike != null) return _Match(lookAlike, true);

    final String? lookAlikeVitamin = _vitamin(_skeletonToText(skeleton));

    if (lookAlikeVitamin != null) return _Match(lookAlikeVitamin, true);

    // One (or for long names two) letters wrong, digits
    // identical, unique best match, never for short words
    // or vitamins.
    final String? close = _closeMatch(skeleton);

    if (close != null) return _Match(close, true);

    return null;
  }

  static String _key(String text) {
    return text
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'[^a-z0-9µμ ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _skeleton(String key) {
    return key
        .replaceAll('rn', 'm')
        .replaceAll('vv', 'w')
        .replaceAll(RegExp('[l1|]'), 'i')
        .replaceAll('0', 'o');
  }

  // A skeleton only maps letters, so it can still be read
  // as text for the vitamin pattern.
  static String _skeletonToText(String skeleton) =>
      skeleton.replaceAllMapped(RegExp(r'b(i+)(\d*)'), (Match m) {
        // "vitamin bi2" (from "b12") -> "vitamin b12"
        final String ones = '1' * m[1]!.length;
        return 'b$ones${m[2]}';
      });

  static String? _vitamin(String key) {
    final RegExpMatch? m = RegExp(
      r'^(?:vitamin|vit|vitamine)\s*([a-z])\s*(\d{0,2})$',
    ).firstMatch(key);

    if (m == null) return null;

    final String code = '${m[1]!.toUpperCase()}${m[2]}';

    // "Vitamin B7" is Biotin; "Vitamin B9" stays Vitamin B9.
    final String? named = _aliasIndex['vitamin ${code.toLowerCase()}'];

    if (named != null) return named;

    return _vitaminCodes.contains(code) ? 'Vitamin $code' : null;
  }

  static const Set<String> _vitaminCodes = <String>{
    'A', 'B1', 'B2', 'B3', 'B5', 'B6', 'B12', 'C', 'D', 'E', 'K',
  };

  static String? _closeMatch(String skeleton) {
    final int length = skeleton.replaceAll(' ', '').length;

    if (length < 6) return null;

    final int allowed = length >= 10 ? 2 : 1;
    final String digits = skeleton.replaceAll(RegExp(r'[^0-9]'), '');

    String? best;
    int bestDistance = allowed + 1;
    bool tie = false;

    _skeletonIndex.forEach((String aliasSkeleton, String canonical) {
      if (aliasSkeleton.startsWith('vitamin')) return;

      if (aliasSkeleton.replaceAll(RegExp(r'[^0-9]'), '') != digits) return;

      if ((aliasSkeleton.length - skeleton.length).abs() > 1) return;

      // Same first letter (or an OCR look-alike such as
      // M/N): "Unsaturated" must never become "Saturated".
      if (!_sameStart(skeleton, aliasSkeleton)) return;

      final int d = _editDistance(skeleton, aliasSkeleton);

      if (d < bestDistance) {
        best = canonical;
        bestDistance = d;
        tie = false;
      } else if (d == bestDistance && canonical != best) {
        tie = true;
      }
    });

    return (best != null && !tie) ? best : null;
  }

  static const List<String> _lookAlikeStarts = <String>[
    'mn', 'nh', 'il', 'oc', 'ec', 'uv', 'bh', 'kh',
  ];

  static bool _sameStart(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    if (a[0] == b[0]) return true;

    return _lookAlikeStarts.any(
      (String pair) =>
          (pair[0] == a[0] && pair[1] == b[0]) ||
          (pair[1] == a[0] && pair[0] == b[0]),
    );
  }

  static int _editDistance(String a, String b) {
    List<int> previous = List<int>.generate(b.length + 1, (int i) => i);

    for (int i = 1; i <= a.length; i++) {
      final List<int> current = List<int>.filled(b.length + 1, 0);
      current[0] = i;

      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;

        final int insert = current[j - 1] + 1;
        final int delete = previous[j] + 1;
        final int replace = previous[j - 1] + cost;

        current[j] = insert < delete
            ? (insert < replace ? insert : replace)
            : (delete < replace ? delete : replace);
      }

      previous = current;
    }

    return previous[b.length];
  }

  // =====================================================
  // UNKNOWN NUTRIENTS: Title Case, codes kept
  // =====================================================

  static const Set<String> _smallWords = <String>{
    'of', 'and', 'or', 'per', 'dan', 'atau', 'as',
  };

  static String _titleCase(String text) {
    final List<String> words = text.split(' ');

    return <String>[
      for (int i = 0; i < words.length; i++)
        _titleWord(words[i], first: i == 0),
    ].join(' ');
  }

  static String _titleWord(String word, {required bool first}) {
    if (word.isEmpty || word == '/') return word;

    // "B6", "D3", "K2" stay as codes.
    if (word.length <= 4 && RegExp(r'\d').hasMatch(word)) {
      return word.toUpperCase();
    }

    final String lower = word.toLowerCase();

    if (!first && _smallWords.contains(lower)) return lower;

    final int letter = lower.indexOf(RegExp(r'[a-z]'));

    if (letter < 0) return lower;

    return lower.substring(0, letter) +
        lower[letter].toUpperCase() +
        lower.substring(letter + 1);
  }

  // =====================================================
  // DICTIONARY (naming only)
  // =====================================================
  //
  // canonical name -> label wordings (English + Bahasa
  // Melayu). Keep separate nutrients in separate entries:
  // never add "sugars" to Added Sugars, "fat" to Saturated
  // Fat, etc.
  // =====================================================

  static const Map<String, List<String>> _aliases = <String, List<String>>{
    'Energy': <String>[
      'energy', 'tenaga', 'energi', 'calories', 'calorie', 'kalori',
      'total energy', 'jumlah tenaga', 'energy value', 'nilai tenaga',
    ],
    'Protein': <String>['protein', 'proteins', 'jumlah protein'],
    'Total Fat': <String>[
      'total fat', 'fat', 'fats', 'lemak', 'lemak jumlah', 'jumlah lemak',
      'lemak total', 'total lipid',
    ],
    'Saturated Fat': <String>[
      'saturated fat', 'saturated fats', 'saturated fatty acids',
      'saturated fatty acid',
      'saturates', 'saturated', 'asid lemak tepu', 'lemak tepu',
      'asid lemak tepu jumlah',
    ],
    // Separate from Saturated Fat: never merged.
    'Unsaturated Fat': <String>[
      'unsaturated fat', 'unsaturated fats', 'unsaturated fatty acids',
      'unsaturated fatty acid',
      'unsaturated', 'asid lemak tidak tepu', 'asid lemak tak tepu',
      'lemak tidak tepu', 'lemak tak tepu',
    ],
    'Trans Fat': <String>[
      'trans fat', 'trans fats', 'trans fatty acids', 'trans fatty acid',
      'asid lemak trans',
      'lemak trans',
    ],
    'Monounsaturated Fat': <String>[
      'monounsaturated fat', 'monounsaturated fats', 'monounsaturated',
      'monounsaturated fatty acids', 'monounsaturates', 'mono unsaturated fat',
      'mono unsaturated fatty acids', 'monounsaturated fatty acid',
      'asid lemak monotidaktepu',
      'lemak monotidaktepu', 'monotidaktepu', 'asid lemak mono tidak tepu',
      'asid lemak tak tepu tunggal', 'lemak tak tepu tunggal',
    ],
    'Polyunsaturated Fat': <String>[
      'polyunsaturated fat', 'polyunsaturated fats', 'polyunsaturated',
      'polyunsaturated fatty acids', 'polyunsaturates', 'poly unsaturated fat',
      'poly unsaturated fatty acids', 'polyunsaturated fatty acid',
      'asid lemak politidaktepu',
      'lemak politidaktepu', 'politidaktepu', 'asid lemak poli tidak tepu',
      'asid lemak tak tepu poli', 'lemak tak tepu poli',
    ],
    'Omega 3': <String>[
      'omega 3', 'omega 3 fatty acids', 'asid lemak omega 3',
    ],
    'Carbohydrate': <String>[
      'carbohydrate', 'carbohydrates', 'total carbohydrate',
      'total carbohydrates', 'karbohidrat', 'jumlah karbohidrat',
      'karbohidrat jumlah', 'carbs',
    ],
    'Total Sugars': <String>[
      'total sugars', 'total sugar', 'sugars', 'sugar', 'jumlah gula',
      'gula', 'gula jumlah',
    ],
    'Added Sugars': <String>[
      'added sugars', 'added sugar', 'gula tambahan', 'total added sugars',
    ],
    'Dietary Fibre': <String>[
      'dietary fibre', 'dietary fiber', 'fibre', 'fiber', 'total fibre',
      'total dietary fibre', 'total dietary fiber', 'serat', 'serat diet',
      'serat dietari', 'jumlah serat dietari', 'serabut',
    ],
    'Sodium': <String>['sodium', 'natrium'],
    'Salt': <String>['salt', 'garam'],
    'Cholesterol': <String>['cholesterol', 'kolesterol'],
    'Potassium': <String>['potassium', 'kalium'],
    'Calcium': <String>['calcium', 'kalsium'],
    'Iron': <String>['iron', 'besi', 'zat besi'],
    'Magnesium': <String>['magnesium'],
    'Vitamin A': <String>['vitamin a', 'retinol'],
    'Vitamin B1': <String>['vitamin b1', 'thiamin', 'thiamine', 'tiamin'],
    'Vitamin B2': <String>['vitamin b2', 'riboflavin', 'riboflavina'],
    'Vitamin B3': <String>['vitamin b3', 'niacin', 'niasin', 'nicotinamide'],
    'Vitamin B5': <String>[
      'vitamin b5', 'pantothenic acid', 'asid pantotenik', 'pantothenate',
    ],
    'Vitamin B6': <String>['vitamin b6', 'pyridoxine', 'piridoksin'],
    'Vitamin B12': <String>['vitamin b12', 'cobalamin', 'kobalamin'],
    'Biotin': <String>['biotin', 'vitamin b7', 'vitamin h'],
    'Vitamin C': <String>['vitamin c', 'ascorbic acid', 'asid askorbik'],
    'Vitamin D': <String>['vitamin d'],
    'Vitamin E': <String>['vitamin e'],
    'Vitamin K': <String>['vitamin k'],
    // Vitamin B9 in three separate entries: folic acid is
    // the synthetic form added to fortified foods, folate the
    // natural form. Both count as vitamin B9 (_vitaminGroup)
    // but are never renamed into each other.
    'Folic Acid': <String>['folic acid', 'asid folik', 'acid folic'],
    'Folate': <String>['folate', 'folat', 'folates', 'natural folate'],
    'Vitamin B9': <String>['vitamin b9'],
    'Zinc': <String>['zinc', 'zink'],
    'Phosphorus': <String>['phosphorus', 'fosforus', 'fosfor'],
    'Iodine': <String>['iodine', 'iodin', 'yodium'],
    'Selenium': <String>['selenium'],
  };

  // Canonical names that are forms of the same vitamin.
  static const Map<String, String> _vitaminGroup = <String, String>{
    'Vitamin B1': 'B1',
    'Vitamin B2': 'B2',
    'Vitamin B3': 'B3',
    'Vitamin B5': 'B5',
    'Vitamin B6': 'B6',
    'Biotin': 'B7',
    'Folic Acid': 'B9',
    'Folate': 'B9',
    'Vitamin B9': 'B9',
    'Vitamin B12': 'B12',
  };

  /// Vitamin a canonical name belongs to ("Folic Acid" and
  /// "Folate" are both "B9"), or null. For health rules
  /// that apply to the vitamin as a whole.
  static String? vitaminGroupOf(String canonicalName) =>
      _vitaminGroup[canonicalName];

  // alias key -> canonical
  static final Map<String, String> _aliasIndex = <String, String>{
    for (final MapEntry<String, List<String>> entry in _aliases.entries)
      for (final String alias in entry.value) _key(alias): entry.key,
  };

  // skeleton (look-alike letters folded) -> canonical.
  // Skeletons shared by two different nutrients are left
  // out, so a look-alike can never pick between them.
  static final Map<String, String> _skeletonIndex = _buildSkeletons();

  static Map<String, String> _buildSkeletons() {
    final Map<String, String> result = <String, String>{};
    final Set<String> clashes = <String>{};

    _aliasIndex.forEach((String key, String canonical) {
      final String skeleton = _skeleton(key);
      final String? existing = result[skeleton];

      if (existing != null && existing != canonical) {
        clashes.add(skeleton);
      } else {
        result[skeleton] = canonical;
      }
    });

    for (final String clash in clashes) {
      result.remove(clash);
    }

    return result;
  }
}

class _Match {
  final String canonical;
  final bool corrected;

  const _Match(this.canonical, this.corrected);
}
