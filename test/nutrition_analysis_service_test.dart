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
// Diabetes: the carb-counting guide (45 g meal budget).
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
      // Diabetes: carb-counting guide for women.
      expect(t.carbsPerMealG, 45);
      expect(t.carbsBasis, CarbBudgetBasis.carbCounting);
      expect(t.carbsPerDayG, closeTo(261.5, 0.1));
      expect(t.saturatedFatG, closeTo(23.2, 0.1));
      expect(t.fibreG, 25);
      expect(t.setByProvider, isEmpty);
      expect(t.setByUser, isEmpty);
      expect(t.proteinG, isNull);
    });

    test('W-T17 every weight goal uses maintenance energy (no fixed change)', () {
      NutritionProfile withGoal(String goal) => NutritionProfile(
            sex: 'male',
            ageYears: 30,
            weightKg: 75,
            heightCm: 175,
            activityLevel: 'Active',
            weightGoal: goal,
          );

      DailyTargets t(String goal) => NutritionAnalysisService.targetsFor(withGoal(goal));

      // Men, active: 1004.82 - 324.9 + 1141 + 1193.25
      for (final String goal in <String>['lose', 'maintain', 'gain']) {
        // Every other limit stays on maintenance energy.
        expect(t(goal).energyKcal, closeTo(3014.2, 0.1));
        expect(t(goal).freeSugarsG, closeTo(75.4, 0.1));
      }

      // Weight Management Analysis Guidance: lose, maintain and
      // gain all compare with maintenance; nothing is taken
      // off or added.
      for (final String goal in <String>['lose', 'maintain', 'gain']) {
        expect(t(goal).goalEnergyKcal, closeTo(3014.2, 0.1));
        expect(t(goal).goal, isNull);
        expect(t(goal).goalAdjusted, isFalse);
      }
    });

    test('W-T18 the energy share uses maintenance energy for weight loss too', () {
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

      // 390 kcal of the 2092.2 kcal maintenance estimate.
      expect(a.nutrients['Energy']!.share, closeTo(390 / 2092.2, 0.001));
      // Sugars still use the maintenance limit (52.3 g).
      expect(a.nutrients['Total Sugars']!.share, closeTo(7 / 52.3, 0.001));
    });

    test('W-T19 lose: energy and its share, then protein, fibre, sugars and fat', () {
      const NutritionProfile loser = NutritionProfile(
        sex: 'female',
        ageYears: 45,
        weightKg: 65,
        heightCm: 158,
        activityLevel: 'Low active',
        weightGoal: 'lose',
        areas: <HealthArea>{HealthArea.weight},
      );

      final AreaAssessment w = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: loser,
        portion: const Portion.amount(1000, 'ml'),
      ).areas.single;

      expect(w.level, isNull);
      expect(w.nutrients.map((NutrientAssessment n) => n.name), <String>['Energy']);
      expect(w.nutrients.single.level, isNull);
      expect(w.nutrients.single.share, closeTo(390 / 2092.2, 0.001));
      // Amounts only, no share or level.
      expect(w.watch.map((NutrientAssessment n) => n.name),
          <String>['Protein', 'Dietary Fibre', 'Total Sugars', 'Total Fat']);
      expect(w.watch.every((NutrientAssessment n) => n.share == null && n.level == null), isTrue);
      // Fibre is in the list, so no separate fibre note.
      expect(w.benefit, isNull);
    });

    test('W-T21 maintain adds protein; gain adds protein and sugars', () {
      AreaAssessment card(String goal) => NutritionAnalysisService.analyse(
            data: homesoy(),
            profile: NutritionProfile(
              sex: 'female',
              ageYears: 45,
              weightKg: 65,
              heightCm: 158,
              activityLevel: 'Low active',
              weightGoal: goal,
              areas: const <HealthArea>{HealthArea.weight},
            ),
          ).areas.single;

      expect(card('maintain').watch.map((NutrientAssessment n) => n.name), <String>['Protein']);
      expect(card('maintain').benefit?.name, 'Dietary Fibre');
      expect(card('gain').watch.map((NutrientAssessment n) => n.name),
          <String>['Protein', 'Total Sugars']);
      expect(card('gain').missing, isEmpty);
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

    test('NT-T01 the user\'s own targets replace the defaults', () {
      const NutritionProfile p = NutritionProfile(
        sodiumLimitMg: 1500,
        sugarsLimitG: 25,
        fatGoalG: 50,
        saturatedFatLimitG: 13,
        fibreGoalG: 30,
        proteinGoalG: 60,
        carbsPerMealGoalG: 40,
      );

      final DailyTargets t = NutritionAnalysisService.targetsFor(p);

      expect(t.sodiumMg, 1500);
      expect(t.freeSugarsG, 25);
      expect(t.totalFatG, 50);
      expect(t.saturatedFatG, 13);
      expect(t.fibreG, 30);
      expect(t.proteinG, 60);
      expect(t.carbsPerMealG, 40);
      expect(t.carbsBasis, CarbBudgetBasis.userGoal);
      expect(t.setByUser, containsAll(<String>[
        'Sodium',
        'Total Sugars',
        'Total Fat',
        'Saturated Fat',
        'Dietary Fibre',
        'Protein',
        'Carbohydrate',
      ]));
      // Trans fat has no user target.
      expect(t.transFatG, closeTo(2000 * 0.01 / 9, 0.01));
      expect(t.setByProvider, isEmpty);
    });

    test('NT-T02 a protein goal is shown as a benefit, never a level', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(proteinGoalG: 60),
      );

      final NutrientAssessment protein = a.nutrients['Protein']!;

      expect(protein.share, closeTo(7.1 / 60, 0.001));
      expect(protein.isBenefit, isTrue);
      expect(protein.level, isNull);
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

    test('carbohydrate meal budget: 25 % and 50 % edges', () {
      double share(double v, String name) {
        final (double low, double high) = NutritionAnalysisService.bandsFor(name);

        return NutritionAnalysisService.shareLevel(v, low: low, high: high).index.toDouble();
      }

      expect(share(0.25, 'Carbohydrate'), NutrientLevel.low.index);
      expect(share(0.26, 'Carbohydrate'), NutrientLevel.moderate.index);
      expect(share(0.50, 'Carbohydrate'), NutrientLevel.moderate.index);
      expect(share(0.51, 'Carbohydrate'), NutrientLevel.high.index);
      expect(share(0.26, 'Total Sugars'), NutrientLevel.moderate.index);
    });
  });

  group('Worked example: Homesoy', () {
    test('one 236 ml serving: key nutrients for diabetes and blood pressure, no level', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
      );

      expect(a.form, ProductForm.drink);
      expect(a.portionAmount, 236);

      // One serving uses the per serving column as printed.
      final NutrientAssessment carbs = a.nutrients['Carbohydrate']!;
      expect(carbs.amount, closeTo(5.4, 0.001));

      final NutrientAssessment sodium = a.nutrients['Sodium']!;
      expect(sodium.amount, closeTo(40, 0.001));
      expect(sodium.share, closeTo(0.020, 0.001));
      expect(sodium.productLevel, NutrientLevel.low);

      expect(a.nutrients['Total Fat']!.productLevel, NutrientLevel.moderate);
      expect(a.nutrients['Dietary Fibre']!.share, closeTo(0.14, 0.001));
      expect(a.nutrients['Dietary Fibre']!.level, isNull);

      expect(a.areas.map((AreaAssessment x) => x.area),
          <HealthArea>[HealthArea.diabetes, HealthArea.bloodPressure]);

      // Diabetes: carbohydrate and sugars as amounts, no level.
      final AreaAssessment dm = a.areas[0];
      expect(dm.partial, isTrue);
      expect(dm.level, isNull);
      expect(dm.watch.map((NutrientAssessment n) => n.name), <String>['Carbohydrate', 'Total Sugars']);
      expect(dm.watch.every((NutrientAssessment n) => n.level == null && n.share == null), isTrue);
      expect(dm.watch.last.productLevel, NutrientLevel.low);
      expect(dm.benefit?.name, 'Dietary Fibre');

      // Blood pressure: sodium with its share and traffic light.
      final AreaAssessment bp = a.areas[1];
      expect(bp.level, isNull);
      expect(bp.nutrients.single.name, 'Sodium');
      expect(bp.nutrients.single.level, isNull);
      expect(bp.nutrients.single.share, closeTo(0.020, 0.001));
      expect(bp.nutrients.single.productLevel, NutrientLevel.low);

      expect(a.overall, isNull);
      expect(a.needsDetails, isTrue);
    });

    test('no portion size ever gives an area level or an overall result', () {
      for (final double ml in <double>[236, 500, 1000, 3000]) {
        final NutritionAnalysis a = NutritionAnalysisService.analyse(
          data: homesoy(),
          profile: sampleUser,
          portion: Portion.amount(ml, 'ml'),
        );

        expect(a.overall, isNull);
        expect(a.areas.every((AreaAssessment x) => x.level == null && x.decidedBy == null), isTrue);
      }

      final NutritionAnalysis litre = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: sampleUser,
        portion: const Portion.amount(1000, 'ml'),
      );

      expect(litre.nutrients['Carbohydrate']!.amount, closeTo(23, 0.01));
    });
  });

  group('Diabetes (one card, no types; D-T01 to D-T04)', () {
    NutritionProfile user({String sex = 'female', double? carbGoal}) => NutritionProfile(
          sex: sex,
          ageYears: 45,
          weightKg: 65,
          heightCm: 158,
          activityLevel: 'Low active',
          areas: const <HealthArea>{HealthArea.diabetes},
          carbsPerMealGoalG: carbGoal,
        );

    NutritionAnalysis litre(NutritionProfile p) => NutritionAnalysisService.analyse(
          data: homesoy(),
          profile: p,
          portion: const Portion.amount(1000, 'ml'),
        );

    test('D-T01 carbohydrate and sugars as amounts only, no level', () {
      final NutritionAnalysis a = litre(user());
      final AreaAssessment area = a.areas.single;

      expect(area.partial, isTrue);
      expect(area.level, isNull);
      expect(area.decidedBy, isNull);
      expect(area.ruleNutrients, <String>['Carbohydrate', 'Total Sugars']);
      expect(area.watch.map((NutrientAssessment n) => n.name), <String>['Carbohydrate', 'Total Sugars']);
      expect(area.watch.first.amount, closeTo(23, 0.01));
      // Amounts only on the card: no share of a meal budget.
      expect(area.watch.every((NutrientAssessment n) => n.share == null && n.level == null), isTrue);
      expect(area.nutrients, isEmpty);
    });

    test('D-T02 the same card for every user with diabetes (men and women)', () {
      final AreaAssessment woman = litre(user()).areas.single;
      final AreaAssessment man = litre(user(sex: 'male')).areas.single;

      expect(man.watch.map((NutrientAssessment n) => n.name), woman.watch.map((NutrientAssessment n) => n.name));
      expect(man.level, isNull);
      // The background meal budget still follows the
      // carb-counting guide by sex.
      expect(litre(user(sex: 'male')).targets.carbsPerMealG, 60);
      expect(litre(user()).targets.carbsPerMealG, 45);
    });

    test('D-T03 a user\'s own carbohydrate goal does not rate the diabetes card', () {
      final NutritionAnalysis a = litre(user(carbGoal: 60));
      final AreaAssessment area = a.areas.single;

      expect(a.targets.carbsBasis, CarbBudgetBasis.userGoal);
      expect(a.nutrients['Carbohydrate']!.share, closeTo(23 / 60, 0.001));
      expect(area.level, isNull);
      expect(area.watch.every((NutrientAssessment n) => n.share == null), isTrue);
    });

    test('D-T04 no diabetes selected: healthy-eating share for the meal budget', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(),
      );

      expect(a.targets.carbsBasis, CarbBudgetBasis.energyShare);
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

    test('salty crisps: sodium share and High traffic light, no area level', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: crisps(),
        profile: bp,
        portion: const Portion.amount(20, 'g'),
      );

      expect(a.nutrients['Sodium']!.share, closeTo(0.08, 0.001));
      expect(a.nutrients['Sodium']!.productLevel, NutrientLevel.high);
      expect(a.areas.single.level, isNull);
      expect(a.areas.single.nutrients.single.level, isNull);
      expect(a.areas.single.nutrients.single.productLevel, NutrientLevel.high);
      expect(a.overall, isNull);
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
      expect(a.areas.single.watch, isEmpty);
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

  group('High LDL cholesterol (R-LDL-01)', () {
    test('LDL-T00 selecting high LDL cholesterol gives one LDL card, no sub-types', () {
      final NutritionProfile p = NutritionProfile.fromSetupData(ProfileSetupData(highCholesterol: true));

      expect(p.areas, <HealthArea>{HealthArea.cholesterol});

      // An older profile that saved cholesterol details
      // (LDL / triglycerides / not sure) still gets only the
      // LDL card; the old details are ignored.
      final ProfileSetupData old = ProfileSetupData.fromJson(<String, dynamic>{
        'conditions': <String, dynamic>{'highCholesterol': true},
        'diabetesType': 'Prediabetes',
        'cholesterol': <String, dynamic>{'highLdl': false, 'highTriglycerides': true, 'notSure': false},
      });

      expect(NutritionProfile.fromSetupData(old).areas, <HealthArea>{HealthArea.cholesterol});
    });

    test('LDL-T03 the card shows the plain share and keeps the traffic light separate', () {
      // Saturated fat 6 g per 100 g (traffic light High),
      // 10 g portion: 0.6 g of 22.2 g (3%).
      final NutritionLabelData biscuit = NutritionLabelData(
        rawText: '',
        columns: const <NutritionColumn>[
          NutritionColumn(id: 'per_100g', label: 'Per 100 g', basis: NutritionColumnBasis.per100g, xCenter: 0),
        ],
        nutrients: const <NutrientRow>[
          NutrientRow(name: 'Saturated Fat', order: 0, valuesByColumn: <List<NutritionValue>>[
            <NutritionValue>[NutritionValue(amount: 6, unit: 'g', rawText: '6')],
          ]),
        ],
      );

      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: biscuit,
        profile: const NutritionProfile(areas: <HealthArea>{HealthArea.cholesterol}),
        portion: const Portion.amount(10, 'g'),
      );

      final AreaAssessment x = a.areas.single;

      expect(a.nutrients['Saturated Fat']!.productLevel, NutrientLevel.high);
      expect(x.area, HealthArea.cholesterol);
      expect(x.level, isNull);
      expect(x.partial, isTrue);
      expect(x.nutrients.single.name, 'Saturated Fat');
      expect(x.nutrients.single.level, isNull);
      expect(x.nutrients.single.share, closeTo(0.027, 0.002));
      expect(x.nutrients.single.productLevel, NutrientLevel.high);
      expect(a.overall, isNull);
    });

    test('LDL-T01 LDL card: key nutrients with no level, total fat as context', () {
      const NutritionProfile ldlUser = NutritionProfile(areas: <HealthArea>{HealthArea.cholesterol});

      final NutritionAnalysis a = NutritionAnalysisService.analyse(data: homesoy(), profile: ldlUser);
      final AreaAssessment ldl = a.areas.single;

      expect(ldl.area, HealthArea.cholesterol);
      expect(ldl.level, isNull);
      expect(ldl.decidedBy, isNull);
      expect(ldl.partial, isTrue);
      expect(ldl.nutrients.map((NutrientAssessment n) => n.name), <String>['Saturated Fat', 'Total Fat']);
      expect(ldl.nutrients.every((NutrientAssessment n) => n.level == null), isTrue);
      expect(ldl.nutrients.first.productLevel, NutrientLevel.low);
      expect(ldl.nutrients.last.productLevel, NutrientLevel.moderate);
      expect(ldl.missing, contains('Trans Fat'));
      expect(ldl.watch, isEmpty);
      expect(ldl.benefit?.name, 'Dietary Fibre');
      expect(a.overall, isNull);
      expect(a.needsDetails, isTrue);
    });

    test('LDL-T02 no area sets an overall result, even at 1.5 litres', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(
          areas: <HealthArea>{HealthArea.diabetes, HealthArea.cholesterol},
        ),
        portion: const Portion.amount(1500, 'ml'),
      );

      expect(a.areas.where((AreaAssessment x) => x.level != null), isEmpty);
      expect(a.overall, isNull);
    });

    test('LDL-T04 general nutrition users see the four cards', () {
      final NutritionAnalysis a = NutritionAnalysisService.analyse(
        data: homesoy(),
        profile: const NutritionProfile(),
      );

      expect(a.areas.map((AreaAssessment x) => x.area), <HealthArea>[
        HealthArea.diabetes,
        HealthArea.bloodPressure,
        HealthArea.cholesterol,
        HealthArea.weight,
      ]);
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
