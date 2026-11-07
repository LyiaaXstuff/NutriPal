// =======================================================
// LABEL READING ASSESSOR
// =======================================================
//
// Pure Dart (testable without a phone).
//
// 1. problems(): should the on-device reading be trusted,
//    or should NutriPal ask the AI to read the table?
//
// 2. verifyAiReading(): can the AI's answer be trusted?
//    Every number the AI returns is looked up in the
//    on-device OCR text of the same table, and the
//    per-serving / per-100 g values are checked against
//    the serving size. The AI never sees the OCR text, so
//    the two readings are independent.
//
// 3. fromAiJson(): converts the Cloud Function's JSON into
//    NutritionLabelData.
// =======================================================

import 'dart:math' as math;

import '../models/nutrition_label_data.dart';
import 'nutrient_name_normalizer.dart';

class AiVerification {
  // Values with a number that were looked up in the OCR.
  final int checked;

  // Of those, how many the OCR also saw.
  final int confirmed;

  // "Natrium (Setiap hidangan): 107mg" etc.
  final List<String> unconfirmed;

  // Rows whose per-serving and per-100 values disagree.
  final List<String> inconsistentRows;

  // False when there was no OCR text to compare with.
  final bool ocrAvailable;

  const AiVerification({
    required this.checked,
    required this.confirmed,
    required this.unconfirmed,
    required this.inconsistentRows,
    required this.ocrAvailable,
  });

  double get confirmedShare => checked == 0 ? 0 : confirmed / checked;

  bool get accepted {
    if (checked == 0) return false;

    if (inconsistentRows.length > 1) return false;

    return !ocrAvailable || confirmedShare >= 0.7;
  }
}

class LabelReadingAssessor {
  LabelReadingAssessor._();

  // =====================================================
  // SHOULD WE ASK THE AI?
  // =====================================================

  static List<String> problems(NutritionLabelData data) {
    final List<String> result = <String>[];

    if (data.nutrients.length < 3) {
      result.add('Only ${data.nutrients.length} nutrient rows were found.');
    }

    if (data.columns.isEmpty ||
        data.columns.every(
          (NutritionColumn c) => c.basis == NutritionColumnBasis.unknown,
        )) {
      result.add('The per serving / per 100 g headings were not found.');
    }

    final bool missingUnit = data.nutrients.any(
      (NutrientRow row) => row.valuesByColumn.any(
        (List<NutritionValue> cell) =>
            cell.any((NutritionValue v) => v.unit == '?'),
      ),
    );

    if (missingUnit) result.add('Some values have no unit.');

    final bool emptyCell = data.columns.length > 1 &&
        data.nutrients.any(
          (NutrientRow row) =>
              row.valuesByColumn.any((List<NutritionValue> c) => c.isEmpty),
        );

    if (emptyCell) result.add('Some table cells are empty.');

    final bool hasEnergy = data.nutrients.any(
      (NutrientRow row) => RegExp(
        r'energy|tenaga|calorie|kalori',
        caseSensitive: false,
      ).hasMatch(row.name),
    );

    if (data.nutrients.isNotEmpty && !hasEnergy) {
      result.add('The energy row was not found.');
    }

    if (data.notes.isNotEmpty) {
      result.add('Some values were corrected automatically.');
    }

    // Arabic, Thai... cannot be read by on-device OCR:
    // let the AI read the whole label.
    if (data.hasUnreadableScript) {
      result.add('Part of the label is in a script the phone cannot read.');
    }

    final List<String> inconsistent = inconsistentRows(data);

    if (inconsistent.isNotEmpty) {
      result.add(
        'Per serving and per 100 g values disagree for '
        '${inconsistent.join(', ')}.',
      );
    }

    return result;
  }

  // =====================================================
  // PER SERVING ≈ PER 100 × SERVING SIZE / 100 ?
  // =====================================================

  static List<String> inconsistentRows(NutritionLabelData data) {
    final int s = data.columns.indexWhere(
      (NutritionColumn c) => c.basis == NutritionColumnBasis.perServing,
    );

    final int p = data.columns.indexWhere(
      (NutritionColumn c) =>
          c.basis == NutritionColumnBasis.per100g ||
          c.basis == NutritionColumnBasis.per100ml,
    );

    final double? size = data.servingSizeAmount;

    if (s < 0 || p < 0 || size == null || size <= 0) return <String>[];

    final double r = size / 100;

    final List<String> result = <String>[];

    for (final NutrientRow row in data.nutrients) {
      if (row.valuesByColumn.length <= math.max(s, p)) continue;

      for (final NutritionValue a in row.valuesByColumn[s]) {
        final Iterable<NutritionValue> match = row.valuesByColumn[p]
            .where((NutritionValue b) => b.unit == a.unit && a.unit != '?');

        if (match.isEmpty) continue;

        final NutritionValue b = match.first;
        final double expected = b.amount * r;

        // Labels round values, so small numbers are skipped.
        if (a.amount < 1 || expected < 1) break;

        // Allowed difference = the rounding of both printed
        // numbers ("6" can be 5.5-6.4, "4.6" can be 4.55-4.64)
        // plus 5 %. "14.7 vs 6 x 3.2" is flagged, "6 vs 2 x
        // 3.2" is not.
        final double tolerance = 0.5 * _precision(a) +
            0.5 * _precision(b) * r +
            0.05 * expected;

        if ((a.amount - expected).abs() > tolerance) {
          result.add(row.name);
        }

        break;
      }
    }

    return result;
  }

  // Size of the last printed digit: "14.7" -> 0.1, "6" -> 1.
  static double _precision(NutritionValue value) {
    final RegExpMatch? number =
        RegExp(r'\d+(?:[.,](\d+))?').firstMatch(value.rawText);

    if (number == null) return 0.1;

    final int decimals = number.group(1)?.length ?? 0;

    return math.pow(10, -decimals).toDouble();
  }

  // =====================================================
  // CAN WE TRUST THE AI?
  // =====================================================

  static AiVerification verifyAiReading(
    NutritionLabelData ai,
    String ocrText,
  ) {
    final Set<String> seen = _numbersIn(ocrText);

    int checked = 0;
    int confirmed = 0;
    final List<String> unconfirmed = <String>[];

    for (final NutrientRow row in ai.nutrients) {
      for (int j = 0; j < row.valuesByColumn.length; j++) {
        for (final NutritionValue v in row.valuesByColumn[j]) {
          checked++;

          if (seen.contains(_key(v.amount))) {
            confirmed++;
          } else {
            final String column =
                j < ai.columns.length ? ai.columns[j].label : 'column ${j + 1}';

            unconfirmed.add(
              '${row.name} ($column): '
              '${v.rawText.isEmpty ? '${_format(v.amount)} ${v.unit}' : v.rawText}',
            );
          }
        }
      }
    }

    return AiVerification(
      checked: checked,
      confirmed: confirmed,
      unconfirmed: unconfirmed,
      inconsistentRows: inconsistentRows(ai),
      ocrAvailable: seen.isNotEmpty,
    );
  }

  // Every number the OCR saw, including the "g read as 9"
  // variant ("0.59" also counts as 0.5).
  static Set<String> _numbersIn(String text) {
    final Set<String> result = <String>{};

    for (final RegExpMatch m
        in RegExp(r'[0-9oOlI]+(?:[.,][0-9oOlI]+)?').allMatches(text)) {
      final String raw = m.group(0)!;

      if (!RegExp(r'\d').hasMatch(raw)) continue;

      final String digits = raw
          .replaceAll(RegExp(r'[oO]'), '0')
          .replaceAll(RegExp(r'[lI]'), '1');

      final double? value = _toAmount(digits);

      if (value != null) result.add(_key(value));

      if (RegExp(r'[.,]\d*9$').hasMatch(digits)) {
        final double? cut = _toAmount(digits.substring(0, digits.length - 1));

        if (cut != null) result.add(_key(cut));
      }
    }

    return result;
  }

  static double? _toAmount(String digits) {
    String value = digits;

    if (value.endsWith('.') || value.endsWith(',')) {
      value = value.substring(0, value.length - 1);
    }

    if (RegExp(r'^[1-9]\d{0,2},\d{3}$').hasMatch(value)) {
      value = value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }

    return double.tryParse(value);
  }

  static String _key(double value) => value.toStringAsFixed(3);

  static String _format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  // =====================================================
  // CLOUD FUNCTION JSON -> NutritionLabelData
  // =====================================================

  static NutritionLabelData fromAiJson(Map<String, dynamic> json) {
    final Map<String, dynamic> label =
        (json['label'] as Map?)?.cast<String, dynamic>() ?? json;

    final List<dynamic> rawColumns = label['columns'] as List? ?? <dynamic>[];

    final List<int> keptIndexes = <int>[];
    final List<NutritionColumn> columns = <NutritionColumn>[];

    for (int i = 0; i < rawColumns.length; i++) {
      final Map<dynamic, dynamic> c = rawColumns[i] as Map? ?? <dynamic, dynamic>{};

      final String basisText = c['basis'] as String? ?? 'other';

      // NutriPal does not use % NRV columns.
      if (basisText == 'percent') continue;

      final NutritionColumnBasis basis = switch (basisText) {
        'per_serving' => NutritionColumnBasis.perServing,
        'per_100g' => NutritionColumnBasis.per100g,
        'per_100ml' => NutritionColumnBasis.per100ml,
        _ => NutritionColumnBasis.unknown,
      };

      final String printed = (c['label'] as String? ?? '').trim();

      final String columnLabel = switch (basis) {
        NutritionColumnBasis.perServing =>
          printed.isEmpty ? 'Per serving' : printed,
        NutritionColumnBasis.per100g => 'Per 100 g',
        NutritionColumnBasis.per100ml => 'Per 100 ml',
        NutritionColumnBasis.unknown =>
          printed.isEmpty ? 'Column ${columns.length + 1}' : printed,
      };

      keptIndexes.add(i);

      columns.add(
        NutritionColumn(
          id: switch (basis) {
            NutritionColumnBasis.perServing => 'per_serving',
            NutritionColumnBasis.per100g => 'per_100g',
            NutritionColumnBasis.per100ml => 'per_100ml',
            NutritionColumnBasis.unknown => 'unknown_$i',
          },
          label: columnLabel,
          basis: basis,
          xCenter: i.toDouble(),
        ),
      );
    }

    final List<NutrientRow> nutrients = <NutrientRow>[];

    final List<dynamic> rawRows = label['nutrients'] as List? ?? <dynamic>[];

    for (final dynamic rawRow in rawRows) {
      if (rawRow is! Map) continue;

      final String name = (rawRow['name'] as String? ?? '').trim();

      if (name.isEmpty) continue;

      final List<dynamic> cells = rawRow['cells'] as List? ?? <dynamic>[];

      final List<List<NutritionValue>> valuesByColumn = <List<NutritionValue>>[
        for (final int i in keptIndexes)
          <NutritionValue>[
            if (i < cells.length && cells[i] is Map)
              for (final dynamic v
                  in ((cells[i] as Map)['values'] as List? ?? <dynamic>[]))
                if (v is Map && v['amount'] is num)
                  NutritionValue(
                    amount: (v['amount'] as num).toDouble(),
                    unit: _unit(v['unit'] as String?),
                    rawText: (v['printed'] as String? ?? '').trim(),
                  ),
          ],
      ];

      if (valuesByColumn.every((List<NutritionValue> c) => c.isEmpty)) {
        continue;
      }

      // Name printed only in Arabic (or another script):
      // the AI also gives the English name to standardise.
      final String englishName =
          (rawRow['english_name'] as String? ?? '').trim();

      final NormalizedNutrientName printed =
          NutrientNameNormalizer.normalizeDetailed(name);

      final String canonical = !printed.wasStandardized && englishName.isNotEmpty
          ? NutrientNameNormalizer.normalize(englishName)
          : printed.canonicalName;

      nutrients.add(
        NutrientRow(
          name: canonical,
          rawName: formatNutrientName(NutrientNameNormalizer.clean(name)),
          order: nutrients.length,
          valuesByColumn: valuesByColumn,
        ),
      );
    }

    final Map<dynamic, dynamic>? serving = label['serving_size'] as Map?;
    final Map<dynamic, dynamic>? physical = label['physical_serving'] as Map?;

    return NutritionLabelData(
      servingSizeAmount: (serving?['amount'] as num?)?.toDouble(),
      servingSizeUnit: serving?['unit'] as String?,
      servingsPerPackage: (label['servings_per_package'] as num?)?.toDouble(),
      servingUnitAmount: (physical?['amount'] as num?)?.toDouble(),
      servingUnitName: physical?['name'] as String?,
      columns: columns,
      nutrients: nutrients,
      rawText: '',
      extractionMethod: NutritionExtractionMethod.ai,
      notes: <String>[
        for (final dynamic note in (label['notes'] as List? ?? <dynamic>[]))
          if (note is String && note.trim().isNotEmpty) note.trim(),
      ],
    );
  }

  static String _unit(String? unit) {
    switch (unit) {
      case 'g':
      case 'mg':
      case 'µg':
      case 'kcal':
      case 'kJ':
      case 'ml':
      case 'IU':
      case '%':
        return unit!;
      case 'mcg':
      case 'ug':
      case 'μg':
        return 'µg';
      case 'kj':
        return 'kJ';
    }

    return '?';
  }
}
