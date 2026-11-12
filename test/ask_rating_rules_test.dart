import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/services/ask_nutripal_service.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

import 'nutrition_analysis_service_test.dart' show homesoy, sampleUser;

// The rating rules sent to Ask NutriPal, so its
// recalculate_portion tool rates any amount like the app
// (functions/test/ask_nutripal.test.js uses the same
// Homesoy numbers and expects the same levels).

void main() {
  final NutritionAnalysis analysis = NutritionAnalysisService.analyse(
    data: homesoy(),
    profile: sampleUser,
    portion: const Portion.amount(1000, 'ml'),
  );

  final Map<String, dynamic> rules = AskNutriPalService.ratingRules(analysis);

  Map<String, dynamic> nutrient(String name) => (rules['nutrients'] as List<Map<String, dynamic>>)
      .firstWhere((Map<String, dynamic> n) => n['name'] == name);

  test('R-T01 rule numbers come from AnalysisRules', () {
    expect(rules['low_share_max'], AnalysisRules.lowShare);
    expect(rules['moderate_share_max'], AnalysisRules.highShare);
    expect(rules['combine'], 'worse_of_both');
  });

  test('R-T02 per-100 amounts and traffic lights in rule units', () {
    expect(nutrient('Carbohydrate')['per100'], 2.3);
    expect(nutrient('Sodium')['per100'], 17);
    expect(nutrient('Sodium')['unit'], 'mg');
    expect(nutrient('Total Fat')['product_level_per_100'], 'Moderate');
    expect(nutrient('Dietary Fibre')['rated'], isFalse);
  });

  test('R-T03 areas list their nutrients and key nutrient', () {
    final List<Map<String, dynamic>> areas = rules['areas'] as List<Map<String, dynamic>>;

    expect(areas.map((Map<String, dynamic> a) => a['area']), <String>['Diabetes', 'Blood pressure']);
    expect(areas.first['nutrients'], <String>['Carbohydrate', 'Total Sugars']);
    expect(areas.first['key_any_of'], <String>['Carbohydrate']);
  });

  test('R-T04 the app itself rates 1 L as Moderate (server must match)', () {
    expect(analysis.overall, NutrientLevel.moderate);
  });
}
