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
      expect(card.label, 'Estimated daily energy need');
      expect(card.rangeText, 'Likely 1,850–2,330 kcal');
    });

    test('W-T11 an own energy target is exact and labelled "Your own energy target"', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        const NutritionProfile(providerEnergyKcal: 1234),
      );

      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      expect(card.kcalText, '1,234');
      expect(card.approximate, isFalse);
      expect(card.label, 'Your own energy target');
      expect(card.rangeText, isNull);
    });

    DailyTargets targets(String goal, {double weightKg = 65, String sex = 'female'}) =>
        NutritionAnalysisService.targetsFor(
          NutritionProfile(
            sex: sex,
            ageYears: 45,
            weightKg: weightKg,
            heightCm: 158,
            activityLevel: 'Low active',
            weightGoal: goal,
          ),
        );

    test('W-T09 lose: the same maintenance energy, not a weight-loss target', () {
      final DailyTargets t = targets('lose');
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(t, goal: 'Lose weight');

      expect(t.energyKcal, closeTo(2092.2, 0.1));
      expect(t.goalEnergyKcal, closeTo(2092.2, 0.1));
      expect(card.kcalText, '2,090');
      expect(card.label, 'Estimated daily energy need');
      expect(card.rangeText, 'Likely 1,850–2,330 kcal');
      expect(card.note, contains('not a weight-loss target'));
    });

    test('W-T10 gain: the same maintenance energy, nothing added', () {
      final EnergyGuideCard card = EnergyGuideCard.fromTargets(targets('gain'), goal: 'Gain weight');

      expect(card.kcalText, '2,090');
      expect(card.label, 'Estimated daily energy need');
      expect(card.note, contains('not a weight-gain target'));
    });

    test('W-T19 lose with BMI under 18.5: still maintenance, no deficit', () {
      // 45 kg, 158 cm -> BMI 18.0
      final DailyTargets t = targets('lose', weightKg: 45);

      expect(t.goalEnergyKcal, closeTo(t.energyKcal, 0.01));
      expect(t.goal, isNull);
    });

    test('W-T20 no floor is needed: the energy is never cut', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        const NutritionProfile(
          sex: 'female',
          ageYears: 70,
          weightKg: 47,
          heightCm: 158,
          activityLevel: 'Inactive',
          weightGoal: 'lose',
        ),
      );

      // EER 584.90 - 490.70 + 903.76 + 550.37 = 1548.3.
      expect(t.goalEnergyKcal, closeTo(1548.3, 0.1));
    });
  });

  group('Energy target from a doctor or dietitian', () {
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
