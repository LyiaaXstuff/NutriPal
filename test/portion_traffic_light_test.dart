import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

import 'nutrition_analysis_service_test.dart' show homesoy, sampleUser;

// Nutrient categories in the intended portion (UK traffic-
// light criteria with the high-per-portion rule, Chapter 3,
// Equation 3.1 and Tables 3.1 / 3.2).

(TrafficCategory, TrafficBasis) cat(
  String nutrient,
  double per100,
  ProductForm form,
  double? portion,
) =>
    NutritionAnalysisService.portionCategory(nutrient, per100, form, portion)!;

void main() {
  group('Portion categories', () {
    test('TL-T01 worked example: 5 g sugars per 100 ml, 300 ml -> 15 g, high', () {
      final (TrafficCategory c, TrafficBasis b) = cat('Total Sugars', 5, ProductForm.drink, 300);

      expect(NutritionAnalysisService.portionAmountOf(5, 300), 15);
      expect(c, TrafficCategory.high);
      expect(b, TrafficBasis.portionThreshold);
    });

    test('TL-T02 the same drink at 150 ml stays medium (rule is for over 150 ml)', () {
      final (TrafficCategory c, TrafficBasis b) = cat('Total Sugars', 5, ProductForm.drink, 150);

      expect(c, TrafficCategory.medium);
      expect(b, TrafficBasis.per100);
    });

    test('TL-T03 food over 100 g: high only above the per-portion threshold', () {
      // 4 g saturated fat per 100 g is medium per 100 g.
      expect(cat('Saturated Fat', 4, ProductForm.food, 120).$1, TrafficCategory.medium); // 4.8 g
      expect(cat('Saturated Fat', 4, ProductForm.food, 200).$1, TrafficCategory.high); // 8 g > 6 g
      // Exactly at the threshold is not above it.
      expect(cat('Saturated Fat', 4, ProductForm.food, 150).$1, TrafficCategory.medium); // 6 g
    });

    test('TL-T04 a food portion of exactly 100 g uses the per 100 g criteria', () {
      expect(NutritionAnalysisService.portionRuleApplies(ProductForm.food, 100), isFalse);
      expect(NutritionAnalysisService.portionRuleApplies(ProductForm.food, 101), isTrue);
      expect(NutritionAnalysisService.portionRuleApplies(ProductForm.drink, 151), isTrue);
    });

    test('TL-T05 a small portion never lowers a high per 100 category', () {
      final (TrafficCategory c, TrafficBasis b) = cat('Total Sugars', 30, ProductForm.food, 20);

      expect(c, TrafficCategory.high);
      expect(b, TrafficBasis.per100);
    });

    test('TL-T06 per 100 boundaries match Table 3.1 (food) and 3.2 (drinks)', () {
      expect(cat('Total Fat', 3.0, ProductForm.food, null).$1, TrafficCategory.low);
      expect(cat('Total Fat', 3.1, ProductForm.food, null).$1, TrafficCategory.medium);
      expect(cat('Total Fat', 17.6, ProductForm.food, null).$1, TrafficCategory.high);
      expect(cat('Salt', 0.75, ProductForm.drink, null).$1, TrafficCategory.medium);
      expect(cat('Salt', 0.76, ProductForm.drink, null).$1, TrafficCategory.high);
    });

    test('TL-T07 nutrients outside the scheme get no category', () {
      expect(
        NutritionAnalysisService.portionCategory('Protein', 10, ProductForm.food, 100),
        isNull,
      );
    });
  });

  group('Analysis', () {
    test('TL-T08 Homesoy, 1 serving (236 ml): four nutrients, portion rule on', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
      );

      final PortionTrafficLights t = a.trafficLights;

      expect(t.unit, 'ml');
      expect(t.portionSize, 236);
      expect(t.portionRuleApplies, isTrue);
      expect(t.results.map((TrafficLightResult r) => r.name).toList(),
          <String>['Fat', 'Saturated fat', 'Total sugars', 'Salt']);

      final TrafficLightResult sugars = t.results[2];

      expect(sugars.portionAmount, closeTo(0.7 * 236 / 100, 1e-9));
      expect(sugars.category, TrafficCategory.low);

      // Salt from 17 mg sodium per 100 ml = 0.0425 g.
      final TrafficLightResult salt = t.results[3];

      expect(salt.per100, closeTo(0.0425, 1e-9));
      expect(salt.saltFromSodium, isTrue);
      expect(salt.category, TrafficCategory.low);
    });

    test('TL-T09 a bigger portion is recalculated (4 servings = 944 ml)', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(),
        portion: const Portion.servings(4),
      );

      // 1.6 g fat per 100 ml x 944 ml / 100 = 15.1 g > 10.5 g.
      final TrafficLightResult fat = a.trafficLights.results.first;

      expect(fat.portionAmount, closeTo(15.104, 1e-9));
      expect(fat.category, TrafficCategory.high);
      expect(fat.basis, TrafficBasis.portionThreshold);
    });
  });
}
