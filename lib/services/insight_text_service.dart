// =======================================================
// INSIGHT TEXT (result screen wording)
// =======================================================
//
// Turns a NutritionAnalysis into the short sentences on
// "Your nutrition insights". Template text only: every
// number comes from the analysis (Layers 1-3), never from
// the AI. Pure Dart, unit tested.
// =======================================================

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import 'nutrition_analysis_service.dart';

class OverallText {
  final String tag;
  final String title;
  final String text;

  const OverallText(this.tag, this.title, this.text);
}

class AreaText {
  // Big number and its unit ("5.4", "g carbs").
  final String value;
  final String unit;

  // "8% of your 72 g meal budget".
  final String share;

  // 0..1 for the bar.
  final double bar;

  final String why;

  const AreaText({
    required this.value,
    required this.unit,
    required this.share,
    required this.bar,
    required this.why,
  });
}

/// One nutrient line on a health area card, e.g.
/// "Sugar 14.7 g" · "almost half your sugar for the day (40%)".
class PlainFact {
  // Canonical nutrient name ('Total Sugars'), for the icon.
  final String nutrient;
  final String label;
  final String amount;
  final String meaning;

  const PlainFact({
    required this.nutrient,
    required this.label,
    required this.amount,
    required this.meaning,
  });
}

/// The evidence layer of a health-area card: one sentence on
/// why the nutrient matters, what to compare when shopping,
/// and the guideline it comes from (knowledge-base IDs).
class PlainEvidence {
  final String why;
  final String lookFor;
  final String source;

  const PlainEvidence({required this.why, required this.lookFor, required this.source});
}

/// A health area card in plain words ("plain answer first").
class PlainAreaText {
  /// One-line answer: "A lot of sugar for you in this portion".
  final String headline;

  /// Where the marker sits on the Low | Moderate | High bar,
  /// 0..1. Null when the area cannot be judged.
  final double? marker;

  final List<PlainFact> facts;

  /// What to try next (moderate or high only).
  final String? tip;

  /// Fibre, when the portion gives a useful amount.
  final String? goodNews;

  /// Small extra line: why the product is rated higher than
  /// the portion alone, or what the label does not show.
  final String? note;

  /// Why it matters, what to look for, and the source.
  final PlainEvidence? evidence;

  const PlainAreaText({
    required this.headline,
    required this.marker,
    required this.facts,
    this.tip,
    this.goodNews,
    this.note,
    this.evidence,
  });

  PlainAreaText withEvidence(PlainEvidence? e) => PlainAreaText(
        headline: headline,
        marker: marker,
        facts: facts,
        tip: tip,
        goodNews: goodNews,
        note: note,
        evidence: e,
      );
}

/// "NutriPal explains" in short, plain parts.
class ExplainText {
  /// "In your 1 cup (236 ml)".
  final String portion;

  /// "92 kcal", "5.4 g carbs"...
  final List<String> amounts;

  /// "That is a small part of the energy you need in a day (6%)."
  final String? energy;

  /// "Low in sugar and sodium (salt) for you."
  final String? good;

  /// "Fat makes it moderate for cholesterol."
  final List<String> watch;

  /// What to do next.
  final String tip;

  /// Standard-limits reminder when the profile is incomplete.
  final String? note;

  const ExplainText({
    required this.portion,
    required this.amounts,
    required this.energy,
    required this.good,
    required this.watch,
    required this.tip,
    required this.note,
  });
}

class ProductTip {
  final bool ok;
  final String text;

  const ProductTip(this.ok, this.text);
}

class InsightTextService {
  InsightTextService._();

  static String _f(double v, String unit) =>
      NutritionAnalysisService.formatAmount(v, unit);

  static String _pct(double share) => NutritionAnalysisService.formatShare(share);

  // Up to 2 decimals, no rounding to 1 place: 0.75 -> "0.75",
  // 1.5 -> "1.5", 120 -> "120".
  static String _exact(double v) {
    final String text = v.toStringAsFixed(v.abs() >= 100 ? 0 : 2);

    if (!text.contains('.')) return text;

    return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }

  // 2000 -> "2,000"
  static String _big(double v, String unit) {
    final String text = _f(v, unit);

    if (v.abs() < 1000 || text.contains('.')) return text;

    return text.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (Match m) => '${m[1]},',
    );
  }

  static String _lower(String name) => switch (name) {
        'Total Sugars' => 'sugar',
        'Total Fat' => 'fat',
        'Saturated Fat' => 'saturated fat',
        'Trans Fat' => 'trans fat',
        'Dietary Fibre' => 'fibre',
        'Energy' => 'energy',
        _ => name.toLowerCase(),
      };

  // =====================================================
  // OVERALL VERDICT
  // =====================================================

  /// [weightGoal] ('lose' | 'maintain' | 'gain') names the
  /// weight area by the user's own goal, e.g. "your
  /// weight-loss goal" instead of "weight".
  static OverallText overall(NutritionAnalysis a, {String? weightGoal}) {
    // No health area gives a Low | Moderate | High result, so
    // there is no overall verdict: the summary points the
    // user to the key-nutrient cards.
    final List<String> shown = <String>[
      for (final AreaAssessment x in a.areas) _findingsName(x.area, weightGoal),
    ];

    if (shown.isEmpty) {
      return const OverallText(
        'Check the label',
        'Not enough information',
        'This label does not show the nutrients NutriPal needs for your '
            'health areas.',
      );
    }

    return OverallText(
      'Review key nutrients',
      'Look at the nutrient findings',
      'NutriPal shows the key nutrients in this portion for ${_joinAnd(shown)} below, '
          'without an overall result.',
    );
  }

  static String _findingsName(HealthArea area, [String? weightGoal]) => switch (area) {
        HealthArea.cholesterol => 'LDL cholesterol',
        HealthArea.bloodPressure => 'hypertension',
        HealthArea.diabetes => 'diabetes',
        HealthArea.weight => switch (weightGoal) {
            'lose' => 'your weight-loss goal',
            'maintain' => 'your weight-maintenance goal',
            'gain' => 'your weight-gain goal',
            _ => 'weight',
          },
      };

  // =====================================================
  // ONE HEALTH AREA CARD, PLAIN WORDS
  // =====================================================
  //
  // Same numbers as [area], said the way people talk:
  // a 24 % share becomes "about a quarter". Fixed rules,
  // no AI.

  /// "about a quarter", "almost half"... for a share.
  static String fraction(double share) {
    if (share < 0.05) return 'a tiny part';
    if (share < 0.15) return 'a small part';
    if (share < 0.22) return 'about a fifth';
    if (share < 0.29) return 'about a quarter';
    if (share < 0.38) return 'about a third';
    if (share < 0.46) return 'almost half';
    if (share < 0.56) return 'about half';
    if (share < 0.75) return 'more than half';
    if (share < 0.95) return 'most';

    return 'nearly all';
  }

  static String _plainName(String nutrient) => switch (nutrient) {
        'Carbohydrate' => 'carbs',
        'Total Sugars' => 'sugar',
        'Sodium' => 'sodium (salt)',
        'Saturated Fat' => 'saturated fat',
        'Trans Fat' => 'trans fat',
        'Total Fat' => 'fat',
        'Energy' => 'energy',
        _ => nutrient.toLowerCase(),
      };

  static String _label(String nutrient) => switch (nutrient) {
        'Carbohydrate' => 'Carbs',
        'Total Sugars' => 'Sugar',
        'Sodium' => 'Sodium',
        'Saturated Fat' => 'Saturated fat',
        'Trans Fat' => 'Trans fat',
        'Total Fat' => 'Fat',
        'Energy' => 'Energy',
        _ => nutrient,
      };

  static String _meaning(NutrientAssessment n) {
    final double share = n.share ?? 0;
    final String pct = _pct(share);

    if (n.name == 'Carbohydrate') {
      if (share > 1.05) return 'more than one meal should have ($pct)';

      return '${fraction(share)} of what one meal should have ($pct)';
    }

    final String what = n.name == 'Energy' ? 'energy' : _plainName(n.name);

    if (share > 1.05) return "more than your whole day's $what ($pct)";

    return '${fraction(share)} of your $what for the day ($pct)';
  }

  /// 0..1 on the Low | Moderate | High bar: inside the
  /// level's third, by how big the share is (in the
  /// nutrient's own bands).
  static double _marker(NutrientLevel level, NutrientAssessment? n) {
    final double share = n?.share ?? 0;
    final double low = n?.lowShareMax ?? AnalysisRules.lowShare;
    final double high = n?.highShareMax ?? AnalysisRules.highShare;

    final NutrientLevel byShare =
        NutritionAnalysisService.shareLevel(share, low: low, high: high);

    // Rated higher because of the product itself: middle of
    // that level.
    if (byShare != level) return (level.index + 0.5) / 3;

    final double t = switch (level) {
      NutrientLevel.low => (share / low),
      NutrientLevel.moderate => (share - low) / (high - low),
      NutrientLevel.high => (share - high) / high,
    };

    return ((level.index + t.clamp(0.08, 0.92)) / 3).clamp(0.03, 0.97);
  }

  static PlainAreaText plainArea(
    AreaAssessment area,
    NutritionAnalysis a, {
    String? weightGoal,
  }) {
    if (area.partial) {
      final PlainAreaText t = _plainFindings(area, a, weightGoal: weightGoal);

      return t.facts.isEmpty ? t : t.withEvidence(_evidenceFor(area.area, a, weightGoal));
    }

    final NutrientLevel? level = area.level;

    if (level == null) {
      final String missing = area.missing.isEmpty
          ? 'the nutrients it needs'
          : area.missing.map(_lower).join(' or ');

      return PlainAreaText(
        headline: 'Not enough information',
        marker: null,
        facts: const <PlainFact>[],
        note: 'This label does not show $missing, so NutriPal cannot judge this area.',
      );
    }

    final String decider = _plainName(area.decidedBy ?? '');

    // ---- headline ---------------------------------------
    final String headline = switch (level) {
      NutrientLevel.high => 'A lot of $decider for you in this portion',
      NutrientLevel.moderate => switch (area.area) {
          HealthArea.diabetes => 'Okay if you count it in your meal',
          HealthArea.bloodPressure => 'Some salt, so go easy on salty food today',
          HealthArea.cholesterol => 'Some $decider, fine now and then',
          HealthArea.weight => 'Okay if you keep to this portion',
        },
      NutrientLevel.low => switch (area.area) {
          HealthArea.diabetes => 'Easy on your blood sugar',
          HealthArea.bloodPressure => 'Low in salt for you',
          HealthArea.cholesterol => 'Kind to your cholesterol',
          HealthArea.weight => switch (weightGoal) {
              'lose' => 'Fits your weight-loss goal',
              'gain' => 'Light, so add more to reach your weight-gain goal',
              _ => 'Fits your weight goal',
            },
        },
    };

    // ---- facts: the deciding nutrient first -------------
    final List<NutrientAssessment> rated = <NutrientAssessment>[...area.nutrients]
      ..sort((NutrientAssessment x, NutrientAssessment y) {
        if (x.name == area.decidedBy) return -1;
        if (y.name == area.decidedBy) return 1;

        return 0;
      });

    final List<PlainFact> facts = <PlainFact>[
      for (final NutrientAssessment n in rated)
        if (n.share != null)
          PlainFact(
            nutrient: n.name,
            label: _label(n.name),
            amount: '${_f(n.amount, n.unit)} ${n.unit}',
            meaning: _meaning(n),
          ),
    ];

    // ---- marker -----------------------------------------
    final NutrientAssessment? main = a.nutrients[area.decidedBy] ?? _mainNutrient(area, a);
    final double marker = _marker(level, main);

    // ---- tip --------------------------------------------
    final String? tip = switch (level) {
      // The portion tip (what half would do) is worked out in
      // NutriPal explains, so it is not repeated here.
      NutrientLevel.high => 'Look for a product with less $decider.',
      NutrientLevel.moderate => switch (area.area) {
          HealthArea.diabetes => 'Count it as part of your meal.',
          HealthArea.bloodPressure => 'Keep your other meals today less salty.',
          HealthArea.cholesterol => 'Enjoy it now and then, not every day.',
          HealthArea.weight => 'Keep to this portion.',
        },
      NutrientLevel.low => null,
    };

    // ---- good news: fibre -------------------------------
    String? goodNews;
    final NutrientAssessment? fibre = area.benefit;

    if (fibre != null && (fibre.share ?? 0) > 0.10) {
      final String helps = switch (area.area) {
        HealthArea.diabetes => 'Fibre helps keep blood sugar steady.',
        HealthArea.cholesterol => 'Fibre can help lower cholesterol.',
        HealthArea.weight => 'Fibre helps you feel full for longer.',
        HealthArea.bloodPressure => 'Fibre is good for you.',
      };

      goodNews = 'It has ${_f(fibre.amount, 'g')} g of fibre, '
          '${fraction(fibre.share!)} of what you need each day. $helps';
    }

    // Protein goal (Nutrition Targets): shown on the weight
    // card, where it helps most.
    final NutrientAssessment? protein = a.nutrients['Protein'];

    if (area.area == HealthArea.weight && protein?.share != null && protein!.share! > 0.10) {
      final String line = 'It gives ${_f(protein.amount, 'g')} g of protein, '
          '${fraction(protein.share!)} of your daily protein goal.';

      goodNews = goodNews == null ? line : '$goodNews $line';
    }

    // ---- note -------------------------------------------
    final List<String> notes = <String>[];

    final NutrientAssessment? d = area.decidedBy == null ? null : a.nutrients[area.decidedBy];

    if (d != null &&
        d.productLevel == level &&
        (d.bandLevel ?? NutrientLevel.low).index < level.index &&
        d.per100 != null) {
      notes.add(
        'The product itself is ${level.label.toLowerCase()} in ${_lower(d.name)} '
        '(${_f(d.per100!, d.unit)} ${d.unit} ${a.per100Label}).',
      );
    }

    if (area.missing.isNotEmpty) {
      notes.add('Not on the label: ${area.missing.map(_lower).join(', ')}.');
    }

    return PlainAreaText(
      headline: headline,
      marker: marker,
      facts: facts,
      tip: tip,
      goodNews: goodNews,
      note: notes.isEmpty ? null : notes.join(' '),
    );
  }

  // =====================================================
  // HEALTH-AREA CARDS, PLAIN WORDS (findings, no level)
  // (rule R-LDL-01 v2 for the LDL cholesterol card)
  // =====================================================
  //
  // Key nutrients with their amounts, no level and no bar.
  // Saturated and trans fat show the plain percentage of the
  // daily reference; the per-100 traffic light is product-
  // level information. It never says a food is safe,
  // suitable or unsuitable, and never calls total sugars
  // added or free sugar.

  static const String _ldlAdvice =
      'Saturated and trans fat are important for LDL cholesterol. Fibre may '
      'give a helpful supporting contribution.';

  static const String _ldlFibre = 'Fibre can help lower cholesterol.';

  /// "5% of your daily limit" - a plain figure, no band word.
  static String _plainShare(NutrientAssessment n, NutritionAnalysis a) {
    final String pct = _pct(n.share ?? 0);

    if (n.name == 'Sodium' && n.target != null) {
      return '$pct of the ${_big(n.target!, 'mg')} mg daily sodium reference';
    }

    // Lose, maintain and gain all use maintenance energy
    // (or the user's own target) as the reference.
    if (n.name == 'Energy') {
      final String of = a.targets.setByProvider.contains('Energy')
          ? 'your own daily energy target'
          : 'your estimated daily energy need';

      return '$pct of $of';
    }

    return '$pct of your ${n.targetLabel ?? 'daily limit'}';
  }

  /// Share of the daily reference, then the product traffic
  /// light as a separate piece of information.
  static String _findingMeaning(NutrientAssessment n, NutritionAnalysis a) {
    final List<String> parts = <String>[
      if (n.share != null && n.name != 'Total Fat') _plainShare(n, a),
    ];

    return parts.isEmpty ? 'in this portion' : parts.join(', ');
  }

  static PlainAreaText _plainFindings(
    AreaAssessment area,
    NutritionAnalysis a, {
    String? weightGoal,
  }) {
    final HealthArea kind = area.area;

    if (area.nutrients.isEmpty && area.watch.isEmpty) {
      final String missing = area.missing.isEmpty
          ? 'the nutrients it needs'
          : area.missing.map(_lower).join(' or ');

      return PlainAreaText(
        headline: 'Not enough information',
        marker: null,
        facts: const <PlainFact>[],
        note: 'This label does not show $missing, so NutriPal cannot show this area.',
      );
    }

    final bool weightCard = kind == HealthArea.weight;
    final String goal = _goalKey(weightGoal);

    final List<PlainFact> watchFacts = <PlainFact>[
      // Diabetes: carbohydrate and total sugars, as amounts
      // only. Weight: the goal's supporting and context
      // nutrients, as amounts only.
      for (final NutrientAssessment n in area.watch)
        PlainFact(
          nutrient: n.name,
          label: n.name == 'Total Sugars'
              ? 'Total sugars'
              : n.name == 'Dietary Fibre'
                  ? 'Fibre'
                  : _label(n.name),
          amount: '${_f(n.amount, n.unit)} ${n.unit}',
          meaning: weightCard ? _weightWatchMeaning(n.name, goal) : _watchMeaning(n, a),
        ),
    ];

    final List<PlainFact> shownFacts = <PlainFact>[
      for (final NutrientAssessment n in area.nutrients)
        PlainFact(
          nutrient: n.name,
          label: _label(n.name),
          amount: '${_f(n.amount, n.unit)} ${n.unit}',
          meaning: _findingMeaning(n, a),
        ),
    ];

    // Diabetes lists its amounts first; the weight card
    // starts with energy.
    final List<PlainFact> facts = weightCard
        ? <PlainFact>[...shownFacts, ...watchFacts]
        : <PlainFact>[...watchFacts, ...shownFacts];

    // Fibre: a supporting factor, never a risk.
    String? goodNews;
    final NutrientAssessment? fibre = area.benefit;

    // Only when the product actually has fibre.
    if (fibre != null && fibre.amount > 0) {
      final String why = switch (kind) {
        HealthArea.cholesterol => _ldlFibre,
        HealthArea.diabetes => 'Fibre-rich carbohydrate foods are generally preferred.',
        _ => 'Fibre can help you feel full.',
      };

      goodNews = 'It has ${_f(fibre.amount, 'g')} g of fibre. $why';
    }

    // Weight card: a protein goal from Nutrition Targets.
    final NutrientAssessment? protein = a.nutrients['Protein'];

    if (kind == HealthArea.weight && protein?.share != null && protein!.share! > 0.10) {
      final String line = 'It gives ${_f(protein.amount, 'g')} g of protein, '
          '${fraction(protein.share!)} of your daily protein goal.';

      goodNews = goodNews == null ? line : '$goodNews $line';
    }

    final String headline = switch (kind) {
      HealthArea.cholesterol => 'Saturated and trans fat in this portion',
      HealthArea.bloodPressure => 'Sodium in this portion',
      HealthArea.weight => 'Energy in this portion',
      HealthArea.diabetes => 'Carbohydrate and sugars in this portion',
    };

    final String tip = switch (kind) {
      HealthArea.cholesterol => _ldlAdvice,
      HealthArea.bloodPressure =>
        'Sodium (salt) adds up through the day. Compare this portion with the '
            'rest of what you eat.',
      HealthArea.weight => switch (goal) {
          'lose' => 'For weight loss, portion size matters: a smaller or larger portion '
              'changes this energy. When comparing similar products, consider options '
              'that give useful protein or fibre without adding unnecessary energy.',
          'gain' => 'This portion adds energy to your day. For gradual weight gain, choose '
              'foods that give energy together with useful nutrients such as protein, '
              'rather than relying mainly on sugary foods or drinks.',
          _ => 'Consider this together with the energy from the rest of your meals, '
              'snacks and drinks.',
        },
      HealthArea.diabetes =>
        'Count these carbohydrates as part of your meal, following your own plan '
            'from your doctor or dietitian. NutriPal never works out insulin or '
            'medicine doses.',
    };

    final List<String> notes = <String>[
      if (area.watch.any((NutrientAssessment n) => n.name == 'Total Sugars'))
        'Total sugars include natural and added sugars. This is the amount in your '
            'portion; the amount ${a.per100Label} is in Nutrition facts.',
      if (weightCard && !a.targets.setByProvider.contains('Energy'))
        'Your estimated daily energy need is the energy to keep your current weight. '
            'It is a general guide, not a target.',
      if (area.missing.isNotEmpty) 'Not on the label: ${area.missing.map(_lower).join(', ')}.',
    ];

    return PlainAreaText(
      headline: headline,
      marker: null,
      facts: facts,
      tip: tip,
      goodNews: goodNews,
      note: notes.isEmpty ? null : notes.join(' '),
    );
  }

  /// One evidence-based sentence per health area, paraphrased
  /// from the validated knowledge base (IDs in the source).
  /// No threshold is invented here.
  static PlainEvidence _evidenceFor(
    HealthArea kind,
    NutritionAnalysis a,
    String? weightGoal,
  ) {
    switch (kind) {
      case HealthArea.diabetes:
        return const PlainEvidence(
          why: 'Guidelines suggest reducing carbohydrate for some adults with diabetes '
              'and minimising sugar-sweetened foods and drinks. One product is only '
              'part of a meal.',
          lookFor: 'When comparing similar products, choose less total sugars and more '
              'fibre.',
          source: 'ADA 2026 (DM-02, DM-04, DM-05)',
        );
      case HealthArea.bloodPressure:
        return const PlainEvidence(
          why: 'Malaysian and WHO guidance recommend keeping sodium below 2,000 mg '
              '(5 g salt) a day.',
          lookFor: 'When comparing similar products, choose the one with less sodium per '
              'serving.',
          source: 'MOH Malaysia / Academy of Medicine 2023 (HT-02); MDA 2026 (HT-01); '
              'WHO 2025 (HT-03)',
        );
      case HealthArea.cholesterol:
        return const PlainEvidence(
          why: 'Malaysian dietitian guidance limits saturated fat to under 10% of energy '
              'and trans fat to under 1%.',
          lookFor: 'When comparing similar products, choose less saturated and trans fat; '
              'fibre also helps.',
          source: 'MDA 2026 (LD-01, LD-03, LD-07)',
        );
      case HealthArea.weight:
        return switch (weightGoal) {
          'gain' => const PlainEvidence(
              why: 'Healthy weight gain is gradual, about 300 to 500 extra kcal a day, '
                  'from nutritious foods rather than sugary ones.',
              lookFor: 'When comparing similar products, compare energy together with '
                  'protein, and avoid relying mainly on sugary options.',
              source: 'NHS 2023 (WT-08)',
            ),
          'lose' => const PlainEvidence(
              why: 'Losing weight comes from taking in less energy overall while keeping '
                  'a healthy eating pattern, so the portion you choose matters.',
              lookFor: 'When comparing similar products, compare energy, protein and '
                  'fibre for the portion you plan to eat.',
              source: 'NIDDK 2023 (WT-02)',
            ),
          _ => const PlainEvidence(
              why: 'Your estimated energy need is for maintaining your current weight, '
                  'so the portion you choose changes how much of it you use.',
              lookFor: 'When comparing similar products, compare energy for the same '
                  'portion and the overall nutrient quality.',
              source: 'NASEM 2023 (WT-11)',
            ),
        };
    }
  }

  /// "about 1.5 carb exchanges" / "Low per 100 ml (product)".
  /// 'lose' | 'maintain' | 'gain' from the stored goal.
  static String _goalKey(String? goal) {
    final String g = (goal ?? '').toLowerCase();

    if (g.contains('lose')) return 'lose';
    if (g.contains('gain')) return 'gain';

    return 'maintain';
  }

  /// Weight card: supporting and context amounts.
  static String _weightWatchMeaning(String nutrient, String goal) => switch (nutrient) {
        'Protein' => switch (goal) {
            'lose' => 'supports fullness and muscle maintenance',
            'gain' => 'supports healthy tissue growth and maintenance',
            _ => 'supports muscle maintenance',
          },
        'Dietary Fibre' => 'can help you feel full',
        'Total Sugars' => goal == 'gain'
            ? 'can add energy, but balance with nutrient-rich foods'
            : 'part of the portion’s overall energy',
        'Total Fat' => 'a major contributor to energy',
        _ => 'in this portion',
      };

  static String _watchMeaning(NutrientAssessment n, NutritionAnalysis a) {
    if (n.name == 'Carbohydrate') {
      final String ex = NutritionAnalysisService.exchanges(n.amount);

      return 'about $ex carb ${ex == '1' ? 'exchange' : 'exchanges'} in this portion';
    }

    return 'in this portion';
  }

  // =====================================================
  // ONE HEALTH AREA CARD
  // =====================================================

  static AreaText area(AreaAssessment area, NutritionAnalysis a) {
    final NutrientAssessment? main = _mainNutrient(area, a);

    if (main == null || area.level == null) {
      final String missing = area.missing.isEmpty
          ? 'the nutrients it needs'
          : area.missing.map(_lower).join(' or ');

      return AreaText(
        value: '–',
        unit: '',
        share: '',
        bar: 0,
        why: 'This label does not show $missing, so NutriPal cannot judge '
            'this area.',
      );
    }

    final String unit = switch (main.name) {
      'Carbohydrate' => 'g carbs',
      'Sodium' => 'mg sodium',
      'Energy' => 'kcal',
      _ => '${main.unit} ${_lower(main.name)}',
    };

    final double share = main.share ?? 0;

    final String shareText = main.target == null
        ? ''
        : '${_pct(share)} of ${_big(main.target!, main.unit)} ${main.unit} '
            '${main.targetLabel ?? ''}'.trim();

    final List<String> why = <String>[];

    // Main sentence from the share band.
    final String label = main.targetLabel ?? 'daily limit';

    final NutrientLevel band = main.bandLevel ?? NutrientLevel.low;

    if (main.name == 'Carbohydrate') {
      final String ex = NutritionAnalysisService.exchanges(main.amount);
      final String exWord = ex == '1' ? 'exchange' : 'exchanges';
      final String highPct = '${(main.highShareMax * 100).round()}%';

      why.add(switch (band) {
        NutrientLevel.low =>
          'About $ex carb $exWord, a small part of your meal budget.',
        NutrientLevel.moderate =>
          '$ex carb $exWord, ${_pct(share)} of your meal budget. Count it in your meal.',
        NutrientLevel.high =>
          '$ex carb $exWord, more than $highPct of your meal budget. A smaller portion fits better.',
      });
    } else {
      why.add(switch (band) {
        NutrientLevel.low => 'A small part of your $label for this portion.',
        NutrientLevel.moderate => '${_pct(share)} of your $label in this portion.',
        NutrientLevel.high =>
          '${_pct(share)} of your $label, a large share. A smaller portion fits better.',
      });
    }

    // Why the level is higher than the main share says.
    final String? decider = area.decidedBy;

    if (decider != null && area.level!.index > band.index) {
      final NutrientAssessment d = a.nutrients[decider]!;
      final NutrientLevel dShare = d.bandLevel ?? NutrientLevel.low;

      if (d.productLevel == area.level && dShare.index < area.level!.index && d.per100 != null) {
        why.add(
          'The product itself is ${area.level!.label.toLowerCase()} in '
          '${_lower(d.name)} (${_f(d.per100!, d.unit)} ${d.unit} ${a.per100Label}).',
        );
      } else if (d.name != main.name) {
        why.add(
          '${_capital(_lower(d.name))}: ${_f(d.amount, d.unit)} ${d.unit}, '
          '${_pct(d.share ?? 0)} of your ${d.targetLabel ?? 'daily limit'}.',
        );
      }
    }

    // Fibre bonus.
    final NutrientAssessment? fibre = area.benefit;

    // Plain words: what fibre does for this health area.
    if (fibre != null && (fibre.share ?? 0) > 0.10) {
      final String helps = switch (area.area) {
        HealthArea.diabetes => 'Fibre helps keep blood sugar steady.',
        HealthArea.cholesterol => 'Fibre can help lower cholesterol.',
        HealthArea.weight => 'Fibre helps you feel full for longer.',
        HealthArea.bloodPressure => 'Fibre is good for you.',
      };

      why.add(
        'Good to know: it has ${_f(fibre.amount, 'g')} g of fibre, about '
        '${_pct(fibre.share!)} of what you need each day. $helps',
      );
    }

    if (area.missing.isNotEmpty) {
      why.add('Not on the label: ${area.missing.map(_lower).join(', ')}.');
    }

    return AreaText(
      value: _f(main.amount, main.unit),
      unit: unit,
      share: shareText,
      bar: share.clamp(0, 1).toDouble(),
      why: why.join(' '),
    );
  }

  static NutrientAssessment? _mainNutrient(AreaAssessment area, NutritionAnalysis a) {
    switch (area.area) {
      case HealthArea.diabetes:
        // The area's key nutrient (carbohydrate).
        final String key = area.ruleNutrients.isEmpty ? 'Carbohydrate' : area.ruleNutrients.first;

        return a.nutrients[key] ?? a.nutrients['Carbohydrate'];
      case HealthArea.bloodPressure:
        return a.nutrients['Sodium'];
      case HealthArea.cholesterol:
        return a.nutrients['Saturated Fat'] ?? a.nutrients['Total Fat'];
      case HealthArea.weight:
        return a.nutrients['Energy'];
    }
  }

  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  // =====================================================
  // "NUTRIPAL EXPLAINS" (template summary)
  // =====================================================

  static String summary(NutritionAnalysis a, String portionText) {
    final List<String> parts = <String>[];

    void add(String name, String unit) {
      final NutrientAssessment? n = a.nutrients[name];

      if (n != null) parts.add('${_f(n.amount, n.unit)} $unit');
    }

    add('Energy', 'kcal');
    add('Carbohydrate', 'g carbohydrate');
    add('Total Sugars', 'g sugar');
    add('Protein', 'g protein');
    add('Sodium', 'mg sodium');

    final StringBuffer text = StringBuffer();

    if (parts.isNotEmpty) {
      final String list = parts.length == 1
          ? parts.first
          : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';

      text.write('$portionText gives you $list. ');
    }

    final List<AreaAssessment> watch = a.areas
        .where((AreaAssessment x) => x.level == NutrientLevel.high || x.level == NutrientLevel.moderate)
        .toList();

    if (a.overall == NutrientLevel.low) {
      text.write('That is a small part of your limits for every health area NutriPal checked.');
    } else if (watch.isNotEmpty) {
      final AreaAssessment worst = watch.reduce(
        (AreaAssessment x, AreaAssessment y) => y.level!.index > x.level!.index ? y : x,
      );

      text.write(
        '${worst.area.title} is ${worst.level!.label.toLowerCase()}'
        '${worst.decidedBy == null ? '' : ' because of the ${_lower(worst.decidedBy!)}'}. '
        'Change the portion above to see how a smaller amount fits.',
      );
    }

    if (!a.targets.energyIsPersonal) {
      text.write(
        ' Limits use a standard 2,000 kcal day; add your weight, height and '
        'activity in your profile for personal limits.',
      );
    }

    return text.toString().trim();
  }

  // =====================================================
  // NUTRIPAL EXPLAINS (plain parts)
  // =====================================================
  //
  // What is in the portion, what is good, what to watch,
  // and one thing to try. The tip re-checks half the
  // portion with the same rules, so "half keeps it low" is
  // worked out, not guessed.

  static ExplainText explain(
    NutritionAnalysis a, {
    required NutritionLabelData data,
    required NutritionProfile profile,
    required String portionText,
    String? weightGoal,
  }) {
    // ---- amounts ----------------------------------------
    final List<String> amounts = <String>[];

    void add(String name, String label) {
      final NutrientAssessment? n = a.nutrients[name];

      if (n == null) return;

      final String value = '${_f(n.amount, n.unit)} ${n.unit}';

      amounts.add(label.isEmpty ? value : '$value $label');
    }

    add('Energy', '');
    add('Carbohydrate', 'carbs');
    add('Total Sugars', 'sugar');
    add('Total Fat', 'fat');
    add('Sodium', 'sodium');
    add('Protein', 'protein');

    // ---- energy share -----------------------------------
    final NutrientAssessment? energy = a.nutrients['Energy'];
    // With a weight goal applied, the share is of the goal
    // energy, so say which figure it is.
    final String energyOf = a.targets.setByProvider.contains('Energy')
        ? 'your own daily energy target'
        : 'the energy you need in a day';

    final String? energyLine = energy?.share == null
        ? null
        : 'That is ${fraction(energy!.share!)} of $energyOf '
            '(${_pct(energy.share!)}).';

    // ---- good: rated nutrients that are low --------------
    // Only nutrients a health area rated (never the carbs
    // and sugar the diabetes card shows as amounts).
    final Map<String, NutrientLevel> rated = <String, NutrientLevel>{};

    for (final AreaAssessment x in a.areas) {
      for (final NutrientAssessment n in x.nutrients) {
        if (n.level == null) continue;

        final NutrientLevel? before = rated[n.name];
        rated[n.name] = before == null ? n.level! : before.worse(n.level!);
      }
    }

    final List<String> low = <String>[
      for (final String name in <String>['Total Sugars', 'Sodium', 'Saturated Fat', 'Total Fat'])
        if (rated[name] == NutrientLevel.low) _plainName(name),
    ];

    final String? good = low.isEmpty ? null : 'Low in ${_joinAnd(low)} for you.';

    // ---- watch: areas that are moderate or high ----------
    String areaName(HealthArea area) => switch (area) {
          HealthArea.weight => switch (weightGoal) {
              'lose' => 'your weight-loss goal',
              'maintain' => 'your weight goal',
              'gain' => 'your weight-gain goal',
              _ => 'weight',
            },
          _ => area.title.toLowerCase(),
        };

    final List<String> watch = <String>[
      for (final AreaAssessment x in a.areas)
        if (x.level == NutrientLevel.moderate || x.level == NutrientLevel.high)
          '${_capital(_plainName(x.decidedBy ?? ''))} makes it '
              '${x.level!.label.toLowerCase()} for ${areaName(x.area)}.',
    ];

    // ---- tip: try half the portion -----------------------
    final String tip = _tip(a, data: data, profile: profile);

    return ExplainText(
      portion: 'In $portionText',
      amounts: amounts,
      energy: energyLine,
      good: good,
      watch: watch,
      tip: tip,
      note: a.targets.energyIsPersonal
          ? null
          : 'Limits use a standard 2,000 kcal day. Add your weight, height and '
              'activity in your profile for personal limits.',
    );
  }

  static String _tip(
    NutritionAnalysis a, {
    required NutritionLabelData data,
    required NutritionProfile profile,
  }) {
    final NutrientLevel? now = a.overall;

    // Findings have no level, so no "twice is fine" claim.
    if (now == null) {
      return 'A smaller or larger portion changes every amount above. '
          'Check the label values with Edit if anything looks wrong.';
    }

    // Same portion scaled by [factor] (½ or 2).
    Portion? scaled(double factor) => a.portionServings != null
        ? Portion.servings(a.portionServings! * factor)
        : (a.portionAmount != null && a.portionUnit != null
            ? Portion.amount(a.portionAmount! * factor, a.portionUnit!)
            : null);

    String amountOf(NutritionAnalysis x) => x.portionAmount == null || x.portionUnit == null
        ? ''
        : ' (${_f(x.portionAmount!, x.portionUnit!)} ${x.portionUnit})';

    // Already low: how much more would still be fine?
    if (now == NutrientLevel.low) {
      final Portion? twice = scaled(2);

      if (twice == null) return 'This portion is a good amount for you.';

      final NutritionAnalysis bigger =
          NutritionAnalysisService.analyse(data: data, profile: profile, portion: twice);

      if (bigger.overall == NutrientLevel.low) {
        return 'Even twice this amount${amountOf(bigger)} stays low for you.';
      }

      return 'Twice this amount${amountOf(bigger)} would be '
          '${(bigger.overall ?? NutrientLevel.moderate).label.toLowerCase()}, '
          'so this portion is a good amount.';
    }

    final Portion? half = scaled(0.5);

    if (half == null) return 'A smaller portion lowers every amount above.';

    final NutritionAnalysis smaller =
        NutritionAnalysisService.analyse(data: data, profile: profile, portion: half);

    final String amount = amountOf(smaller);

    final NutrientLevel? then = smaller.overall;

    if (then == NutrientLevel.low) {
      return 'Having half$amount keeps it low for all your health areas.';
    }

    if (then != null && then.index < now.index) {
      return 'Having half$amount brings it down to ${then.label.toLowerCase()}.';
    }

    final AreaAssessment worst = a.areas
        .where((AreaAssessment x) => x.level != null)
        .reduce((AreaAssessment x, AreaAssessment y) => y.level!.index > x.level!.index ? y : x);

    return 'Even half stays ${now.label.toLowerCase()}, so look for a product with less '
        '${_plainName(worst.decidedBy ?? 'sugar')}.';
  }

  static String _joinAnd(List<String> items) => items.length == 1
      ? items.first
      : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

  // =====================================================
  // QUESTION CHIPS
  // =====================================================

  static List<String> suggestedQuestions(NutritionAnalysis a) {
    final List<String> q = <String>[];

    AreaAssessment? flagged;

    for (final AreaAssessment x in a.areas) {
      if (x.level == NutrientLevel.high || x.level == NutrientLevel.moderate) {
        flagged = x;
        break;
      }
    }

    if (flagged != null) {
      q.add('Why is ${flagged.area.title.toLowerCase()} ${flagged.level!.label.toLowerCase()}?');
    }

    if (flagged == null && a.areas.isNotEmpty) {
      q.add('What should I watch for ${_findingsName(a.areas.first.area)}?');
    }

    if (a.portionServings != null) {
      q.add('Can I have 2 servings?');
    }

    q.add('What is a healthier swap?');

    return q.take(3).toList();
  }

  // =====================================================
  // CHOOSING SIMILAR PRODUCTS (Layer 1 low limits)
  // =====================================================

  static List<ProductTip> tips(NutritionAnalysis a) {
    final Map<String, List<double>> t = a.form == ProductForm.drink
        ? AnalysisRules.drinkThresholds
        : AnalysisRules.foodThresholds;

    final Set<String> wanted = <String>{};

    for (final AreaAssessment area in a.areas) {
      switch (area.area) {
        case HealthArea.diabetes:
          wanted.add('Total Sugars');
        case HealthArea.bloodPressure:
          wanted.add('Sodium');
        case HealthArea.cholesterol:
          wanted.add('Saturated Fat');
        case HealthArea.weight:
          wanted
            ..add('Total Fat')
            ..add('Total Sugars');
      }
    }

    final List<ProductTip> tips = <ProductTip>[];

    for (final String name in <String>['Total Sugars', 'Sodium', 'Saturated Fat', 'Total Fat']) {
      if (!wanted.contains(name)) continue;

      final NutrientAssessment? n = a.nutrients[name];

      if (n?.per100 == null) continue;

      final double limit = name == 'Sodium'
          ? t['Salt']![0] / AnalysisRules.saltPerSodium * 1000
          : t[name]![0];

      final String unit = name == 'Sodium' ? 'mg' : 'g';
      final bool ok = n!.per100! <= limit;
      final String what = _lower(name);

      // Exact numbers (0.75, not 0.8), so the limit and the
      // product's value read the same way as the rule.
      final String max = _exact(limit);
      final String has = _exact(n.per100!);

      tips.add(ProductTip(
        ok,
        ok
            ? 'Pick products with up to $max $unit $what ${a.per100Label}. '
                'This one has $has $unit.'
            : 'For less $what, look for up to $max $unit ${a.per100Label}. '
                'This one has $has $unit.',
      ));
    }

    return tips;
  }
}
