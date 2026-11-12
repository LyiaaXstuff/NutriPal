import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/energy_requirement.dart';

// Validation tests W-T01 to W-T07 (knowledge base, tab 10).
// W-T01 and W-T02 are NASEM's own worked examples, so the
// equations are checked against the source itself.

EnergyEstimate? eer(String sex, int age, double height, double weight, String activity) =>
    EnergyRequirement.estimate(
      sex: sex,
      ageYears: age,
      heightCm: height,
      weightKg: weight,
      activity: activity,
    );

void main() {
  group('NASEM 2023 EER', () {
    test('W-T01 NASEM example: woman, 22 y, 165 cm, 63 kg, low active = 2,275 kcal', () {
      expect(eer('Female', 22, 165, 63, ActivityLevels.lowActive)!.kcal.round(), 2275);
    });

    test('W-T02 NASEM example: man, 45 y, 175 cm, 100 kg, low active = 3,041 kcal', () {
      expect(eer('Male', 45, 175, 100, ActivityLevels.lowActive)!.kcal.round(), 3041);
    });

    test('W-T03 sample user: 2,092.2 kcal, likely 1,851-2,333', () {
      final EnergyEstimate e = eer('female', 45, 158, 65, ActivityLevels.lowActive)!;

      expect(e.kcal, closeTo(2092.2, 0.1));
      expect(e.standardErrorKcal, 241);
      expect(e.lowKcal, closeTo(1851.2, 0.1));
      expect(e.highKcal, closeTo(2333.2, 0.1));
    });

    test('W-T04 man, 30 y, 175 cm, 75 kg, active: 3,014.2 kcal, SE 342', () {
      final EnergyEstimate e = eer('male', 30, 175, 75, ActivityLevels.active)!;

      expect(e.kcal, closeTo(3014.2, 0.1));
      expect(e.standardErrorKcal, 342);
    });

    test('W-T05 sample user across the four activity levels', () {
      final List<double> kcal = <double>[
        for (final String level in ActivityLevels.all) eer('female', 45, 158, 65, level)!.kcal,
      ];

      expect(kcal[0], closeTo(1934.4, 0.1));
      expect(kcal[1], closeTo(2092.2, 0.1));
      expect(kcal[2], closeTo(2230.2, 0.1));
      expect(kcal[3], closeTo(2445.8, 0.1));
    });

    test('W-T06 age 18: no estimate', () {
      expect(eer('female', 18, 158, 65, ActivityLevels.lowActive), isNull);
      expect(eer('female', 19, 158, 65, ActivityLevels.lowActive), isNotNull);
    });

    test('missing or unknown inputs give no estimate', () {
      expect(eer('other', 45, 158, 65, ActivityLevels.lowActive), isNull);
      expect(eer('female', 45, 158, 65, 'Sometimes'), isNull);
      expect(eer('female', 45, 0, 65, ActivityLevels.lowActive), isNull);
    });
  });

  group('Activity levels', () {
    test('older saved values map to the nearest NASEM level', () {
      expect(ActivityLevels.normalise('Sedentary'), ActivityLevels.inactive);
      expect(ActivityLevels.normalise('Lightly active'), ActivityLevels.lowActive);
      expect(ActivityLevels.normalise('Moderately active'), ActivityLevels.active);
      expect(ActivityLevels.normalise('Very active'), ActivityLevels.veryActive);
      expect(ActivityLevels.normalise(' low ACTIVE '), ActivityLevels.lowActive);
      expect(ActivityLevels.normalise(null), isNull);
    });
  });

  group('Adults aged 19 and over (birthday)', () {
    test('W-T07 the day before the 19th birthday is still 18', () {
      final DateTime born = DateTime(2007, 11, 12);

      expect(AdultAge.yearsOn(born, DateTime(2026, 11, 11)), 18);
      expect(AdultAge.isAdult(born, DateTime(2026, 11, 11)), isFalse);
      expect(AdultAge.isAdult(born, DateTime(2026, 11, 12)), isTrue);
    });

    test('the picker allows dates up to the day someone turns 19 today', () {
      expect(AdultAge.latestBirthDate(DateTime(2026, 11, 11)), DateTime(2007, 11, 11));
    });

    test('on 29 February the latest date is 28 February', () {
      final DateTime today = DateTime(2028, 2, 29);
      final DateTime latest = AdultAge.latestBirthDate(today);

      expect(latest, DateTime(2009, 2, 28));
      expect(AdultAge.isAdult(latest, today), isTrue);
      expect(AdultAge.isAdult(DateTime(2009, 3, 1), today), isFalse);
    });
  });

  group('Daily figure from a doctor or dietitian', () {
    test('accepted from 800 to 5,000 kcal', () {
      expect(EnergyRequirement.providerTargetOk(799), isFalse);
      expect(EnergyRequirement.providerTargetOk(800), isTrue);
      expect(EnergyRequirement.providerTargetOk(5000), isTrue);
      expect(EnergyRequirement.providerTargetOk(5001), isFalse);
      expect(EnergyRequirement.providerTargetOk(null), isFalse);
    });

    test('a note below 1,200 kcal (women) or 1,500 kcal (men)', () {
      expect(EnergyRequirement.providerTargetIsBelowGuideline(1000, 'Female'), isTrue);
      expect(EnergyRequirement.providerTargetIsBelowGuideline(1200, 'Female'), isFalse);
      expect(EnergyRequirement.providerTargetIsBelowGuideline(1400, 'Male'), isTrue);
      expect(EnergyRequirement.providerTargetIsBelowGuideline(1500, 'Male'), isFalse);
    });
  });

  group('Energy for a weight goal (rule R-EN-02)', () {
    GoalEnergyResult apply(String? goal, double eerKcal,
            {int? chosen, String sex = 'female', double kg = 65, double cm = 158}) =>
        GoalEnergy.apply(
          maintenanceKcal: eerKcal,
          goal: goal,
          chosenKcal: chosen,
          sex: sex,
          weightKg: kg,
          heightCm: cm,
        );

    test('defaults: lose 500 less, gain 300 more, maintain unchanged', () {
      expect(apply('Lose weight', 2000).kcal, 1500);
      expect(apply('Gain weight', 2000).kcal, 2300);
      expect(apply('Maintain weight', 2000).kcal, 2000);
      expect(apply(null, 2000).requestedKcal, 0);
    });

    test('only the listed amounts are used; others fall back to the default', () {
      expect(apply('lose', 2000, chosen: 750).kcal, 1250);
      expect(apply('lose', 2000, chosen: 600).kcal, 1500);
      expect(apply('gain', 2000, chosen: 500).kcal, 2500);
      expect(apply('gain', 2000, chosen: 750).kcal, 2300);
    });

    test('floors: 1,200 kcal for women, 1,500 kcal for men', () {
      final GoalEnergyResult woman = apply('lose', 1550);

      expect(woman.kcal, 1200);
      expect(woman.floorApplied, isTrue);
      expect(woman.adjusted, isTrue);

      final GoalEnergyResult man = apply('lose', 1900, sex: 'male', kg: 70, cm: 175);

      expect(man.kcal, 1500);
      expect(man.floorApplied, isTrue);
    });

    test('maintenance already below the floor: no deficit', () {
      final GoalEnergyResult r = apply('lose', 1150);

      expect(r.kcal, 1150);
      expect(r.adjusted, isFalse);
      expect(r.floorApplied, isTrue);
      expect(r.floorKcal, 1200);
    });

    test('BMI under 18.5: no deficit for weight loss', () {
      // 45 kg, 160 cm -> BMI 17.6
      final GoalEnergyResult r = apply('lose', 1800, kg: 45, cm: 160);

      expect(r.kcal, 1800);
      expect(r.lowBmi, isTrue);
      expect(r.adjusted, isFalse);

      // Gain is still applied at a low BMI.
      expect(apply('gain', 1800, kg: 45, cm: 160).kcal, 2100);
    });
  });
}
