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
import 'energy_requirement.dart' show GoalEnergyResult;
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

  const PlainAreaText({
    required this.headline,
    required this.marker,
    required this.facts,
    this.tip,
    this.goodNews,
    this.note,
  });
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
    final List<AreaAssessment> judged =
        a.areas.where((AreaAssessment x) => x.level != null).toList();

    String nameOf(HealthArea area) {
      if (area != HealthArea.weight) return area.title.toLowerCase();

      return switch (weightGoal) {
        'lose' => 'your weight-loss goal',
        'maintain' => 'your weight-maintenance goal',
        'gain' => 'your weight-gain goal',
        _ => 'weight',
      };
    }

    String names(NutrientLevel level) {
      final List<String> list = <String>[
        for (final AreaAssessment x in judged)
          if (x.level == level) nameOf(x.area),
      ];

      if (list.length <= 1) return list.join();

      return '${list.sublist(0, list.length - 1).join(', ')} and ${list.last}';
    }

    switch (a.overall) {
      case NutrientLevel.low:
        return const OverallText(
          'Fits your goals',
          'Good choice for you',
          'This portion is low for every health area NutriPal checked.',
        );
      case NutrientLevel.moderate:
        return OverallText(
          'Fits with care',
          'OK in this portion',
          'Watch ${names(NutrientLevel.moderate)} at this amount.',
        );
      case NutrientLevel.high:
        return OverallText(
          'Watch out',
          'Too much for you',
          'High for ${names(NutrientLevel.high)}. Try a smaller portion.',
        );
      case null:
        return const OverallText(
          'Check the label',
          'Not enough information',
          'This label does not show the nutrients NutriPal needs for your '
              'health areas.',
        );
    }
  }

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
  /// level's third, by how big the share is.
  static double _marker(NutrientLevel level, double share) {
    final NutrientLevel byShare = NutritionAnalysisService.shareLevel(share);

    // Rated higher because of the product itself: middle of
    // that level.
    if (byShare != level) return (level.index + 0.5) / 3;

    final double low = AnalysisRules.lowShare;
    final double high = AnalysisRules.highShare;

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
    final double marker = _marker(level, main?.share ?? 0);

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

    // ---- note -------------------------------------------
    final List<String> notes = <String>[];

    final NutrientAssessment? d = area.decidedBy == null ? null : a.nutrients[area.decidedBy];

    if (d != null &&
        d.productLevel == level &&
        NutritionAnalysisService.shareLevel(d.share ?? 0).index < level.index &&
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

    if (main.name == 'Carbohydrate') {
      final String ex = NutritionAnalysisService.exchanges(main.amount);
      final String exWord = ex == '1' ? 'exchange' : 'exchanges';

      why.add(switch (NutritionAnalysisService.shareLevel(share)) {
        NutrientLevel.low =>
          'About $ex carb $exWord, a small part of your meal budget.',
        NutrientLevel.moderate =>
          '$ex carb $exWord, ${_pct(share)} of your meal budget. Count it in your meal.',
        NutrientLevel.high =>
          '$ex carb $exWord, more than 30% of your meal budget. A smaller portion fits better.',
      });
    } else {
      why.add(switch (NutritionAnalysisService.shareLevel(share)) {
        NutrientLevel.low => 'A small part of your $label for this portion.',
        NutrientLevel.moderate => '${_pct(share)} of your $label in this portion.',
        NutrientLevel.high =>
          '${_pct(share)} of your $label, a large share. A smaller portion fits better.',
      });
    }

    // Why the level is higher than the main share says.
    final String? decider = area.decidedBy;

    if (decider != null && area.level!.index > NutritionAnalysisService.shareLevel(share).index) {
      final NutrientAssessment d = a.nutrients[decider]!;
      final NutrientLevel dShare = NutritionAnalysisService.shareLevel(d.share ?? 0);

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
        'Good news: it has ${_f(fibre.amount, 'g')} g of fibre, about '
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
        return a.nutrients['Carbohydrate'];
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
    final GoalEnergyResult? goal = a.targets.goalAdjusted ? a.targets.goal : null;
    final String energyOf = goal == null
        ? 'the energy you need in a day'
        : goal.changeKcal < 0
            ? 'your daily energy guide for weight loss'
            : 'your daily energy guide for weight gain';

    final String? energyLine = energy?.share == null
        ? null
        : 'That is ${fraction(energy!.share!)} of $energyOf '
            '(${_pct(energy.share!)}).';

    // ---- good: rated nutrients that are low --------------
    final List<String> low = <String>[
      for (final String name in <String>['Total Sugars', 'Sodium', 'Saturated Fat', 'Total Fat'])
        if (a.nutrients[name]?.level == NutrientLevel.low) _plainName(name),
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

    if (now == null) return 'Check the label values with Edit if anything looks wrong.';

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
