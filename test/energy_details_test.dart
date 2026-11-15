import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/profile_setup_data.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';
import 'package:nutripal/widgets/energy_details_fields.dart';

// Energy details for High LDL cholesterol without weight
// management (no weight goal). Saturated fat and trans fat
// are limited as a share of the day's energy, so the
// profile needs gender, weight, height and activity level.

void main() {
  group('EnergyDetails (E-T01-E-T05)', () {
    const EnergyDetails full = EnergyDetails(
      sex: 'Female',
      weightKg: 65,
      heightCm: 158,
      activity: 'Low active',
    );

    test('E-T01 complete only when body, activity and the optional box are valid', () {
      expect(full.complete, isTrue);
      expect(const EnergyDetails().complete, isFalse);

      expect(
        const EnergyDetails(sex: 'Female', weightKg: 65, heightCm: 158).complete,
        isFalse, // no activity level
      );

      expect(
        const EnergyDetails(
          sex: 'Female',
          weightKg: 65,
          heightCm: 158,
          activity: 'Active',
          providerText: '50', // outside 800-5,000 kcal
        ).complete,
        isFalse,
      );
    });

    test('E-T02 the optional calorie box may be empty or a valid figure', () {
      expect(full.providerKcal, isNull);

      const EnergyDetails withProvider = EnergyDetails(
        sex: 'Male',
        weightKg: 80,
        heightCm: 175,
        activity: 'Active',
        providerText: '1800',
      );

      expect(withProvider.complete, isTrue);
      expect(withProvider.providerKcal, 1800);
    });

    test('E-T03 applyTo writes kg and cm and never sets a weight goal', () {
      final ProfileSetupData d = ProfileSetupData(highCholesterol: true);

      full.applyTo(d);

      expect(d.genderForEnergyEstimate, 'Female');
      expect(d.currentWeight, 65);
      expect(d.height, 158);
      expect(d.activityLevel, 'Low active');
      expect(d.weightUnit, 'kg');
      expect(d.heightUnit, 'cm');
      expect(d.weightGoal, isNull);
      expect(d.weightManagement, isFalse);
    });

    test('E-T04 profileHasDetails: asked only when something is missing', () {
      final ProfileSetupData d = ProfileSetupData(highCholesterol: true);

      expect(EnergyDetails.profileHasDetails(d), isFalse);

      full.applyTo(d);

      expect(EnergyDetails.profileHasDetails(d), isTrue);

      d.activityLevel = null;

      expect(EnergyDetails.profileHasDetails(d), isFalse);
    });

    test('E-T05 clearFrom removes every energy detail', () {
      final ProfileSetupData d = ProfileSetupData(highCholesterol: true);

      full.applyTo(d);
      d.providerEnergyKcal = 1800;

      EnergyDetails.clearFrom(d);

      expect(d.genderForEnergyEstimate, isNull);
      expect(d.currentWeight, isNull);
      expect(d.height, isNull);
      expect(d.activityLevel, isNull);
      expect(d.providerEnergyKcal, isNull);
    });
  });

  group('LDL limits from the energy details (E-T06-E-T07)', () {
    test('E-T06 with details: limits follow the estimated energy', () {
      final ProfileSetupData d = ProfileSetupData(
        highCholesterol: true,
        dateOfBirth: DateTime(1982, 11, 9),
      );

      const EnergyDetails(
        sex: 'Female',
        weightKg: 65,
        heightCm: 158,
        activity: 'Low active',
      ).applyTo(d);

      final DailyTargets t = NutritionAnalysisService.targetsFor(
        NutritionProfile.fromSetupData(d, today: DateTime(2026, 11, 8)),
      );

      expect(t.energyIsPersonal, isTrue);
      expect(t.goal, isNull); // no weight goal, so maintenance
      expect(t.saturatedFatG, closeTo(t.energyKcal * 0.10 / 9, 1e-9));
      expect(t.transFatG, closeTo(t.energyKcal * 0.01 / 9, 1e-9));
    });

    test('E-T07 without details: the standard 2,000 kcal day', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(
        NutritionProfile.fromSetupData(ProfileSetupData(highCholesterol: true)),
      );

      expect(t.energyIsPersonal, isFalse);
      expect(t.energyKcal, 2000);
      expect(t.saturatedFatG, closeTo(22.22, 0.01));
      expect(t.transFatG, closeTo(2.22, 0.01));
    });
  });
}
