import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/profile_setup_data.dart';
import 'package:nutripal/services/ask_nutripal_service.dart';
import 'package:nutripal/services/insight_text_service.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

import 'nutrition_analysis_service_test.dart' show homesoy, sampleUser;

void main() {
  final NutritionAnalysis oneCup = NutritionAnalysisService.analyse(
    data: homesoy(),
    profile: sampleUser,
  );

  final NutritionAnalysis oneLitre = NutritionAnalysisService.analyse(
    data: homesoy(),
    profile: sampleUser,
    portion: const Portion.amount(1000, 'ml'),
  );

  test('overall text follows the worst area', () {
    expect(InsightTextService.overall(oneCup).title, 'Good choice for you');

    final OverallText high = InsightTextService.overall(oneLitre);
    expect(high.tag, 'Watch out');
    expect(high.text, contains('diabetes'));
  });

  test('diabetes card shows carbs, exchanges and the fibre bonus', () {
    final AreaText t = InsightTextService.area(oneCup.areas[0], oneCup);

    expect(t.value, '5.4');
    expect(t.unit, 'g carbs');
    expect(t.share, '8% of 71.7 g meal budget');
    expect(t.why, contains('0.4 carb exchanges'));
    expect(t.why, contains('Bonus: 3.5 g fibre'));
  });

  test('blood pressure card shows the share of 2,000 mg', () {
    final AreaText t = InsightTextService.area(oneCup.areas[1], oneCup);

    expect(t.value, '40');
    expect(t.share, '2% of 2,000 mg daily limit');
  });

  test('tips compare per 100 ml with the green limits', () {
    final List<ProductTip> tips = InsightTextService.tips(oneCup);

    expect(tips.map((ProductTip t) => t.ok), <bool>[true, true]);
    expect(tips.first.text, contains('2.5 g sugar per 100 ml'));
    expect(tips.last.text, contains('120 mg'));
  });

  test('Ask NutriPal context has the analysis but no personal details', () {
    final ProfileSetupData profile = ProfileSetupData(
      nickname: 'Aud',
      fullName: 'Secret Name',
      email: 'someone@example.com',
      diabetes: true,
    );

    final Map<String, dynamic> context = AskNutriPalService.buildContext(
      productName: 'Homesoy',
      data: homesoy(),
      analysis: oneCup,
      profile: profile,
    );

    final String text = context.toString();

    expect(text, isNot(contains('Secret Name')));
    expect(text, isNot(contains('someone@example.com')));
    expect(text, isNot(contains('Aud')));

    final List<Map<String, dynamic>> per100 =
        (context['per_100'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(per100.first, <String, dynamic>{'name': 'Energy', 'amount': 39.0, 'unit': 'kcal'});
    expect((context['targets'] as Map<String, dynamic>)['sodium_mg'], 2000.0);
    expect((context['analysis'] as Map<String, dynamic>)['overall'], 'Low');
  });
}
