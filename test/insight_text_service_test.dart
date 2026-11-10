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

  test('NutriPal explains, one cup: amounts, good news, it fits', () {
    final ExplainText t = InsightTextService.explain(
      oneCup,
      data: homesoy(),
      profile: sampleUser,
      portionText: 'your 236 ml',
    );

    expect(t.portion, 'In your 236 ml');
    expect(t.amounts, contains('5.4 g carbs'));
    expect(t.good, startsWith('Low in'));
    expect(t.watch, isEmpty);
    // Worked out by checking twice the portion.
    expect(t.tip.toLowerCase(), contains('twice this amount (472 ml)'));
  });

  test('NutriPal explains, one litre: what to watch and a half-portion tip', () {
    final ExplainText t = InsightTextService.explain(
      oneLitre,
      data: homesoy(),
      profile: sampleUser,
      portionText: 'your 1000 ml',
    );

    expect(t.watch, isNotEmpty);
    expect(t.watch.first, contains('for diabetes'));
    expect(t.tip, contains('half'));
  });

  test('overall text follows the worst area', () {
    expect(InsightTextService.overall(oneCup).title, 'Good choice for you');

    final OverallText high = InsightTextService.overall(oneLitre);
    expect(high.tag, 'Watch out');
    expect(high.text, contains('diabetes'));
  });

  test('overall text names the weight area by the user\'s goal', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(areas: <HealthArea>{HealthArea.weight}),
      portion: const Portion.amount(3000, 'ml'),
    );

    expect(InsightTextService.overall(a).text, contains('weight'));
    expect(
      InsightTextService.overall(a, weightGoal: 'lose').text,
      contains('your weight-loss goal'),
    );
    expect(
      InsightTextService.overall(a, weightGoal: 'gain').text,
      contains('your weight-gain goal'),
    );
  });

  test('plain fractions for shares', () {
    expect(InsightTextService.fraction(0.03), 'a tiny part');
    expect(InsightTextService.fraction(0.24), 'about a quarter');
    expect(InsightTextService.fraction(0.40), 'almost half');
    expect(InsightTextService.fraction(0.50), 'about half');
  });

  test('plain diabetes card for one cup: easy, with fibre good news', () {
    final PlainAreaText t = InsightTextService.plainArea(oneCup.areas[0], oneCup);

    expect(t.headline, 'Easy on your blood sugar');
    expect(t.facts.first.label, 'Carbs');
    expect(t.facts.first.amount, '5.4 g');
    expect(t.facts.first.meaning, 'a small part of what one meal should have (8%)');
    expect(t.tip, isNull);
    expect(t.goodNews, contains('3.5 g of fibre'));
    expect(t.marker, lessThan(1 / 3));
  });

  test('plain diabetes card for one litre: a lot, with a tip', () {
    final PlainAreaText t = InsightTextService.plainArea(oneLitre.areas[0], oneLitre);

    expect(t.headline, startsWith('A lot of'));
    expect(t.tip, startsWith('Look for a product with less'));
    expect(t.marker, greaterThan(2 / 3));
  });

  test('diabetes card shows carbs, exchanges and the fibre bonus', () {
    final AreaText t = InsightTextService.area(oneCup.areas[0], oneCup);

    expect(t.value, '5.4');
    expect(t.unit, 'g carbs');
    expect(t.share, '8% of 71.7 g meal budget');
    expect(t.why, contains('0.4 carb exchanges'));
    expect(t.why, contains('Good news: it has 3.5 g of fibre, about 14% of what you need each day.'));
    expect(t.why, contains('Fibre helps keep blood sugar steady.'));
  });

  test('blood pressure card shows the share of 2,000 mg', () {
    final AreaText t = InsightTextService.area(oneCup.areas[1], oneCup);

    expect(t.value, '40');
    expect(t.share, '2% of 2,000 mg daily limit');
  });

  test('tips show the exact saturated fat limit (0.75, not 0.8)', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(areas: <HealthArea>{HealthArea.cholesterol}),
    );

    expect(
      InsightTextService.tips(a).single.text,
      'Pick products with up to 0.75 g saturated fat per 100 ml. This one has 0.3 g.',
    );
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
