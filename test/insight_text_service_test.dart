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

  // 1.5 litres: 34.5 g of carbohydrate.
  final NutritionAnalysis oneLitre = NutritionAnalysisService.analyse(
    data: homesoy(),
    profile: sampleUser,
    portion: const Portion.amount(1500, 'ml'),
  );

  test('NutriPal explains, one cup: amounts, no level wording', () {
    final ExplainText t = InsightTextService.explain(
      oneCup,
      data: homesoy(),
      profile: sampleUser,
      portionText: 'your 236 ml',
    );

    expect(t.portion, 'In your 236 ml');
    expect(t.amounts, contains('5.4 g carbs'));
    expect(t.good, isNull);
    expect(t.watch, isEmpty);
    expect(t.tip, contains('smaller or larger portion'));
  });

  test('NutriPal explains, 1.5 litres: still no area is called high', () {
    final ExplainText t = InsightTextService.explain(
      oneLitre,
      data: homesoy(),
      profile: sampleUser,
      portionText: 'your 1500 ml',
    );

    expect(t.watch, isEmpty);
    expect(t.good, isNull);
  });

  test('overall text: review key nutrients, never a fit or a warning', () {
    for (final NutritionAnalysis a in <NutritionAnalysis>[oneCup, oneLitre]) {
      final OverallText o = InsightTextService.overall(a);

      expect(o.tag, 'Review key nutrients');
      expect(o.title, 'Look at the nutrient findings');
      expect(o.text, contains('diabetes'));
      expect(o.text, contains('hypertension'));
      expect(o.text, contains('without an overall result'));
      expect(o.tag, isNot('Watch out'));
      expect(o.tag, isNot('Fits your goals'));
    }
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

  test('plain diabetes card: amounts, exchanges, no level, no meal guide', () {
    final PlainAreaText t = InsightTextService.plainArea(oneCup.areas[0], oneCup);

    expect(t.headline, 'Carbohydrate and sugars in this portion');
    expect(t.marker, isNull);
    expect(t.facts.map((PlainFact f) => f.label), <String>['Carbs', 'Total sugars']);
    expect(t.facts.first.amount, '5.4 g');
    expect(t.facts.first.meaning, 'about 0.4 carb exchanges in this portion');
    expect(t.facts.last.meaning, 'in this portion');
    expect(t.tip, contains('following your own plan from your doctor or dietitian'));
    expect(t.tip, isNot(contains('Malaysian guide')));
    expect(t.goodNews, contains('3.5 g of fibre'));
    expect(t.note, contains('amount in your portion'));
  });

  test('plain diabetes card at 1 litre has the same neutral layout', () {
    final PlainAreaText t = InsightTextService.plainArea(oneLitre.areas[0], oneLitre);

    expect(t.headline, 'Carbohydrate and sugars in this portion');
    expect(t.marker, isNull);
    expect(t.tip, isNot(startsWith('Look for a product with less')));
  });

  test('blood pressure card: sodium mg, % of the 2,000 mg reference, salt traffic light', () {
    final PlainAreaText t = InsightTextService.plainArea(oneCup.areas[1], oneCup);

    expect(t.headline, 'Sodium in this portion');
    expect(t.marker, isNull);
    expect(t.facts.single.label, 'Sodium');
    expect(t.facts.single.amount, '40 mg');
    expect(t.facts.single.meaning,
        '2% of the 2,000 mg daily sodium reference');
    expect(t.note ?? '', isNot(contains('product level')));
  });

  test('weight card: energy share, no level', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(
        areas: <HealthArea>{HealthArea.weight},
        sex: 'female',
        ageYears: 45,
        weightKg: 65,
        heightCm: 158,
        activityLevel: 'Low active',
        weightGoal: 'maintain',
      ),
    );

    final PlainAreaText t = InsightTextService.plainArea(a.areas.single, a, weightGoal: 'maintain');

    expect(t.headline, 'Energy in this portion');
    expect(t.marker, isNull);
    expect(t.facts.single.meaning, contains('of your estimated daily energy need'));
  });

  test('D-T06 one diabetes card for everyone: no type words, never an insulin dose', () {
    final PlainAreaText t = InsightTextService.plainArea(oneCup.areas[0], oneCup);

    final String all = '${t.headline} ${t.tip} ${t.note} ${t.evidence?.why} ${t.evidence?.lookFor}';

    expect(all, isNot(contains('Type 1')));
    expect(all, isNot(contains('Type 2')));
    expect(all.toLowerCase(), isNot(contains('prediabetes')));
    expect(t.tip, contains('NutriPal never works out insulin or medicine doses'));
    expect(t.evidence?.source, 'ADA 2026 (DM-02, DM-04, DM-05)');
  });

  test('NT-T03 protein goal: bonus on the weight card', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(
        areas: <HealthArea>{HealthArea.weight},
        proteinGoalG: 50,
      ),
    );

    expect(
      InsightTextService.plainArea(a.areas.single, a).goodNews,
      contains('7.1 g of protein, a small part of your daily protein goal'),
    );
  });

  test('LDL-T03 LDL card: the same neutral key-nutrient layout', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(areas: <HealthArea>{HealthArea.cholesterol}),
    );

    final PlainAreaText t = InsightTextService.plainArea(a.areas.single, a);

    expect(t.headline, 'Saturated and trans fat in this portion');
    expect(t.marker, isNull);
    expect(t.facts.map((PlainFact f) => f.label), <String>['Saturated fat', 'Fat']);
    expect(t.facts.first.meaning, contains('of your daily limit'));
    expect(t.facts.first.meaning, isNot(contains('product level')));
    // Total fat is context only: its amount, no share.
    expect(t.facts.last.meaning, 'in this portion');
    expect(t.goodNews, contains('3.5 g of fibre'));
    expect(t.note ?? '', isNot(contains('product level')));
  });

  test('LDL-T05 overall: review key nutrients for LDL cholesterol, never a fit', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(areas: <HealthArea>{HealthArea.cholesterol}),
    );

    final OverallText o = InsightTextService.overall(a);

    expect(a.overall, isNull);
    expect(o.tag, 'Review key nutrients');
    expect(o.title, 'Look at the nutrient findings');
    expect(o.text, contains('LDL cholesterol'));
    expect(o.text, contains('without an overall result'));
  });

  test('LDL-T04 overall: no area level, points to the key-nutrient cards', () {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: homesoy(),
      profile: const NutritionProfile(
        areas: <HealthArea>{HealthArea.diabetes, HealthArea.cholesterol},
      ),
      portion: const Portion.amount(1500, 'ml'),
    );

    final OverallText o = InsightTextService.overall(a);

    expect(a.overall, isNull);
    expect(o.tag, 'Review key nutrients');
    expect(o.text, contains('without an overall result'));
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
    expect((context['analysis'] as Map<String, dynamic>)['overall'], startsWith('review key nutrients'));

    // Each nutrient carries its own target and bands, and
    // the areas their nutrients.
    final Map<String, dynamic> rating = context['rating'] as Map<String, dynamic>;
    final Map<String, dynamic> carbs = (rating['nutrients'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((Map<String, dynamic> n) => n['name'] == 'Carbohydrate');

    expect(carbs['target'], 45);
    expect(carbs['low_share_max'], 0.25);
    expect(carbs['moderate_share_max'], 0.5);
    expect(
      ((rating['areas'] as List<dynamic>).first as Map<String, dynamic>)['nutrients'],
      <String>['Carbohydrate', 'Total Sugars'],
    );
    // No diabetes type is asked or sent.
    expect((context['user'] as Map<String, dynamic>).containsKey('diabetes_type'), isFalse);
    expect((context['user'] as Map<String, dynamic>).containsKey('diabetes_rating'), isFalse);
    expect((context['user'] as Map<String, dynamic>)['key_nutrient_cards'], contains('Diabetes is one area'));
    // No carbohydrate meal budget is sent unless the user set their own.
    expect((context['targets'] as Map<String, dynamic>).containsKey('carbs_basis'), isFalse);
    expect((context['targets'] as Map<String, dynamic>).containsKey('carbs_per_meal_g'), isFalse);
  });

  test('every key-nutrient card has an evidence layer with a source', () {
    for (final HealthArea area in HealthArea.values) {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: NutritionProfile(areas: <HealthArea>{area}),
      );

      final PlainAreaText t = InsightTextService.plainArea(a.areas.single, a, weightGoal: 'lose');

      expect(t.evidence, isNotNull, reason: '$area');
      expect(t.evidence!.why, isNotEmpty);
      expect(t.evidence!.lookFor, startsWith('When comparing similar products'));
      expect(t.evidence!.source, matches(RegExp(r'\((?:[A-Z]{2}-\d{2}(?:, )?)+\)')), reason: '$area');
    }
  });
}
