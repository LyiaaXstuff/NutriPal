// =======================================================
// VALUE CHECK SERVICE (Quick verification)
// =======================================================
//
// Finds values that look misread, so NutriPal can ask the
// user to compare them with the pack BEFORE judging the
// product. No issues = straight to the result; the Quick
// verification screen never appears.
//
// Checks (each cell is flagged at most once):
//   1. Unit could not be read.
//   2. Per serving does not match per 100 x serving size
//      (with a "decimal point missing" special case).
//   3. A part is bigger than its whole (sugars >
//      carbohydrate, saturated fat > total fat).
//   4. kJ and kcal in the same cell disagree.
//   5. Energy does not match 4C + 4P + 9F.
//   6. The AI reading could not be confirmed on the phone.
//
// Pure Dart, unit tested.
// =======================================================

import 'dart:math' as math;

import '../models/nutrition_label_data.dart';
import 'nutrition_analysis_service.dart';

enum ValueIssueKind {
  unitMissing,
  doesNotAddUp,
  decimalMissing,
  partExceedsWhole,
  energyMismatch,
  notConfirmed,
}

class ValueIssue {
  final int row;
  final int column;
  final int valueIndex;

  final String nutrient;
  final String columnLabel;

  final NutritionValue current;

  final ValueIssueKind kind;

  // Explanation for the user.
  final String message;

  // "Use 92 kcal". Null when NutriPal cannot tell.
  final double? suggestedAmount;

  // Unit for the suggestion (also the fix for unitMissing).
  final String suggestedUnit;

  const ValueIssue({
    required this.row,
    required this.column,
    required this.valueIndex,
    required this.nutrient,
    required this.columnLabel,
    required this.current,
    required this.kind,
    required this.message,
    required this.suggestedAmount,
    required this.suggestedUnit,
  });

  String get tag => switch (kind) {
        ValueIssueKind.unitMissing => 'Unit missing',
        ValueIssueKind.doesNotAddUp => "Doesn't add up",
        ValueIssueKind.decimalMissing => 'Hard to read',
        ValueIssueKind.partExceedsWhole => "Doesn't add up",
        ValueIssueKind.energyMismatch => "Doesn't add up",
        ValueIssueKind.notConfirmed => 'Please check',
      };
}

class ValueCheckService {
  ValueCheckService._();

  static const Map<String, String> _usualUnits = <String, String>{
    'Energy': 'kcal',
    'Protein': 'g',
    'Total Fat': 'g',
    'Saturated Fat': 'g',
    'Trans Fat': 'g',
    'Monounsaturated Fat': 'g',
    'Polyunsaturated Fat': 'g',
    'Carbohydrate': 'g',
    'Total Sugars': 'g',
    'Added Sugars': 'g',
    'Dietary Fibre': 'g',
    'Sodium': 'mg',
    'Salt': 'g',
    'Cholesterol': 'mg',
    'Potassium': 'mg',
    'Calcium': 'mg',
    'Iron': 'mg',
    'Magnesium': 'mg',
    'Phosphorus': 'mg',
    'Zinc': 'mg',
  };

  static const List<List<String>> _partOfWhole = <List<String>>[
    <String>['Total Sugars', 'Carbohydrate'],
    <String>['Added Sugars', 'Carbohydrate'],
    <String>['Saturated Fat', 'Total Fat'],
    <String>['Trans Fat', 'Total Fat'],
  ];

  static List<ValueIssue> find(NutritionLabelData data) {
    final Map<String, ValueIssue> found = <String, ValueIssue>{};

    void add(ValueIssue issue) {
      found.putIfAbsent('${issue.row}:${issue.column}', () => issue);
    }

    _unitMissing(data, add);
    _servingVsPer100(data, add);
    _partBiggerThanWhole(data, add);
    _energyUnits(data, add);
    _energyFromMacros(data, add, found.keys.toSet());
    _notConfirmed(data, add);

    final List<ValueIssue> issues = found.values.toList()
      ..sort((ValueIssue a, ValueIssue b) =>
          a.row != b.row ? a.row - b.row : a.column - b.column);

    return issues;
  }

  /// Values NutriPal checked and found nothing wrong with.
  static int countValues(NutritionLabelData data) {
    int n = 0;

    for (final NutrientRow row in data.nutrients) {
      for (final List<NutritionValue> cell in row.valuesByColumn) {
        if (cell.isNotEmpty) n++;
      }
    }

    return n;
  }

  // =====================================================
  // 1. UNIT MISSING
  // =====================================================

  static void _unitMissing(
    NutritionLabelData data,
    void Function(ValueIssue) add,
  ) {
    for (int r = 0; r < data.nutrients.length; r++) {
      final NutrientRow row = data.nutrients[r];

      for (int c = 0; c < row.valuesByColumn.length; c++) {
        final List<NutritionValue> cell = row.valuesByColumn[c];

        for (int i = 0; i < cell.length; i++) {
          if (cell[i].unit != '?') continue;

          final String? usual = _usualUnits[row.name];

          add(ValueIssue(
            row: r,
            column: c,
            valueIndex: i,
            nutrient: row.name,
            columnLabel: _columnLabel(data, c),
            current: cell[i],
            kind: ValueIssueKind.unitMissing,
            message: usual == null
                ? 'NutriPal could not read the unit. Please type it as printed.'
                : 'NutriPal could not read the unit. Is it $usual?',
            suggestedAmount: usual == null ? null : cell[i].amount,
            suggestedUnit: usual ?? '',
          ));
        }
      }
    }
  }

  // =====================================================
  // 2. PER SERVING vs PER 100
  // =====================================================

  static void _servingVsPer100(
    NutritionLabelData data,
    void Function(ValueIssue) add,
  ) {
    final int s = data.columnIndexFor(NutritionColumnBasis.perServing);
    final int g = data.columnIndexFor(NutritionColumnBasis.per100g);
    final int p = g >= 0 ? g : data.columnIndexFor(NutritionColumnBasis.per100ml);
    final double? size = data.servingSizeAmount;

    if (s < 0 || p < 0 || size == null || size <= 0) return;

    final double ratio = size / 100;
    final String sizeUnit = data.servingSizeUnit ?? (g >= 0 ? 'g' : 'ml');
    final String per100Text = g >= 0 ? 'per 100 g' : 'per 100 ml';

    for (int r = 0; r < data.nutrients.length; r++) {
      final NutrientRow row = data.nutrients[r];

      if (row.valuesByColumn.length <= math.max(s, p)) continue;

      final List<NutritionValue> servingCell = row.valuesByColumn[s];

      for (int i = 0; i < servingCell.length; i++) {
        final NutritionValue a = servingCell[i];

        if (a.unit == '?') continue;

        final int j = row.valuesByColumn[p]
            .indexWhere((NutritionValue b) => b.unit == a.unit);

        if (j < 0) continue;

        final NutritionValue b = row.valuesByColumn[p][j];
        final double expected = b.amount * ratio;

        // Labels round small numbers.
        if (a.amount < 1 && expected < 1) break;

        final double tolerance = 0.5 * _precision(a) +
            0.5 * _precision(b) * ratio +
            0.05 * expected;

        if ((a.amount - expected).abs() <= tolerance) break;

        // "38" printed where the pack says "3.8".
        if (!_hasDecimal(a) && (a.amount / 10 - expected).abs() <= tolerance) {
          add(ValueIssue(
            row: r,
            column: s,
            valueIndex: i,
            nutrient: row.name,
            columnLabel: _columnLabel(data, s),
            current: a,
            kind: ValueIssueKind.decimalMissing,
            message: 'The decimal point may be missing. '
                'Did the pack say ${_fmt(a.amount / 10, a.unit)} ${a.unit}?',
            suggestedAmount: a.amount / 10,
            suggestedUnit: a.unit,
          ));
          break;
        }

        // The per 100 value lost its decimal point instead.
        if (!_hasDecimal(b) &&
            (b.amount / 10 * ratio - a.amount).abs() <= tolerance) {
          add(ValueIssue(
            row: r,
            column: p,
            valueIndex: j,
            nutrient: row.name,
            columnLabel: _columnLabel(data, p),
            current: b,
            kind: ValueIssueKind.decimalMissing,
            message: 'The decimal point may be missing. '
                'Did the pack say ${_fmt(b.amount / 10, b.unit)} ${b.unit}?',
            suggestedAmount: b.amount / 10,
            suggestedUnit: b.unit,
          ));
          break;
        }

        final String e = _fmt(expected, a.unit);

        add(ValueIssue(
          row: r,
          column: s,
          valueIndex: i,
          nutrient: row.name,
          columnLabel: _columnLabel(data, s),
          current: a,
          kind: ValueIssueKind.doesNotAddUp,
          message: 'From ${_fmt(b.amount, b.unit)} ${b.unit} $per100Text, '
              'one ${_fmt(size, sizeUnit)} $sizeUnit serving should be '
              'about $e ${a.unit}.',
          suggestedAmount: double.parse(e),
          suggestedUnit: a.unit,
        ));
        break;
      }
    }
  }

  // =====================================================
  // 3. PART BIGGER THAN WHOLE
  // =====================================================

  static void _partBiggerThanWhole(
    NutritionLabelData data,
    void Function(ValueIssue) add,
  ) {
    for (final List<String> pair in _partOfWhole) {
      final int pr = _rowIndex(data, pair[0]);
      final int wr = _rowIndex(data, pair[1]);

      if (pr < 0 || wr < 0) continue;

      final NutrientRow part = data.nutrients[pr];
      final NutrientRow whole = data.nutrients[wr];

      final int columns =
          math.min(part.valuesByColumn.length, whole.valuesByColumn.length);

      for (int c = 0; c < columns; c++) {
        final List<NutritionValue> pc = part.valuesByColumn[c];

        for (int i = 0; i < pc.length; i++) {
          final NutritionValue pv = pc[i];
          final double? partG = NutritionAnalysisService.convertMass(pv.amount, pv.unit, 'g');
          final double? wholeG = _grams(whole.valuesByColumn[c]);

          if (partG == null || wholeG == null) continue;

          if (partG <= wholeG + 0.15) continue;

          final bool decimal = !_hasDecimal(pv) && partG / 10 <= wholeG + 0.15;

          add(ValueIssue(
            row: pr,
            column: c,
            valueIndex: i,
            nutrient: part.name,
            columnLabel: _columnLabel(data, c),
            current: pv,
            kind: decimal
                ? ValueIssueKind.decimalMissing
                : ValueIssueKind.partExceedsWhole,
            message: decimal
                ? 'The decimal point may be missing. '
                    'Did the pack say ${_fmt(pv.amount / 10, pv.unit)} ${pv.unit}?'
                : '${part.name} cannot be more than ${whole.name.toLowerCase()} '
                    '(${_fmt(wholeG, 'g')} g). Please check both values.',
            suggestedAmount: decimal ? pv.amount / 10 : null,
            suggestedUnit: pv.unit,
          ));
          break;
        }
      }
    }
  }

  // =====================================================
  // 4. kJ vs kcal
  // =====================================================

  static void _energyUnits(
    NutritionLabelData data,
    void Function(ValueIssue) add,
  ) {
    final int r = _rowIndex(data, 'Energy');

    if (r < 0) return;

    final NutrientRow row = data.nutrients[r];

    for (int c = 0; c < row.valuesByColumn.length; c++) {
      final List<NutritionValue> cell = row.valuesByColumn[c];

      final int k = cell.indexWhere((NutritionValue v) => v.unit == 'kcal');
      final int j = cell.indexWhere((NutritionValue v) => v.unit == 'kJ');

      if (k < 0 || j < 0) continue;

      final double kcal = cell[k].amount;
      final double kj = cell[j].amount;

      if ((kj - 4.184 * kcal).abs() <= 0.04 * kj + 5) continue;

      final String expected = (kj / 4.184).round().toString();

      add(ValueIssue(
        row: r,
        column: c,
        valueIndex: k,
        nutrient: row.name,
        columnLabel: _columnLabel(data, c),
        current: cell[k],
        kind: ValueIssueKind.energyMismatch,
        message: '${_fmt(kj, 'kJ')} kJ is about $expected kcal, but '
            'NutriPal read ${_fmt(kcal, 'kcal')} kcal.',
        suggestedAmount: double.parse(expected),
        suggestedUnit: 'kcal',
      ));
    }
  }

  // =====================================================
  // 5. ENERGY vs 4C + 4P + 9F
  // =====================================================

  // Skipped for a column whose carbohydrate, protein or
  // fat value is already flagged: that value is the cause.
  static void _energyFromMacros(
    NutritionLabelData data,
    void Function(ValueIssue) add,
    Set<String> flagged,
  ) {
    final int er = _rowIndex(data, 'Energy');
    final int cr = _rowIndex(data, 'Carbohydrate');
    final int pr = _rowIndex(data, 'Protein');
    final int fr = _rowIndex(data, 'Total Fat');

    if (er < 0 || cr < 0 || pr < 0 || fr < 0) return;

    final NutrientRow energy = data.nutrients[er];

    for (int c = 0; c < energy.valuesByColumn.length; c++) {
      final int k = energy.valuesByColumn[c]
          .indexWhere((NutritionValue v) => v.unit == 'kcal');

      if (k < 0) continue;

      if (flagged.contains('$cr:$c') ||
          flagged.contains('$pr:$c') ||
          flagged.contains('$fr:$c')) {
        continue;
      }

      final double? carbs = _gramsAt(data, cr, c);
      final double? protein = _gramsAt(data, pr, c);
      final double? fat = _gramsAt(data, fr, c);

      if (carbs == null || protein == null || fat == null) continue;

      final double kcal = energy.valuesByColumn[c][k].amount;
      final double computed = 4 * carbs + 4 * protein + 9 * fat;

      final double allowed = math.max(25.0, 0.30 * math.max(kcal, computed));

      if ((kcal - computed).abs() <= allowed) continue;

      add(ValueIssue(
        row: er,
        column: c,
        valueIndex: k,
        nutrient: energy.name,
        columnLabel: _columnLabel(data, c),
        current: energy.valuesByColumn[c][k],
        kind: ValueIssueKind.energyMismatch,
        message: '${_fmt(carbs, 'g')} g carbohydrate, ${_fmt(protein, 'g')} g '
            'protein and ${_fmt(fat, 'g')} g fat give about '
            '${computed.round()} kcal, but NutriPal read '
            '${_fmt(kcal, 'kcal')} kcal.',
        suggestedAmount: null,
        suggestedUnit: 'kcal',
      ));
    }
  }

  // =====================================================
  // 6. AI VALUES NOT CONFIRMED ON THE PHONE
  // =====================================================
  //
  // NutritionExtractionService writes
  //   "Please check: Sodium (Per serving): 107mg (not
  //    confirmed by on-device reading)"
  // =====================================================

  static final RegExp _unconfirmed = RegExp(
    r'^Please check: (.+?) \((.+?)\): .* \(not confirmed',
  );

  static void _notConfirmed(
    NutritionLabelData data,
    void Function(ValueIssue) add,
  ) {
    for (final String note in data.notes) {
      final RegExpMatch? m = _unconfirmed.firstMatch(note);

      if (m == null) continue;

      final int r = _rowIndex(data, m.group(1)!);
      final int c = data.columns.indexWhere(
        (NutritionColumn col) => col.label == m.group(2),
      );

      if (r < 0 || c < 0 || c >= data.nutrients[r].valuesByColumn.length) {
        continue;
      }

      final List<NutritionValue> cell = data.nutrients[r].valuesByColumn[c];

      if (cell.isEmpty) continue;

      add(ValueIssue(
        row: r,
        column: c,
        valueIndex: 0,
        nutrient: data.nutrients[r].name,
        columnLabel: _columnLabel(data, c),
        current: cell.first,
        kind: ValueIssueKind.notConfirmed,
        message: 'NutriPal could not double-check this value. '
            'Compare it with the pack.',
        suggestedAmount: null,
        suggestedUnit: cell.first.unit,
      ));
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  static int _rowIndex(NutritionLabelData data, String name) =>
      data.nutrients.indexWhere((NutrientRow r) => r.name == name && r.hasAnyValue);

  static String _columnLabel(NutritionLabelData data, int c) {
    if (c >= data.columns.length) return 'value';

    return switch (data.columns[c].basis) {
      NutritionColumnBasis.perServing => 'per serving',
      NutritionColumnBasis.per100g => 'per 100 g',
      NutritionColumnBasis.per100ml => 'per 100 ml',
      NutritionColumnBasis.unknown => data.columns[c].label.toLowerCase(),
    };
  }

  static double? _grams(List<NutritionValue> cell) {
    for (final NutritionValue v in cell) {
      final double? g = NutritionAnalysisService.convertMass(v.amount, v.unit, 'g');

      if (g != null) return g;
    }

    return null;
  }

  static double? _gramsAt(NutritionLabelData data, int row, int column) {
    final NutrientRow r = data.nutrients[row];

    if (column >= r.valuesByColumn.length) return null;

    return _grams(r.valuesByColumn[column]);
  }

  static bool _hasDecimal(NutritionValue v) {
    if (v.rawText.isEmpty || v.rawText == 'calculated') {
      return v.amount != v.amount.roundToDouble();
    }

    return RegExp(r'\d[.,]\d').hasMatch(v.rawText);
  }

  // Size of the last printed digit: "14.7" -> 0.1, "6" -> 1.
  static double _precision(NutritionValue value) {
    final RegExpMatch? number =
        RegExp(r'\d+(?:[.,](\d+))?').firstMatch(value.rawText);

    if (number == null) {
      return value.amount == value.amount.roundToDouble() ? 1 : 0.1;
    }

    final int decimals = number.group(1)?.length ?? 0;

    return math.pow(10, -decimals).toDouble();
  }

  static String _fmt(double v, String unit) =>
      NutritionAnalysisService.formatAmount(v, unit);
}
