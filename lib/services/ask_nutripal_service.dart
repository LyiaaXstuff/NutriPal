import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../models/profile_setup_data.dart';
import 'nutrition_analysis_service.dart';

// =======================================================
// ASK NUTRIPAL SERVICE (Layer 4)
// =======================================================
//
// Sends the analysis NutriPal already computed, plus the
// chat so far, to the askNutriPal Cloud Function. Claude
// explains it and can recalculate other portions; it never
// sets levels or limits. The API key stays on the server.
//
// Privacy: no name, email or date of birth is sent, only
// the label, the user's health areas, goal and limits.
// =======================================================

class AskNutriPalException implements Exception {
  final String message;

  const AskNutriPalException(this.message);

  @override
  String toString() => message;
}

class ChatTurn {
  // 'user' or 'assistant'
  final String role;
  final String text;

  // What the agent did ("Recalculated for 472 ml").
  final List<String> steps;

  const ChatTurn({required this.role, required this.text, this.steps = const <String>[]});
}

class AskNutriPalService {
  AskNutriPalService._();

  // Must match `region` in functions/index.js.
  static const String region = 'asia-southeast1';

  static const String functionName = 'askNutriPal';

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  // =====================================================
  // CONTEXT (pure, unit tested)
  // =====================================================

  static Map<String, dynamic> buildContext({
    required String productName,
    required NutritionLabelData data,
    required NutritionAnalysis analysis,
    required ProfileSetupData profile,
  }) {
    final DailyTargets t = analysis.targets;

    final Map<String, List<double>> guide = analysis.form == ProductForm.drink
        ? AnalysisRules.drinkThresholds
        : AnalysisRules.foodThresholds;

    return <String, dynamic>{
      'product': <String, dynamic>{
        'name': productName,
        'form': analysis.form.name,
        if (data.servingSizeAmount != null)
          'serving_size': <String, dynamic>{
            'amount': data.servingSizeAmount,
            'unit': data.servingSizeUnit,
          },
        if (data.servingsPerPackage != null) 'servings_per_package': data.servingsPerPackage,
      },
      'per_100': _per100(data),
      'portion_rated_by_app': <String, dynamic>{
        if (analysis.portionAmount != null) 'amount': analysis.portionAmount,
        if (analysis.portionUnit != null) 'unit': analysis.portionUnit,
        if (analysis.portionServings != null) 'servings': _r(analysis.portionServings!),
      },
      'user': <String, dynamic>{
        'health_areas': <String>[
          for (final AreaAssessment a in analysis.areas) a.area.title,
        ],
        if (profile.weightGoal != null) 'weight_goal': profile.weightGoal,
        if (profile.diabetesType != null) 'diabetes_type': profile.diabetesType,
      },
      'targets': <String, dynamic>{
        'energy_kcal': _r(t.energyKcal),
        'energy_is_personal': t.energyIsPersonal,
        'sodium_mg': _r(t.sodiumMg),
        'free_sugars_g': _r(t.freeSugarsG),
        'total_fat_g': _r(t.totalFatG),
        'saturated_fat_g': _r(t.saturatedFatG),
        'trans_fat_g': _r(t.transFatG),
        'carbs_per_meal_g': _r(t.carbsPerMealG),
        'fibre_g': _r(t.fibreG),
        'set_by_provider': t.setByProvider.toList(),
      },
      'analysis': <String, dynamic>{
        'overall': analysis.overall?.label ?? 'not enough information',
        'areas': <Map<String, dynamic>>[
          for (final AreaAssessment a in analysis.areas)
            <String, dynamic>{
              'area': a.area.title,
              'level': a.level?.label ?? 'not enough information',
              if (a.decidedBy != null) 'decided_by': a.decidedBy,
              'nutrients': <Map<String, dynamic>>[
                for (final NutrientAssessment n in a.nutrients)
                  <String, dynamic>{
                    'name': n.name,
                    'amount': _r(n.amount),
                    'unit': n.unit,
                    if (n.share != null) 'share_of_limit_percent': (n.share! * 100).round(),
                    if (n.productLevel != null)
                      'product_level_per_100': n.productLevel!.label,
                    'level': n.level?.label,
                  },
              ],
              if (a.missing.isNotEmpty) 'not_on_label': a.missing,
            },
        ],
      },
      'guide': <String, dynamic>{
        'basis': analysis.per100Label,
        'low_limits': <String, dynamic>{
          'total_fat_g': guide['Total Fat']![0],
          'saturated_fat_g': guide['Saturated Fat']![0],
          'total_sugars_g': guide['Total Sugars']![0],
          'sodium_mg': _r(guide['Salt']![0] / AnalysisRules.saltPerSodium * 1000),
        },
        'high_above': <String, dynamic>{
          'total_fat_g': guide['Total Fat']![1],
          'saturated_fat_g': guide['Saturated Fat']![1],
          'total_sugars_g': guide['Total Sugars']![1],
          'sodium_mg': _r(guide['Salt']![1] / AnalysisRules.saltPerSodium * 1000),
        },
      },
      'rules': 'Levels: share of limit up to 10% Low, up to 30% Moderate, above '
          '30% High${AnalysisRules.combineRule == CombineRule.worseOfBoth ? ', and never lower than the per-100 traffic light' : ''}.',
    };
  }

  static double _r(double v) => double.parse(v.toStringAsFixed(v.abs() >= 10 ? 1 : 2));

  /// Every nutrient per 100 g / ml (from the label, or from
  /// per serving and the serving size).
  static List<Map<String, dynamic>> _per100(NutritionLabelData data) {
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
        'amount': _r(v.amount * factor),
        'unit': v.unit,
      });
    }

    return rows;
  }

  // =====================================================
  // ASK
  // =====================================================

  static Future<ChatTurn> ask({
    required Map<String, dynamic> context,
    required List<ChatTurn> history,
  }) async {
    if (!isAvailable) {
      throw const AskNutriPalException(
        'Ask NutriPal needs Firebase. Check your internet connection and try again.',
      );
    }

    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: region).httpsCallable(
      functionName,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );

    try {
      final HttpsCallableResult<dynamic> result = await callable.call(<String, dynamic>{
        'context': context,
        'messages': <Map<String, String>>[
          for (final ChatTurn t in history) <String, String>{'role': t.role, 'text': t.text},
        ],
      });

      final Object? data = result.data;

      if (data is! Map || data['answer'] is! String) {
        throw const AskNutriPalException('Unexpected answer. Please try again.');
      }

      return ChatTurn(
        role: 'assistant',
        text: data['answer'] as String,
        steps: <String>[
          for (final dynamic s in (data['steps'] as List? ?? <dynamic>[]))
            if (s is String) s,
        ],
      );
    } on FirebaseFunctionsException catch (error) {
      throw AskNutriPalException(
        error.code == 'not-found'
            ? 'Ask NutriPal is not deployed yet (firebase deploy --only functions).'
            : error.message ?? 'Ask NutriPal failed (${error.code}).',
      );
    }
  }
}
