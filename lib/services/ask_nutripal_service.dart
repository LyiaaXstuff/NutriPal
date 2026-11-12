import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../models/profile_setup_data.dart';
import 'agent_summary.dart';
import 'energy_requirement.dart' show GoalEnergyResult;
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
// The server may also read the signed-in user's own scan
// history (compare_with_history tool) and NutriPal's
// validated guideline notes (search_guidelines tool).
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

  // Knowledge-base entries the answer drew on (GEN-05,
  // DM-12...). Internal, for testing only: never shown in
  // the chat; printed to the debug console.
  final List<String> evidenceIds;

  const ChatTurn({
    required this.role,
    required this.text,
    this.steps = const <String>[],
    this.evidenceIds = const <String>[],
  });
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
      'per_100': AgentSummary.per100(data),
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
        // The energy target each product is judged against
        // (with the weight goal applied).
        'energy_kcal': _r(t.goalEnergyKcal),
        'energy_is_personal': t.energyIsPersonal,
        // Where the energy figure comes from, so the chatbot
        // never calls an estimate a prescription.
        'energy_basis': t.setByProvider.contains('Energy')
            ? 'set by healthcare provider'
            : !t.energyIsPersonal
                ? 'standard 2,000 kcal reference'
                : t.goalAdjusted
                    ? 'NASEM 2023 maintenance estimate '
                        '${t.goal!.changeKcal < 0 ? 'minus' : 'plus'} '
                        '${t.goal!.changeKcal.abs().round()} kcal for the weight goal '
                        '(general guide, adjustable in settings)'
                    : 'NASEM 2023 estimated maintenance energy',
        if (t.goal != null) 'maintenance_energy_kcal': _r(t.goal!.maintenanceKcal),
        if (_goalNote(t) != null) 'energy_goal_note': _goalNote(t),
        if (t.energyLowKcal != null && t.energyHighKcal != null)
          'maintenance_likely_range_kcal': <int>[
            (t.energyLowKcal! / 10).round() * 10,
            (t.energyHighKcal! / 10).round() * 10,
          ],
        // Every limit below is based on maintenance energy
        // (or the provider's figure), not on the goal energy.
        'limits_energy_kcal': _r(t.energyKcal),
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
      // The app's own rule numbers and per-100 amounts, so
      // the recalculate_portion tool rates another amount
      // exactly like the result screen (no second copy of
      // the rules on the server).
      'rating': ratingRules(analysis),
    };
  }

  /// Why the weight goal changed the energy less than
  /// asked, or null.
  static String? _goalNote(DailyTargets t) {
    final GoalEnergyResult? g = t.goal;

    if (g == null) return null;
    if (g.lowBmi) return 'no deficit because BMI is below 18.5';
    if (g.floorApplied && g.floorKcal != null) {
      return 'weight-loss guide kept at or above ${g.floorKcal!.round()} kcal';
    }

    return null;
  }

  /// Layer 1 + Layer 3 inputs for rating any amount.
  static Map<String, dynamic> ratingRules(NutritionAnalysis analysis) {
    return <String, dynamic>{
      'low_share_max': AnalysisRules.lowShare,
      'moderate_share_max': AnalysisRules.highShare,
      'combine': AnalysisRules.combineRule == CombineRule.worseOfBoth ? 'worse_of_both' : 'portion_decides',
      'nutrients': <Map<String, dynamic>>[
        for (final NutrientAssessment n in analysis.nutrients.values)
          if (n.per100 != null)
            <String, dynamic>{
              'name': n.name,
              // In the rule unit (kcal, g, mg), after any
              // kJ or salt conversion the app made.
              'per100': n.per100,
              'unit': n.unit,
              if (n.productLevel != null) 'product_level_per_100': n.productLevel!.label,
              'rated': !n.isBenefit,
            },
      ],
      'areas': <Map<String, dynamic>>[
        for (final AreaAssessment a in analysis.areas)
          <String, dynamic>{
            'area': a.area.title,
            'nutrients': AnalysisRules.areaNutrients[a.area],
            // Without one of these the area cannot be rated.
            'key_any_of': a.area == HealthArea.cholesterol
                ? <String>['Saturated Fat', 'Total Fat']
                : <String>[AnalysisRules.areaNutrients[a.area]!.first],
          },
      ],
    };
  }

  static double _r(double v) => double.parse(v.toStringAsFixed(v.abs() >= 10 ? 1 : 2));

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

      final List<String> evidence = <String>[
        for (final dynamic e in (data['evidence_ids'] as List? ?? <dynamic>[]))
          if (e is String) e,
      ];

      if (kDebugMode && evidence.isNotEmpty) {
        debugPrint('[Ask NutriPal] evidence: ${evidence.join(', ')}');
      }

      return ChatTurn(
        role: 'assistant',
        text: data['answer'] as String,
        steps: <String>[
          for (final dynamic s in (data['steps'] as List? ?? <dynamic>[]))
            if (s is String) s,
        ],
        evidenceIds: evidence,
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
