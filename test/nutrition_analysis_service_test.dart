import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/models/profile_setup_data.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

// Homesoy Soya Bean Drink (worked example in the rules
// document): per serving 236 ml and per 100 ml.
NutritionLabelData homesoy() {
  NutritionValue v(double amount, String unit) =>
      NutritionValue(amount: amount, unit: unit, rawText: '$amount$unit');

  NutrientRow row(int order, String name, NutritionValue serving, NutritionValue per100) =>
      NutrientRow(
        name: name,
        order: order,
        valuesByColumn: <List<NutritionValue>>[
          <NutritionValue>[serving],
          <NutritionValue>[per100],
        ],
      );

  return NutritionLabelData(
    rawText: '',
    servingSizeAmount: 236,
    servingSizeUnit: 'ml',
    servingsPerPackage: 4,
    columns: const <NutritionColumn>[
      NutritionColumn(
        id: 'per_serving',
        label: 'Per serving',
        basis: NutritionColumnBasis.perServing,
        xCenter: 0,
      ),
      NutritionColumn(
        id: 'per_100ml',
        label: 'Per 100 ml',
        basis: NutritionColumnBasis.per100ml,
        xCenter: 1,
      ),
    ],
    nutrients: <NutrientRow>[
      row(0, 'Energy', v(92, 'kcal'), v(39, 'kcal')),
      row(1, 'Protein', v(7.1, 'g'), v(3.0, 'g')),
      row(2, 'Total Fat', v(3.8, 'g'), v(1.6, 'g')),
      row(3, 'Saturated Fat', v(0.7, 'g'), v(0.3, 'g')),
      row(4, 'Carbohydrate', v(5.4, 'g'), v(2.3, 'g')),
      row(5, 'Total Sugars', v(1.7, 'g'), v(0.7, 'g')),
      row(6, 'Dietary Fibre', v(3.5, 'g'), v(1.5, 'g')),
      row(7, 'Sodium', v(40, 'mg'), v(17, 'mg')),
      row(8, 'Calcium', v(283, 'mg'), v(120, 'mg')),
    ],
  );
}

// Female, 45, 65 kg, 158 cm, light activity, maintaining
// weight, diabetes + blood pressure (rules document).
const NutritionProfile sampleUser = NutritionProfile(
  sex: 'female',
  ageYears: 45,
  weightKg: 65,
  heightCm: 158,
  activityLevel: 'Lightly active',
  weightGoal: 'maintain',
  areas: <HealthArea>{HealthArea.diabetes, HealthArea.bloodPressure},
);

// Crisps: per 100 g only, salty (800 mg sodium = 2 g salt).
NutritionLabelData crisps() => NutritionLabelData(
      rawText: '',
      columns: const <NutritionColumn>[
        NutritionColumn(
          id: 'per_100g',
          label: 'Per 100 g',
          basis: NutritionColumnBasis.per100g,
          xCenter: 0,
        ),
      ],
      nutrients: const <NutrientRow>[
        NutrientRow(name: 'Energy', order: 0, valuesByColumn: <List<NutritionValue>>[
          <NutritionValue>[NutritionValue(amount: 520, unit: 'kcal', rawText: '520')],
        ]),
        NutrientRow(name: 'Sodium', order: 1, valuesByColumn: <List<NutritionValue>>[
          <NutritionValue>[NutritionValue(amount: 800, unit: 'mg', rawText: '800')],
        ]),
      ],
    );

void main() {
  group('Layer 2: daily targets', () {
    test('Mifflin-St Jeor energy for the sample user', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(sampleUser);

      // BMR = 650 + 987.5 - 225 - 161 = 1251.5; x 1.375.
      expect(t.energyKcal, closeTo(1720.8, 0.1));
      expect(t.energyIsPersonal, isTrue);
      expect(t.sodiumMg, 2000);
      expect(t.freeSugarsG, closeTo(43.0, 0.1));
      expect(t.carbsPerMealG, closeTo(71.7, 0.1));
      expect(t.saturatedFatG, closeTo(19.1, 0.1));
      expect(t.fibreG, 25);
    });

    test('weight loss subtracts 500 kcal but never goes below BMR', () {
      const NutritionProfile p = NutritionProfile(
        sex: 'male',
        ageYears: 30,
        weightKg: 80,
        heightCm: 175,
        activityLevel: 'Sedentary',
        weightGoal: 'lose',
      );

      // BMR 1748.75; 1748.75 x 1.2 - 500 = 1598.5 < BMR.
      expect(NutritionAnalysisService.targetsFor(p).energyKcal,
          closeTo(1748.75, 0.01));
    });

    test('missing profile data uses the 2,000 kcal reference', () {
      final DailyTargets t =
          NutritionAnalysisService.targetsFor(const NutritionProfile());

      expect(t.energyKcal, 2000);
      expect(t.energyIsPersonal, isFalse);
      expect(t.freeSugarsG, 50);
    });

    test('a limit from the doctor replaces the default', () {
      const NutritionProfile p = NutritionProfile(providerSodiumMg: 1500);

      final DailyTargets t = NutritionAnalysisService.targetsFor(p);

      expect(t.sodiumMg, 1500);
      expect(t.setByProvider, contains('Sodium'));
    });

    test('profile form data is converted (age, units, areas)', () {
      final ProfileSetupData data = ProfileSetupData(
        dateOfBirth: DateTime(1981, 11, 9),
        diabetes: true,
        weightGoal: 'Lose weight',
        genderForEnergyEstimate: 'Female',
        currentWeight: 65,
        height: 158,
        activityLevel: 'Lightly active',
      );

      final NutritionProfile p = NutritionProfile.fromSetupData(
        data,
        today: DateTime(2026, 11, 8),
      );

      expect(p.ageYears, 44); // birthday is tomorrow
      expect(p.sex, 'female');
      expect(p.weightGoal, 'lose');
      expect(p.areas, <HealthArea>{HealthArea.diabetes});
    });
  });

  group('Layer 1: FSA colours', () {
    test('drink thresholds per 100 ml', () {
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 1.6, ProductForm.drink),
        NutrientLevel.moderate,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Sugars', 0.7, ProductForm.drink),
        NutrientLevel.low,
      );
    });

    test('food thresholds per 100 g, edges included in the lower band', () {
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 3.0, ProductForm.food),
        NutrientLevel.low,
      );
      expect(
        NutritionAnalysisService.productLevel('Total Fat', 17.5, ProductForm.food),
        NutrientLevel.moderate,
      );
      expect(
        NutritionAnalysisService.productLevel('Salt', 1.51, ProductForm.food),
        NutrientLevel.high,
      );
      expect(
        NutritionAnalysisService.productLevel('Protein', 30, ProductForm.food),
        isNull,
      );
    });
  });

  group('Layer 3: share bands', () {
    test('10 % and 30 % edges', () {
      expect(NutritionAnalysisService.shareLevel(0.10), NutrientLevel.low);
      expect(NutritionAnalysisService.shareLevel(0.11), NutrientLevel.moderate);
      expect(NutritionAnalysisService.shareLevel(0.30), NutrientLevel.moderate);
      expect(NutritionAnalysisService.shareLevel(0.31), NutrientLevel.high);
    });
  });

  group('Worked example: Homesoy', () {
    test('one 236 ml serving is Low for diabetes and blood pressure', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
      );

      expect(a.form, ProductForm.drink);
      expect(a.portionAmount, 236);

      // One serving uses the per serving column as printed.
      final NutrientAssessment carbs = a.nutrients['Carbohydrate']!;
      expect(carbs.amount, closeTo(5.4, 0.001));
      expect(carbs.share, closeTo(0.0753, 0.0005));
      expect(carbs.level, NutrientLevel.low);

      final NutrientAssessment sodium = a.nutrients['Sodium']!;
      expect(sodium.amount, closeTo(40, 0.001));
      expect(sodium.share, closeTo(0.020, 0.001));
      expect(sodium.productLevel, NutrientLevel.low);

      expect(a.nutrients['Total Fat']!.productLevel, NutrientLevel.moderate);
      expect(a.nutrients['Dietary Fibre']!.share, closeTo(0.14, 0.001));
      expect(a.nutrients['Dietary Fibre']!.level, isNull);

      expect(a.areas.map((AreaAssessment x) => x.area),
          <HealthArea>[HealthArea.diabetes, HealthArea.bloodPressure]);
      expect(a.areas[0].level, NutrientLevel.low);
      expect(a.areas[0].benefit?.name, 'Dietary Fibre');
      expect(a.areas[1].level, NutrientLevel.low);
      expect(a.overall, NutrientLevel.low);
    });

    test('one litre moves diabetes to High', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
        portion: const Portion.amount(1000, 'ml'),
      );

      expect(a.nutrients['Carbohydrate']!.amount, closeTo(23, 0.01));
      expect(a.nutrients['Carbohydrate']!.share, closeTo(0.321, 0.001));
      expect(a.areas[0].level, NutrientLevel.high);
      expect(a.areas[0].decidedBy, 'Carbohydrate');
    });

    test('servings and amounts give the same numbers', () {
      final NutritionAnalysis twoServings = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
        portion: const Portion.servings(2),
      );

      expect(twoServings.portionAmount, 472);
      expect(twoServings.nutrients['Energy']!.amount, closeTo(184, 0.001));
    });

    test('a label rounded per 100 ml: 1 can shows the printed 6 mg', () {
      // Coke 320 ml: 6 mg sodium per can, 2 mg per 100 ml.
      final NutritionLabelData coke = NutritionLabelData(
        rawText: '',
        servingSizeAmount: 320,
        servingSizeUnit: 'ml',
        servingsPerPackage: 1,
        columns: homesoy().columns,
        nutrients: const <NutrientRow>[
          NutrientRow(name: 'Sodium', order: 0, valuesByColumn: <List<NutritionValue>>[
            <NutritionValue>[NutritionValue(amount: 6, unit: 'mg', rawText: '6')],
            <NutritionValue>[NutritionValue(amount: 2, unit: 'mg', rawText: '2')],
          ]),
        ],
      );

      final NutritionAnalysis oneCan = NutritionAnalysisService.analyse(
        data: coke,
        profile: sampleUser,
      );
      final NutritionAnalysis hundred = NutritionAnalysisService.analyse(
        data: coke,
        profile: sampleUser,
        portion: const Portion.amount(100, 'ml'),
      );

      expect(oneCan.nutrients['Sodium']!.amount, 6);
      expect(oneCan.facts.single.portion, '6 mg');
      expect(hundred.nutrients['Sodium']!.amount, 2);
      expect(hundred.facts.single.portion, '2 mg');
    });

    test('portion options include whole pack', () {
      final List<PortionOption> options =
          NutritionAnalysisService.portionOptions(homesoy());

      expect(options.map((PortionOption o) => o.label), <String>[
        '½ serving',
        '1 serving',
        '2 servings',
        'Whole pack',
        '100 ml',
      ]);
      expect(options[3].sub, '944 ml');
    });

    test('nutrition facts list every row for the portion', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
      );

      expect(a.facts.length, 9);
      expect(a.facts.first.portion, '92 kcal');
      expect(a.facts.first.per100, '39 kcal');
      expect(a.facts[8].portion, '283 mg');
      expect(a.facts[3].isSubRow, isTrue);
    });
  });

  group('Combining Layer 1 and Layer 3', () {
    const NutritionProfile bp = NutritionProfile(
      areas: <HealthArea>{HealthArea.bloodPressure},
    );

    test('worse of both: a small portion of salty crisps stays High', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: crisps(),
        profile: bp,
        portion: const Portion.amount(20, 'g'),
        rule: CombineRule.worseOfBoth,
      );

      expect(a.nutrients['Sodium']!.share, closeTo(0.08, 0.001));
      expect(a.nutrients['Sodium']!.productLevel, NutrientLevel.high);
      expect(a.areas.single.level, NutrientLevel.high);
    });

    test('portion decides: the same 20 g is Low', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: crisps(),
        profile: bp,
        portion: const Portion.amount(20, 'g'),
        rule: CombineRule.portionDecides,
      );

      expect(a.areas.single.level, NutrientLevel.low);
    });

    test('missing key nutrient: not enough information', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: crisps(),
        profile: const NutritionProfile(
          areas: <HealthArea>{HealthArea.diabetes},
        ),
      );

      expect(a.areas.single.hasEnoughInformation, isFalse);
      expect(a.areas.single.missing, contains('Carbohydrate'));
      expect(a.overall, isNull);
    });

    test('general nutrition users see all four areas', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(),
      );

      expect(a.areas.length, 4);
    });
  });

  group('Display', () {
    test('formatAmount', () {
      expect(NutritionAnalysisService.formatAmount(92.04, 'kcal'), '92');
      expect(NutritionAnalysisService.formatAmount(40.12, 'mg'), '40');
      expect(NutritionAnalysisService.formatAmount(5.428, 'g'), '5.4');
      expect(NutritionAnalysisService.formatAmount(14.24, 'g'), '14.2');
      expect(NutritionAnalysisService.formatAmount(3.0, 'g'), '3');
      expect(NutritionAnalysisService.formatAmount(0.708, 'g'), '0.7');
      expect(NutritionAnalysisService.formatAmount(0.042, 'g'), '0.04');
      expect(NutritionAnalysisService.formatAmount(236, 'ml'), '236');
    });

    test('formatShare', () {
      expect(NutritionAnalysisService.formatShare(0.0757), '8%');
      expect(NutritionAnalysisService.formatShare(0.004), '<1%');
    });
  });
}
