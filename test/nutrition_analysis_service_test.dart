import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_analysis.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/models/profile_setup_data.dart';
import 'package:nutripal/services/nutrition_analysis_service.dart';

// Homesoy Soya Bean Drink (worked example in the rules
// document): per serving 236 ml and per 100 ml.
NutritionLabelData homesoy() {
  // rawText is the cell as printed on the pack.
  NutritionValue v(double amount, String unit, [String? printed]) => NutritionValue(
        amount: amount,
        unit: unit,
        rawText: printed ??
            (amount == amount.roundToDouble() ? '${amount.toInt()} $unit' : '$amount $unit'),
      );

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
      row(1, 'Protein', v(7.1, 'g'), v(3.0, 'g', '3.0 g')),
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

// Female, 45, 65 kg, 158 cm, low active, maintaining
// weight, diabetes + blood pressure (rules document).
const NutritionProfile sampleUser = NutritionProfile(
  sex: 'female',
  ageYears: 45,
  weightKg: 65,
  heightCm: 158,
  activityLevel: 'Low active',
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
    test('NASEM 2023 EER for the sample user', () {
      final DailyTargets t = NutritionAnalysisService.targetsFor(sampleUser);

      // Women, low active:
      // 575.77 - 7.01 x 45 + 6.60 x 158 + 12.14 x 65 = 2092.22
      expect(t.energyKcal, closeTo(2092.2, 0.1));
      expect(t.energyIsPersonal, isTrue);
      // EER plus or minus 241 kcal (women).
      expect(t.energyLowKcal, closeTo(1851.2, 0.1));
      expect(t.energyHighKcal, closeTo(2333.2, 0.1));
      expect(t.sodiumMg, 2000);
      expect(t.freeSugarsG, closeTo(52.3, 0.1));
      expect(t.carbsPerMealG, closeTo(87.2, 0.1));
      expect(t.saturatedFatG, closeTo(23.2, 0.1));
      expect(t.fibreG, 25);
      expect(t.setByProvider, isEmpty);
    });

    test('W-T17 weight goal changes the energy target only', () {
      NutritionProfile withGoal(String goal, [int? change]) => NutritionProfile(
            sex: 'male',
            ageYears: 30,
            weightKg: 75,
            heightCm: 175,
            activityLevel: 'Active',
            weightGoal: goal,
            energyChangeKcal: change,
          );

      DailyTargets t(String goal, [int? change]) =>
          NutritionAnalysisService.targetsFor(withGoal(goal, change));

      // Men, active: 1004.82 - 324.9 + 1141 + 1193.25
      for (final String goal in <String>['lose', 'maintain', 'gain']) {
        // Every other limit stays on maintenance energy.
        expect(t(goal).energyKcal, closeTo(3014.2, 0.1));
        expect(t(goal).freeSugarsG, closeTo(75.4, 0.1));
      }

      expect(t('maintain').goalEnergyKcal, closeTo(3014.2, 0.1));
      expect(t('maintain').goal, isNull);
      expect(t('lose').goalEnergyKcal, closeTo(2514.2, 0.1));
      expect(t('lose', 750).goalEnergyKcal, closeTo(2264.2, 0.1));
      expect(t('gain').goalEnergyKcal, closeTo(3314.2, 0.1));
      expect(t('gain', 500).goalEnergyKcal, closeTo(3514.2, 0.1));
    });

    test('W-T18 the energy share uses the goal energy', () {
      const NutritionProfile loser = NutritionProfile(
        sex: 'female',
        ageYears: 45,
        weightKg: 65,
        heightCm: 158,
        activityLevel: 'Low active',
        weightGoal: 'lose',
        areas: <HealthArea>{HealthArea.weight},
      );

      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: loser,
        portion: const Portion.amount(1000, 'ml'),
      );

      // 390 kcal of 2092.2 - 500 = 1592.2 kcal.
      expect(a.nutrients['Energy']!.share, closeTo(390 / 1592.2, 0.001));
      // Sugars still use the maintenance limit (52.3 g).
      expect(a.nutrients['Total Sugars']!.share, closeTo(7 / 52.3, 0.001));
    });

    test('a daily figure from the doctor or dietitian replaces the EER', () {
      const NutritionProfile p = NutritionProfile(
        sex: 'female',
        ageYears: 45,
        weightKg: 65,
        heightCm: 158,
        activityLevel: 'Low active',
        weightGoal: 'lose',
        providerEnergyKcal: 1500,
      );

      final DailyTargets t = NutritionAnalysisService.targetsFor(p);

      expect(t.energyKcal, 1500);
      // Used as given: no goal change on top.
      expect(t.goal, isNull);
      expect(t.goalEnergyKcal, 1500);
      expect(t.energyIsPersonal, isTrue);
      expect(t.setByProvider, contains('Energy'));
      expect(t.energyLowKcal, isNull);
      expect(t.freeSugarsG, closeTo(37.5, 0.01));
    });

    test('a provider figure below 800 kcal is not used', () {
      const NutritionProfile p = NutritionProfile(
        sex: 'female',
        ageYears: 45,
        weightKg: 65,
        heightCm: 158,
        activityLevel: 'Low active',
        providerEnergyKcal: 700,
      );

      final DailyTargets t = NutritionAnalysisService.targetsFor(p);

      expect(t.energyKcal, closeTo(2092.2, 0.1));
      expect(t.setByProvider, isNot(contains('Energy')));
    });

    test('under 19 gets the 2,000 kcal reference, not an estimate', () {
      const NutritionProfile p = NutritionProfile(
        sex: 'female',
        ageYears: 18,
        weightKg: 55,
        heightCm: 160,
        activityLevel: 'Active',
      );

      final DailyTargets t = NutritionAnalysisService.targetsFor(p);

      expect(t.energyKcal, 2000);
      expect(t.energyIsPersonal, isFalse);
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
      // An older saved value maps to the NASEM level.
      expect(p.activityLevel, 'Low active');
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
      // 5.4 g of an 87.2 g meal budget.
      expect(carbs.share, closeTo(0.0619, 0.0005));
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

    test('one litre is Moderate for diabetes, 1.5 litres High', () {
      final NutritionAnalysis litre = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
        portion: const Portion.amount(1000, 'ml'),
      );

      expect(litre.nutrients['Carbohydrate']!.amount, closeTo(23, 0.01));
      expect(litre.nutrients['Carbohydrate']!.share, closeTo(0.264, 0.001));
      expect(litre.areas[0].level, NutrientLevel.moderate);
      expect(litre.areas[0].decidedBy, 'Carbohydrate');

      final NutritionAnalysis more = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
        portion: const Portion.amount(1500, 'ml'),
      );

      expect(more.nutrients['Carbohydrate']!.share, closeTo(0.396, 0.001));
      expect(more.areas[0].level, NutrientLevel.high);
      expect(more.areas[0].decidedBy, 'Carbohydrate');
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
      // The pack prints "3.0 g" for protein per 100 ml.
      expect(a.facts[1].per100, '3.0 g');
    });

    // N-T01: fibre is its own row, and a part is indented
    // only under its own nutrient.
    test('N-T01 indents only real sub-rows under their parent', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
      );

      final Map<String, bool> indented = <String, bool>{
        for (final FactRow r in a.facts) r.name: r.isSubRow,
      };

      expect(indented['Saturated Fat'], isTrue);
      expect(indented['Total Sugars'], isTrue);
      expect(indented['Dietary Fibre'], isFalse);
      expect(indented['Total Fat'], isFalse);
      expect(indented['Sodium'], isFalse);
    });

    // N-T03: one serving and the per 100 column show the
    // pack's own digits; calculated portions are rounded.
    test('N-T03 printed values keep the label digits', () {
      NutritionValue v(double amount, String raw) =>
          NutritionValue(amount: amount, unit: 'µg', rawText: raw);

      expect(NutritionAnalysisService.printedAmount(v(2.66, '2.66µg')), '2.66');
      expect(NutritionAnalysisService.printedAmount(v(3.0, '3.0 g')), '3.0');
      expect(NutritionAnalysisService.printedAmount(v(0.1, '<0.1 g')), '<0.1');
      expect(NutritionAnalysisService.printedAmount(v(1.5, '1,5 g')), '1.5');
      // Text that is not the same number (edited, calculated).
      expect(NutritionAnalysisService.printedAmount(v(2.66, 'calculated')), '2.66');
      expect(NutritionAnalysisService.printedAmount(v(0.3, '0.30000000000000004')), '0.3');
    });

    test('N-T04 facts table: 1 serving as printed, 2 servings rounded', () {
      final NutritionLabelData d = homesoy();
      NutritionValue v(double amount, String raw) =>
          NutritionValue(amount: amount, unit: 'µg', rawText: raw);

      final NutritionLabelData withVitD = NutritionLabelData(
        rawText: '',
        servingSizeAmount: d.servingSizeAmount,
        servingSizeUnit: d.servingSizeUnit,
        servingsPerPackage: d.servingsPerPackage,
        columns: d.columns,
        nutrients: <NutrientRow>[
          ...d.nutrients,
          NutrientRow(
            name: 'Vitamin D',
            order: 9,
            valuesByColumn: <List<NutritionValue>>[
              <NutritionValue>[v(2.66, '2.66µg')],
              <NutritionValue>[v(1.13, '1.13µg')],
            ],
          ),
        ],
      );

      FactRow vitD(Portion p) => NutritionAnalysisService.analyse(
            data: withVitD,
            profile: sampleUser,
            portion: p,
          ).facts.last;

      expect(vitD(const Portion.servings(1)).portion, '2.66 µg');
      expect(vitD(const Portion.servings(1)).per100, '1.13 µg');
      expect(vitD(const Portion.servings(2)).portion, '5.3 µg');
    });

    test('N-T02 a sub-row away from its parent is not indented', () {
      final NutritionLabelData d = homesoy();
      final NutritionLabelData moved = NutritionLabelData(
        rawText: '',
        servingSizeAmount: d.servingSizeAmount,
        servingSizeUnit: d.servingSizeUnit,
        servingsPerPackage: d.servingsPerPackage,
        columns: d.columns,
        // Total Sugars after Total Fat, away from Carbohydrate.
        nutrients: <NutrientRow>[d.nutrients[2], d.nutrients[5], d.nutrients[4]],
      );

      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: moved,
        profile: sampleUser,
      );

      expect(a.facts.map((FactRow r) => r.isSubRow).toList(), <bool>[false, false, false]);
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

  group('Household measure (only when the label prints one)', () {
    test('"236 ml (1 cup)": choices are named in cups', () {
      final NutritionLabelData data =
          homesoy().copyWith(servingUnitAmount: 1, servingUnitName: 'cup');

      final List<PortionOption> options = NutritionAnalysisService.portionOptions(data);

      expect(options.map((PortionOption o) => o.label), <String>[
        '½ cup',
        '1 cup',
        '2 cups',
        'Whole pack',
      ]);
      expect(options[0].sub, '118 ml');
      expect(options[1].portion, const Portion.servings(1));
    });

    test('"30 g (3 biscuits)": one biscuit is 10 g, counts read naturally', () {
      final NutritionLabelData data = homesoy().copyWith(
        servingSizeAmount: 30,
        servingSizeUnit: 'g',
        servingsPerPackage: 10,
        servingUnitAmount: 3,
        servingUnitName: 'biscuits',
      );

      final HouseholdMeasure m = NutritionAnalysisService.householdMeasure(data)!;

      expect(m.name, 'biscuit');
      expect(m.amountEach, 10);
      expect(m.label(1), '1 biscuit');
      expect(m.label(4), '4 biscuits');
      expect(m.servingsFor(4), closeTo(4 / 3, 1e-9));

      final List<PortionOption> options = NutritionAnalysisService.portionOptions(data);

      expect(options[0].label, '½ serving');
      expect(options[0].sub, '1½ biscuits · 15 g');
      expect(options[1].sub, '3 biscuits · 30 g');
      expect(NutritionAnalysisService.householdText(data, 2 / 3), '2 biscuits');
      expect(NutritionAnalysisService.householdText(data, 0.7), isNull);
    });

    test('no measure on the label: nothing is guessed', () {
      expect(NutritionAnalysisService.householdMeasure(homesoy()), isNull);
      expect(
        NutritionAnalysisService.householdMeasure(
          homesoy().copyWith(servingUnitAmount: 1, servingUnitName: 'serving'),
        ),
        isNull,
      );
    });

    test('one serving per pack and no measure: half, whole or 2 packs', () {
      final List<PortionOption> options =
          NutritionAnalysisService.portionOptions(homesoy().copyWith(servingsPerPackage: 1));

      expect(options.map((PortionOption o) => o.label), <String>[
        '½ pack',
        'Whole pack',
        '2 packs',
      ]);
    });

    test('Malay measures keep their form; English ones get a plural', () {
      const HouseholdMeasure keping =
          HouseholdMeasure(name: 'keping', perServing: 2, amountEach: 12, unit: 'g');
      const HouseholdMeasure glass =
          HouseholdMeasure(name: 'glass', perServing: 1, amountEach: 200, unit: 'ml');

      expect(keping.label(3), '3 keping');
      expect(glass.label(2), '2 glasses');
      expect(glass.label(0.5), '½ glass');
      expect(HouseholdMeasure.countText(1.5), '1½');
    });
  });
}
