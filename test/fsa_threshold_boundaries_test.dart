import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

void main() {
  group('FSA threshold boundaries', () {
    test('food fat uses inclusive Low and Medium upper limits', () {
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 3.0, ProductForm.food),
        NutrientLevel.low,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 3.1, ProductForm.food),
        NutrientLevel.moderate,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 17.5, ProductForm.food),
        NutrientLevel.moderate,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 17.6, ProductForm.food),
        NutrientLevel.high,
      );
    });

    test('drink sugars uses inclusive Low and Medium upper limits', () {
      expect(
        NutritionAnalysisService.productLevel('Total Sugars', 2.5, ProductForm.drink),
        NutrientLevel.low,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Sugars', 11.25, ProductForm.drink),
        NutrientLevel.moderate,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Sugars', 11.3, ProductForm.drink),
        NutrientLevel.high,
      );
    });

    test('food portion is High only above its per-portion threshold', () {
      (TrafficCategory, TrafficBasis) category(double per100) =>
          NutritionAnalysisService.portionCategory(
            'Total Fat',
            per100,
            ProductForm.food,
            200,
          )!;

      expect(category(10.5).$1, TrafficCategory.medium);
      expect(category(10.55).$1, TrafficCategory.high);
    });
  });
}
