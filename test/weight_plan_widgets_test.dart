import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';
import 'package:nutripal/widgets/weight_plan_widgets.dart';

// Validation tests W-T08 to W-T12 and W-T19 to W-T20
// (knowledge base, tab 10):
// what the weight screens show, worked out without a
// device.

void main() {
  group('Energy guide card', () {
    test('an estimate shows ≈, its label and the likely range', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        const NutritionProfile(
          sex: 'female',
          ageYears: 45,
          weightKg: 65,
          heightCm: 158,
          activityLevel: 'Low active',
        ),
      );

      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Maintain weight');

      expect(card.kcalText, '2,090');
      expect(card.approximate, isTrue);
      expect(card.label, 'Estimated daily maintenance energy');
      expect(card.rangeText, 'Likely 1,850–2,330 kcal');
    });

    test('W-T11 a provider figure is exact and "Set by your healthcare provider"', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        const NutritionProfile(providerEnergyKcal: 1234),
      );

      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      expect(card.kcalText, '1,234');
      expect(card.approximate, isFalse);
      expect(card.label, 'Set by your healthcare provider');
      expect(card.rangeText, isNull);
    });

    DailyTargets targets(String goal, {double weightKg = 65, int? change, String sex = 'female'}) =>
        NutritionAnalysisService.targetsFor(
          NutritionProfile(
            sex: sex,
            ageYears: 45,
            weightKg: weightKg,
            heightCm: 158,
            activityLevel: 'Low active',
            weightGoal: goal,
            energyChangeKcal: change,
          ),
        );

    test('W-T09 lose: 500 kcal less by default, shown with maintenance', () {
      final DailyTargets t = targets('lose');
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      // 2092.2 - 500 = 1592.2
      expect(t.energyKcal, closeTo(2092.2, 0.1));
      expect(card.kcalText, '1,590');
      expect(card.label, 'Daily energy guide for weight loss');
      expect(card.rangeText, 'Maintenance ≈ 2,090 kcal − 500 kcal');
      expect(card.note, contains('not a prescription'));
    });

    test('W-T10 gain: 300 kcal more by default; 500 when chosen', () {
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(targets('gain'), goal: 'Gain weight');

      expect(card.kcalText, '2,390');
      expect(card.label, 'Daily energy guide for weight gain');
      expect(card.rangeText, 'Maintenance ≈ 2,090 kcal + 300 kcal');
      expect(
        EnergyGuideCard.fromTargets(targets('gain', change: 500), goal: 'Gain weight').kcalText,
        '2,590',
      );
    });

    test('W-T19 lose with BMI under 18.5: no deficit, referral note', () {
      // 45 kg, 158 cm -> BMI 18.0
      final DailyTargets t = targets('lose', weightKg: 45);
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      expect(t.goalEnergyKcal, closeTo(t.energyKcal, 0.01));
      expect(card.label, 'Estimated daily maintenance energy');
      expect(card.note, contains('talk to a doctor or dietitian'));
    });

    test('W-T20 lose: never below 1,200 kcal for a woman', () {
      // 2092.2 - 750 = 1342.2 (above the floor) ...
      expect(targets('lose', change: 750).goalEnergyKcal, closeTo(1342.2, 0.1));

      // ... a smaller, inactive woman of 50 kg at 158 cm:
      // EER 584.90 - 315.45 + 903.76 + 585.5 = 1758.7;
      // 1758.7 - 750 = 1008.7 -> 1,200.
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        const NutritionProfile(
          sex: 'female',
          ageYears: 45,
          weightKg: 50,
          heightCm: 158,
          activityLevel: 'Inactive',
          weightGoal: 'lose',
          energyChangeKcal: 750,
        ),
      );
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      expect(t.goalEnergyKcal, 1200);
      expect(card.rangeText, contains('1,200 kcal minimum'));
    });

    test('energy change choices and labels', () {
      expect(WeightPlanOptions.energyChangeOptions('Lose weight'), <int>[250, 500, 750]);
      expect(WeightPlanOptions.energyChangeOptions('Gain weight'), <int>[300, 500]);
      expect(WeightPlanOptions.energyChangeOptions('Maintain weight'), isEmpty);
      expect(WeightPlanOptions.energyChangeText('Lose weight', 500), '500 kcal less a day (default)');
      expect(WeightPlanOptions.energyChangeText('Gain weight', 500), '500 kcal more a day');
    });
  });

  group('Calorie target from a doctor or dietitian', () {
    test('empty is fine; 800 to 5,000 is accepted', () {
      expect(WeightPlanOptions.providerTextOk(''), isTrue);
      expect(WeightPlanOptions.providerKcal('1500'), 1500);
      expect(WeightPlanOptions.providerError('1500'), isNull);
    });

    test('W-T12 below 800 kcal is not used', () {
      expect(WeightPlanOptions.providerKcal('700'), isNull);
      expect(WeightPlanOptions.providerError('700'), contains('below 800 kcal'));
    });

    test('W-T11 below 1,200 kcal for a woman is used, with a note', () {
      expect(WeightPlanOptions.providerKcal('1000'), 1000);
      expect(WeightPlanOptions.providerNote('1000', 'Female'), isNotNull);
      expect(WeightPlanOptions.providerNote('1300', 'Female'), isNull);
      expect(WeightPlanOptions.providerNote('1300', 'Male'), isNotNull);
    });
  });

  group('What guidelines say', () {
    test('W-T08 lose with BMI under 18.5: ranges hidden, referral shown', () {
      // 45 kg, 160 cm -> BMI 17.6
      final (String, bool)? g = WeightPlanOptions.goalGuidance(
        goal: 'Lose weight',
        sex: 'Female',
        weightKg: 45,
        heightCm: 160,
      );

      expect(g!.$1, contains('talk to a doctor or dietitian'));
      expect(g.$1, isNot(contains('kcal')));
      expect(g.$2, isFalse);
    });

    test('W-T09 lose: ranges for the user\'s sex, marked as general', () {
      final (String, bool)? woman = WeightPlanOptions.goalGuidance(
        goal: 'Lose weight',
        sex: 'Female',
        weightKg: 70,
        heightCm: 158,
      );
      final (String, bool)? man = WeightPlanOptions.goalGuidance(
        goal: 'Lose weight',
        sex: 'Male',
        weightKg: 90,
        heightCm: 175,
      );

      expect(woman!.$1, contains('500–750 kcal'));
      expect(woman.$1, contains('1,200–1,500'));
      expect(man!.$1, contains('1,500–1,800'));
      expect(woman.$2, isTrue);
    });

    test('W-T10 gain guidance: 300–500 kcal from nourishing foods', () {
      final (String, bool)? g = WeightPlanOptions.goalGuidance(
        goal: 'Gain weight',
        sex: 'Male',
        weightKg: 55,
        heightCm: 175,
      );

      expect(g!.$1, contains('300–500 kcal'));
      expect(g.$2, isTrue);
    });
  });
}
