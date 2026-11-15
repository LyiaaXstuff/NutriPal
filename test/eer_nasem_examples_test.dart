import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/services/energy_requirement.dart';

void main() {
  group('NASEM 2023 EER examples', () {
    test('case A: female, 22, low active', () {
      final EnergyEstimate estimate = EnergyRequirement.estimate(
        sex: 'female',
        ageYears: 22,
        heightCm: 165,
        weightKg: 63,
        activity: ActivityLevels.lowActive,
      )!;

      expect(estimate.kcal, closeTo(2275.37, 1));
      expect(estimate.lowKcal, closeTo(2034.37, 1));
      expect(estimate.highKcal, closeTo(2516.37, 1));
    });

    test('case B: male, 45, low active', () {
      final EnergyEstimate estimate = EnergyRequirement.estimate(
        sex: 'male',
        ageYears: 45,
        heightCm: 175,
        weightKg: 100,
        activity: ActivityLevels.lowActive,
      )!;

      expect(estimate.kcal, closeTo(3040.62, 1));
    });

    test('case 1: female, 30, low active', () {
      final EnergyEstimate estimate = EnergyRequirement.estimate(
        sex: 'female',
        ageYears: 30,
        heightCm: 160,
        weightKg: 60,
        activity: ActivityLevels.lowActive,
      )!;

      expect(estimate.kcal, closeTo(2149.87, 1));
    });

    test('case 2: male, 30, inactive', () {
      final EnergyEstimate estimate = EnergyRequirement.estimate(
        sex: 'male',
        ageYears: 30,
        heightCm: 175,
        weightKg: 70,
        activity: ActivityLevels.inactive,
      )!;

      expect(estimate.kcal, closeTo(2552.67, 1));
    });
  });
}
