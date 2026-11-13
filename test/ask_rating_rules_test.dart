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

  test('R-T05 sodium carries its daily reference', () {
    expect(nutrient('Sodium')['target'], 2000);
    expect(nutrient('Sodium')['low_share_max'], AnalysisRules.lowShare);
  });

  test('R-T06 diabetes: carbohydrate and sugars are sent as display-only, never rated', () {
    final Map<String, dynamic> dm = (rules['areas'] as List<Map<String, dynamic>>)
        .firstWhere((Map<String, dynamic> a) => a['area'] == 'Diabetes');

    expect(dm['display_only'], <String>['Carbohydrate', 'Total Sugars']);
    expect(nutrient('Carbohydrate')['rated'], isFalse);
    expect(nutrient('Total Sugars')['rated'], isFalse);
  });

  test('R-T03 every area is sent as findings: its nutrients, no level', () {
    final List<Map<String, dynamic>> areas = rules['areas'] as List<Map<String, dynamic>>;

    expect(areas.map((Map<String, dynamic> a) => a['area']), <String>['Diabetes', 'Blood pressure']);
    expect(areas.first['nutrients'], <String>['Carbohydrate', 'Total Sugars']);
    expect(areas.first['combine'], 'findings');
    expect(areas.last['nutrients'], <String>['Sodium']);
    expect(areas.last['combine'], 'findings');
  });

  test('R-T04 no nutrient is rated by any area and the app gives no overall level', () {
    final List<Map<String, dynamic>> nutrients = rules['nutrients'] as List<Map<String, dynamic>>;

    expect(nutrients.every((Map<String, dynamic> n) => n['rated'] == false), isTrue);
    expect(analysis.overall, isNull);
  });
}
