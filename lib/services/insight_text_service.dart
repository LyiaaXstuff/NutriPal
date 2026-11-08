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

  static OverallText overall(NutritionAnalysis a) {
    final List<AreaAssessment> judged =
        a.areas.where((AreaAssessment x) => x.level != null).toList();

    String names(NutrientLevel level) {
      final List<String> list = <String>[
        for (final AreaAssessment x in judged)
          if (x.level == level) x.area.title.toLowerCase(),
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

    if (fibre != null && (fibre.share ?? 0) > 0.10) {
      why.add(
        'Bonus: ${_f(fibre.amount, 'g')} g fibre '
        '(${_pct(fibre.share!)} of your daily ${_f(fibre.target!, 'g')} g).',
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

      tips.add(ProductTip(
        ok,
        ok
            ? 'Pick products with up to ${_f(limit, unit)} $unit $what ${a.per100Label}. '
                'This one has ${_f(n.per100!, unit)} $unit.'
            : 'For less $what, look for up to ${_f(limit, unit)} $unit ${a.per100Label}. '
                'This one has ${_f(n.per100!, unit)} $unit.',
      ));
    }

    return tips;
  }
}
