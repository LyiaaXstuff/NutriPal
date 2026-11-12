import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import 'nutrition_analysis_service.dart';

// =======================================================
// AGENT SUMMARY (per 100 g / ml, for Ask NutriPal)
// =======================================================
//
// One small, profile-free summary of a confirmed label:
// every nutrient per 100 g or 100 ml, plus the Layer 1
// (FSA traffic-light) level where one exists.
//
// Used in two places, so both always agree:
//
//   AskNutriPalService.buildContext   per_100 of the
//                                     product in the chat
//   FirestoreScanHistoryRepository    agentSummary field
//                                     of each scan doc,
//                                     read by the
//                                     compare_with_history
//                                     tool on the server
//
// It holds no name, email, birthday or health details.
// The share of the user's limits is NOT stored here: the
// server works that out from the current profile, so a
// profile change never leaves old numbers behind.
// =======================================================

class AgentSummary {
  AgentSummary._();

  /// Bump when the shape changes; older docs are rewritten
  /// once when the history loads.
  static const int version = 1;

  static const Set<String> _levelled = <String>{
    'Total Fat',
    'Saturated Fat',
    'Total Sugars',
    'Sodium',
  };

  static const Map<String, double> _toGrams = <String, double>{
    'g': 1,
    'mg': 0.001,
    'µg': 0.000001,
    'mcg': 0.000001,
  };

  /// The Firestore map for one label, or null when no
  /// nutrient can be given per 100 g / ml.
  static Map<String, dynamic>? forLabel(NutritionLabelData data) {
    final List<Map<String, dynamic>> rows = per100(data);

    if (rows.isEmpty) return null;

    final ProductForm form = NutritionAnalysisService.formOf(data);

    return <String, dynamic>{
      'v': version,
      'form': form.name,
      'basis': form == ProductForm.drink ? 'per 100 ml' : 'per 100 g',
      'per100': <Map<String, dynamic>>[
        for (final Map<String, dynamic> row in rows)
          <String, dynamic>{
            ...row,
            if (levelFor(row['name'] as String, row['amount'] as double, row['unit'] as String, form)
                case final NutrientLevel level)
              'level': level.label,
          },
      ],
    };
  }

  /// Layer 1 level of one per-100 value (null when FSA has
  /// no threshold for it or the unit is not a mass).
  static NutrientLevel? levelFor(String name, double amount, String unit, ProductForm form) {
    if (!_levelled.contains(name)) return null;

    final double? grams = _toGrams[unit] == null ? null : amount * _toGrams[unit]!;

    if (grams == null) return null;

    if (name == 'Sodium') {
      return NutritionAnalysisService.productLevel(
        'Salt',
        grams * AnalysisRules.saltPerSodium,
        form,
      );
    }

    return NutritionAnalysisService.productLevel(name, grams, form);
  }

  /// Every nutrient per 100 g / ml: from the label's own
  /// per-100 column, or per serving x 100 / serving size.
  /// Energy prefers kcal over kJ.
  static List<Map<String, dynamic>> per100(NutritionLabelData data) {
    final int g = data.columnIndexFor(NutritionColumnBasis.per100g);
    final int p100 = g >= 0 ? g : data.columnIndexFor(NutritionColumnBasis.per100ml);
    final int ps = data.columnIndexFor(NutritionColumnBasis.perServing);
    final double? size = data.servingSizeAmount;

    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];

    for (final NutrientRow row in data.nutrients) {
      List<NutritionValue> cell = const <NutritionValue>[];
      double factor = 1;

      if (p100 >= 0 && p100 < row.valuesByColumn.length && row.valuesByColumn[p100].isNotEmpty) {
        cell = row.valuesByColumn[p100];
      } else if (ps >= 0 && ps < row.valuesByColumn.length && size != null && size > 0) {
        cell = row.valuesByColumn[ps];
        factor = 100 / size;
      }

      if (cell.isEmpty) continue;

      NutritionValue v = cell.first;

      for (final NutritionValue c in cell) {
        if (c.unit == 'kcal') v = c;
      }

      if (v.unit == '?') continue;

      rows.add(<String, dynamic>{
        'name': row.name,
        'amount': round(v.amount * factor),
        'unit': v.unit,
      });
    }

    return rows;
  }

  static double round(double v) => double.parse(v.toStringAsFixed(v.abs() >= 10 ? 1 : 2));
}
