// =======================================================
// COMPARE SERVICE
// =======================================================
//
// Compares two saved products for one user. Pure Dart, no
// Flutter, so every rule is unit tested
// (test/compare_service_test.dart).
//
// The numbers come from NutritionAnalysisService.analyse()
// on the labels the user confirmed when scanning, so
// Compare always shows the same values as "Your nutrition
// insights". Nothing is re-read or estimated here.
//
// Two ways to compare:
//
//   Per 100 g / ml  The fair way to compare the products
//                   themselves (the FSA colours are set
//                   per 100 too). Default.
//   Per serving     What one serving of each gives, using
//                   the label's own serving size.
//
// Which product is "better" is decided only by the user's
// health areas (Layer 2 / 3 nutrients of each area, in the
// rules document's order):
//
//   1. The area's key nutrient must be on both labels,
//      otherwise the area says "not enough information".
//   2. The first nutrient (in rule order) where the two
//      products clearly differ decides the area.
//   3. Overall: the product that is better in more areas.
//      An equal split is "mixed" (it depends on what
//      matters most to the user).
//
// Values within the label rounding margin count as "about
// the same" (see [_sameMargin]).
// =======================================================

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import 'nutrition_analysis_service.dart';

enum CompareBasis { per100, perServing }

/// Which product a row, an area or the whole comparison
/// favours.
enum CompareResult {
  first,
  second,

  // Both about the same.
  same,

  // Overall only: each product is better in a different
  // health area.
  mixed,

  // A value is missing from one of the labels.
  unknown,
}

enum NutrientDirection { lowerIsBetter, higherIsBetter, neutral }

// =======================================================
// RESULT TYPES
// =======================================================

class ComparedNutrient {
  // Canonical name ('Sodium', 'Total Sugars').
  final String name;

  final String unit;

  // Values on the chosen basis; null = not on the label.
  final double? first;
  final double? second;

  // Per 100: FSA colour. Per serving: the combined level
  // shown on the insights screen.
  final NutrientLevel? firstLevel;
  final NutrientLevel? secondLevel;

  // neutral = not used by any of the user's health areas,
  // so it is shown but neither side is marked better.
  final NutrientDirection direction;

  final CompareResult result;

  const ComparedNutrient({
    required this.name,
    required this.unit,
    required this.first,
    required this.second,
    required this.firstLevel,
    required this.secondLevel,
    required this.direction,
    required this.result,
  });

  bool get mattersForUser => direction != NutrientDirection.neutral;
}

class AreaComparison {
  final HealthArea area;

  final CompareResult result;

  // Nutrient that decided it, if any.
  final String? decidedBy;

  // One plain sentence for the card.
  final String reason;

  const AreaComparison({
    required this.area,
    required this.result,
    required this.decidedBy,
    required this.reason,
  });
}

class ProductComparison {
  final CompareBasis basis;

  final String firstName;
  final String secondName;

  // Full analyses (default portion), e.g. to show the
  // serving each product uses.
  final NutritionAnalysis firstAnalysis;
  final NutritionAnalysis secondAnalysis;

  final List<ComparedNutrient> nutrients;

  final List<AreaComparison> areas;

  final CompareResult overall;

  // Short sentence under the overall result.
  final String summary;

  // Things the user should know before trusting the
  // comparison (different units, missing serving size...).
  final List<String> notes;

  const ProductComparison({
    required this.basis,
    required this.firstName,
    required this.secondName,
    required this.firstAnalysis,
    required this.secondAnalysis,
    required this.nutrients,
    required this.areas,
    required this.overall,
    required this.summary,
    required this.notes,
  });

  /// "per 100 g", "per 100 ml", "per 100 g / ml" or
  /// "per serving".
  String get basisLabel => CompareService.basisLabel(
        basis,
        firstAnalysis.form,
        secondAnalysis.form,
      );

  String nameOf(CompareResult side) =>
      side == CompareResult.second ? secondName : firstName;
}

// =======================================================
// THE SERVICE
// =======================================================

class CompareService {
  CompareService._();

  /// Rows, in the order shown (only those on at least one
  /// label appear).
  static const List<String> nutrientOrder = <String>[
    'Energy',
    'Carbohydrate',
    'Total Sugars',
    'Total Fat',
    'Saturated Fat',
    'Trans Fat',
    'Sodium',
    'Dietary Fibre',
    'Protein',
  ];

  static String displayName(String name) => switch (name) {
        'Total Sugars' => 'Sugars',
        'Total Fat' => 'Fat',
        'Dietary Fibre' => 'Fibre',
        _ => name,
      };

  static String _lower(String name) => switch (name) {
        'Total Sugars' => 'sugars',
        'Total Fat' => 'total fat',
        'Dietary Fibre' => 'fibre',
        _ => name.toLowerCase(),
      };

  static String basisLabel(
    CompareBasis basis,
    ProductForm first,
    ProductForm second,
  ) {
    if (basis == CompareBasis.perServing) return 'per serving';

    if (first != second) return 'per 100 g / ml';

    return first == ProductForm.drink ? 'per 100 ml' : 'per 100 g';
  }

  /// Per 100 when both labels give (or allow working out)
  /// per 100 values, otherwise per serving.
  static CompareBasis defaultBasis(
    NutritionLabelData first,
    NutritionLabelData second,
  ) {
    bool has100(NutritionLabelData d) =>
        d.hasPer100gColumn ||
        d.hasPer100mlColumn ||
        (d.hasPerServingColumn &&
            d.servingSizeAmount != null &&
            d.servingSizeAmount! > 0);

    return has100(first) && has100(second)
        ? CompareBasis.per100
        : CompareBasis.perServing;
  }

  // =====================================================
  // COMPARE
  // =====================================================

  static ProductComparison compare({
    required NutritionLabelData first,
    required NutritionLabelData second,
    required NutritionProfile profile,
    CompareBasis basis = CompareBasis.per100,
    String firstName = 'Product A',
    String secondName = 'Product B',
  }) {
    final NutritionAnalysis a =
        NutritionAnalysisService.analyse(data: first, profile: profile);
    final NutritionAnalysis b =
        NutritionAnalysisService.analyse(data: second, profile: profile);

    final List<HealthArea> areas = profile.areasToShow;
    final Map<String, NutrientDirection> directions = _directionsFor(areas);

    final String basisText = basisLabel(basis, a.form, b.form);

    // ---- rows ------------------------------------------

    final List<ComparedNutrient> rows = <ComparedNutrient>[];
    final Map<String, ComparedNutrient> byName = <String, ComparedNutrient>{};

    for (final String name in nutrientOrder) {
      final NutrientAssessment? na = a.nutrients[name];
      final NutrientAssessment? nb = b.nutrients[name];

      if (na == null && nb == null) continue;

      final double? va = _value(na, basis);
      final double? vb = _value(nb, basis);

      if (va == null && vb == null) continue;

      final String unit = na?.unit ?? nb!.unit;
      final NutrientDirection direction =
          directions[name] ?? NutrientDirection.neutral;

      final ComparedNutrient row = ComparedNutrient(
        name: name,
        unit: unit,
        first: va,
        second: vb,
        firstLevel: _level(na, basis),
        secondLevel: _level(nb, basis),
        direction: direction,
        result: better(va, vb, unit, direction),
      );

      rows.add(row);
      byName[name] = row;
    }

    // ---- areas -----------------------------------------

    final List<AreaComparison> areaResults = <AreaComparison>[
      for (final HealthArea area in areas)
        _compareArea(area, byName, firstName, secondName, basisText),
    ];

    // ---- overall ---------------------------------------

    final int firstWins =
        areaResults.where((AreaComparison r) => r.result == CompareResult.first).length;
    final int secondWins =
        areaResults.where((AreaComparison r) => r.result == CompareResult.second).length;
    final bool anySame =
        areaResults.any((AreaComparison r) => r.result == CompareResult.same);

    final CompareResult overall;

    if (firstWins > secondWins) {
      overall = CompareResult.first;
    } else if (secondWins > firstWins) {
      overall = CompareResult.second;
    } else if (firstWins > 0) {
      overall = CompareResult.mixed;
    } else if (anySame) {
      overall = CompareResult.same;
    } else {
      overall = CompareResult.unknown;
    }

    return ProductComparison(
      basis: basis,
      firstName: firstName,
      secondName: secondName,
      firstAnalysis: a,
      secondAnalysis: b,
      nutrients: rows,
      areas: areaResults,
      overall: overall,
      summary: _summary(overall, areaResults, firstName, secondName, basisText),
      notes: _notes(basis, a, b, rows, firstName, secondName),
    );
  }

  // =====================================================
  // ONE NUTRIENT
  // =====================================================

  static double? _value(NutrientAssessment? n, CompareBasis basis) {
    if (n == null) return null;

    return basis == CompareBasis.per100 ? n.per100 : n.amount;
  }

  static NutrientLevel? _level(NutrientAssessment? n, CompareBasis basis) {
    if (n == null) return null;

    return basis == CompareBasis.per100 ? n.productLevel : n.level;
  }

  /// Nutrients the user's areas care about. Fibre is a
  /// benefit (more is better) where the rules count it.
  static Map<String, NutrientDirection> _directionsFor(List<HealthArea> areas) {
    final Map<String, NutrientDirection> d = <String, NutrientDirection>{};

    for (final HealthArea area in areas) {
      for (final String n in AnalysisRules.areaNutrients[area]!) {
        d[n] = NutrientDirection.lowerIsBetter;
      }

      if (AnalysisRules.fibreAreas.contains(area)) {
        d['Dietary Fibre'] = NutrientDirection.higherIsBetter;
      }
    }

    return d;
  }

  /// Labels round their values, so small differences are
  /// "about the same": within 5 % of the larger value, or
  /// within 0.2 g / 5 mg / 2 kcal.
  static bool _same(double a, double b, String unit) {
    final double margin = _sameMargin(a, b, unit);

    return (a - b).abs() <= margin;
  }

  static double _sameMargin(double a, double b, String unit) {
    final double absolute = switch (unit) {
      'mg' => 5,
      'kcal' => 2,
      _ => 0.2,
    };

    final double relative = 0.05 * (a.abs() > b.abs() ? a.abs() : b.abs());

    return relative > absolute ? relative : absolute;
  }

  static CompareResult better(
    double? a,
    double? b,
    String unit,
    NutrientDirection direction,
  ) {
    if (a == null || b == null) return CompareResult.unknown;

    if (_same(a, b, unit)) return CompareResult.same;

    return switch (direction) {
      NutrientDirection.lowerIsBetter =>
        a < b ? CompareResult.first : CompareResult.second,
      NutrientDirection.higherIsBetter =>
        a > b ? CompareResult.first : CompareResult.second,
      // Not used by the user's areas: no side is better.
      NutrientDirection.neutral => CompareResult.same,
    };
  }

  // =====================================================
  // ONE HEALTH AREA
  // =====================================================

  static AreaComparison _compareArea(
    HealthArea area,
    Map<String, ComparedNutrient> rows,
    String firstName,
    String secondName,
    String basisText,
  ) {
    final List<String> names = AnalysisRules.areaNutrients[area]!;

    bool onBoth(String n) => rows[n]?.first != null && rows[n]?.second != null;

    // Key nutrient (cholesterol: saturated fat, or failing
    // that total fat, as in the analysis rules).
    final bool hasKey = area == HealthArea.cholesterol
        ? onBoth('Saturated Fat') || onBoth('Total Fat')
        : onBoth(names.first);

    if (!hasKey) {
      final String key = area == HealthArea.cholesterol ? 'Saturated Fat' : names.first;
      final ComparedNutrient? row = rows[key];

      String missingFrom;

      if (row == null || (row.first == null && row.second == null)) {
        missingFrom = 'either label';
      } else if (row.first == null) {
        missingFrom = "$firstName's label";
      } else {
        missingFrom = "$secondName's label";
      }

      return AreaComparison(
        area: area,
        result: CompareResult.unknown,
        decidedBy: null,
        reason: 'Not enough information: ${_lower(key)} is not on $missingFrom.',
      );
    }

    String fmt(double v, String unit) =>
        '${NutritionAnalysisService.formatAmount(v, unit)} $unit';

    ComparedNutrient? firstSame;

    for (final String n in names) {
      final ComparedNutrient? row = rows[n];

      if (row == null || row.first == null || row.second == null) continue;

      if (row.result == CompareResult.same) {
        firstSame ??= row;
        continue;
      }

      final bool firstBetter = row.result == CompareResult.first;
      final String winner = firstBetter ? firstName : secondName;
      final double low = firstBetter ? row.first! : row.second!;
      final double high = firstBetter ? row.second! : row.first!;

      return AreaComparison(
        area: area,
        result: row.result,
        decidedBy: n,
        reason: '$winner is lower in ${_lower(n)}: '
            '${fmt(low, row.unit)} vs ${fmt(high, row.unit)} $basisText.',
      );
    }

    final ComparedNutrient key = firstSame!;

    return AreaComparison(
      area: area,
      result: CompareResult.same,
      decidedBy: key.name,
      reason: 'About the same ${_lower(key.name)}: '
          '${fmt(key.first!, key.unit)} vs ${fmt(key.second!, key.unit)} $basisText.',
    );
  }

  // =====================================================
  // TEXT
  // =====================================================

  static String _summary(
    CompareResult overall,
    List<AreaComparison> areas,
    String firstName,
    String secondName,
    String basisText,
  ) {
    String areaList(CompareResult side) => areas
        .where((AreaComparison a) => a.result == side)
        .map((AreaComparison a) => a.area.title.toLowerCase())
        .join(', ');

    return switch (overall) {
      CompareResult.first =>
        '$firstName fits your health goals better $basisText '
            '(${areaList(CompareResult.first)}).',
      CompareResult.second =>
        '$secondName fits your health goals better $basisText '
            '(${areaList(CompareResult.second)}).',
      CompareResult.mixed =>
        'Each product is better for a different goal: $firstName for '
            '${areaList(CompareResult.first)}, $secondName for '
            '${areaList(CompareResult.second)}. Choose by what matters most to you.',
      CompareResult.same =>
        'Both products are about the same for your health goals $basisText.',
      CompareResult.unknown =>
        'The labels do not show enough of the same nutrients to compare them.',
    };
  }

  static List<String> _notes(
    CompareBasis basis,
    NutritionAnalysis a,
    NutritionAnalysis b,
    List<ComparedNutrient> rows,
    String firstName,
    String secondName,
  ) {
    final List<String> notes = <String>[];

    if (basis == CompareBasis.per100) {
      if (a.form != b.form) {
        notes.add(
          'One product is measured per 100 g and the other per 100 ml, '
          'so this is only a rough comparison.',
        );
      }

      bool noPer100(bool first) =>
          rows.every((ComparedNutrient r) => (first ? r.first : r.second) == null);

      if (rows.isNotEmpty && noPer100(true)) {
        notes.add('$firstName has no per 100 values or serving size on its label. '
            'Try comparing per serving.');
      }

      if (rows.isNotEmpty && noPer100(false)) {
        notes.add('$secondName has no per 100 values or serving size on its label. '
            'Try comparing per serving.');
      }
    } else {
      String unitOf(NutritionAnalysis x) => x.form == ProductForm.drink ? 'ml' : 'g';

      if (a.portion.servings == null) {
        notes.add('$firstName has no serving size on its label, '
            'so 100 ${unitOf(a)} is used for it.');
      }

      if (b.portion.servings == null) {
        notes.add('$secondName has no serving size on its label, '
            'so 100 ${unitOf(b)} is used for it.');
      }

      final double? sa = a.portionAmount;
      final double? sb = b.portionAmount;

      if (a.portion.servings != null &&
          b.portion.servings != null &&
          sa != null &&
          sb != null &&
          !_same(sa, sb, 'g')) {
        String size(double v, NutritionAnalysis x) =>
            '${NutritionAnalysisService.formatAmount(v, 'g')} ${x.portionUnit ?? unitOf(x)}';

        notes.add(
          'The serving sizes differ (${size(sa, a)} vs ${size(sb, b)}). '
          'Per 100 g / ml is fairer for comparing the products themselves.',
        );
      }
    }

    return notes;
  }
}
