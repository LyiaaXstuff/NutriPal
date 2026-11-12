// =======================================================
// NUTRITION ANALYSIS SERVICE (Layers 1-3)
// =======================================================
//
// Pure Dart, no Flutter: the same label, portion and
// profile always give the same result, so every rule can
// be unit tested (test/nutrition_analysis_service_test.dart).
//
//   Layer 1  Product level per 100 g / 100 ml
//            (FSA front-of-pack traffic lights).
//   Layer 2  Personal daily targets from the profile
//            (NASEM 2023 EER, WHO 2023/2026 limits; see
//            energy_requirement.dart).
//   Layer 3  Share of the target in the intended portion,
//            combined with Layer 1 into one level per
//            health area.
//   Layer 4  The AI assistant explains this result. It
//            never sets or changes a number.
//
// Every threshold lives in [AnalysisRules] so the report
// and the code use the same numbers.
// =======================================================

import 'dart:math' as math;

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../models/profile_setup_data.dart';
import 'energy_requirement.dart';

/// How Layer 1 and Layer 3 are combined for one nutrient.
/// See the open comment in the rules document.
enum CombineRule {
  // The worse of the product colour and the portion band.
  worseOfBoth,

  // The portion band decides; the product colour is shown
  // as context only.
  portionDecides,
}

// =======================================================
// RULE NUMBERS (rules document, Layers 1-3)
// =======================================================

class AnalysisRules {
  AnalysisRules._();

  /// Change here to switch the combine rule everywhere.
  static const CombineRule combineRule = CombineRule.worseOfBoth;

  // ---- Layer 1: FSA thresholds per 100 g (food) --------
  // [low upper limit, medium upper limit]
  static const Map<String, List<double>> foodThresholds = <String, List<double>>{
    'Total Fat': <double>[3.0, 17.5],
    'Saturated Fat': <double>[1.5, 5.0],
    'Total Sugars': <double>[5.0, 22.5],
    'Salt': <double>[0.3, 1.5],
  };

  // ---- Layer 1: FSA thresholds per 100 ml (drinks) -----
  static const Map<String, List<double>> drinkThresholds = <String, List<double>>{
    'Total Fat': <double>[1.5, 8.75],
    'Saturated Fat': <double>[0.75, 2.5],
    'Total Sugars': <double>[2.5, 11.25],
    'Salt': <double>[0.3, 0.75],
  };

  // Salt (g) = sodium (g) x 2.5.
  static const double saltPerSodium = 2.5;

  // ---- Layer 2 ----------------------------------------
  // Used only when NutriPal cannot estimate the user's
  // energy (no weight details, or an older profile under
  // 19). Energy itself: EnergyRequirement (NASEM 2023).
  static const double referenceEnergyKcal = 2000;
  static const double sodiumLimitMg = 2000;
  static const double freeSugarsShare = 0.10;
  static const double totalFatShare = 0.30;
  static const double saturatedFatShare = 0.10;
  static const double transFatShare = 0.01;
  static const double carbsShare = 0.50;
  static const int mainMealsPerDay = 3;
  static const double fibreTargetG = 25;
  static const double carbExchangeG = 15;

  // ---- Layer 3 ----------------------------------------
  static const double lowShare = 0.10;
  static const double highShare = 0.30;

  // ---- Health areas -> nutrients (rule order) ---------
  // The first entry is the key nutrient: without it the
  // area says "not enough information".
  static const Map<HealthArea, List<String>> areaNutrients =
      <HealthArea, List<String>>{
    HealthArea.diabetes: <String>['Carbohydrate', 'Total Sugars'],
    HealthArea.bloodPressure: <String>['Sodium'],
    HealthArea.cholesterol: <String>['Saturated Fat', 'Trans Fat', 'Total Fat'],
    HealthArea.weight: <String>['Energy', 'Total Fat', 'Total Sugars'],
  };

  // Areas where fibre counts as a benefit.
  static const Set<HealthArea> fibreAreas = <HealthArea>{
    HealthArea.diabetes,
    HealthArea.cholesterol,
    HealthArea.weight,
  };
}

// =======================================================
// PROFILE INPUTS (Layer 2)
// =======================================================

class NutritionProfile {
  final String? sex; // 'male' | 'female'
  final int? ageYears;
  final double? weightKg;
  final double? heightCm;
  final String? activityLevel;
  final String? weightGoal; // 'lose' | 'maintain' | 'gain'

  // kcal a day the user chose to take off (lose: 250, 500,
  // 750) or add (gain: 300, 500); null = the default.
  final int? energyChangeKcal;

  final Set<HealthArea> areas;

  // Limits from the user's doctor or dietitian (optional).
  final double? providerSodiumMg;
  final double? providerCarbsPerMealG;
  final double? providerEnergyKcal;

  const NutritionProfile({
    this.sex,
    this.ageYears,
    this.weightKg,
    this.heightCm,
    this.activityLevel,
    this.weightGoal,
    this.energyChangeKcal,
    this.areas = const <HealthArea>{},
    this.providerSodiumMg,
    this.providerCarbsPerMealG,
    this.providerEnergyKcal,
  });

  factory NutritionProfile.fromSetupData(
    ProfileSetupData data, {
    DateTime? today,
  }) {
    final DateTime now = today ?? DateTime.now();
    final DateTime? born = data.dateOfBirth;

    final int? age = born == null ? null : AdultAge.yearsOn(born, now);

    final String? goal = data.weightGoal?.toLowerCase();

    return NutritionProfile(
      sex: data.genderForEnergyEstimate?.toLowerCase(),
      ageYears: age,
      weightKg: data.weightUnit == 'lb' && data.currentWeight != null
          ? data.currentWeight! * 0.45359237
          : data.currentWeight,
      heightCm: data.heightUnit == 'in' && data.height != null
          ? data.height! * 2.54
          : data.height,
      activityLevel: ActivityLevels.normalise(data.activityLevel),
      weightGoal: goal == null
          ? null
          : goal.contains('lose')
              ? 'lose'
              : goal.contains('gain')
                  ? 'gain'
                  : 'maintain',
      energyChangeKcal: data.energyChangeKcal,
      areas: <HealthArea>{
        if (data.diabetes) HealthArea.diabetes,
        if (data.hypertension) HealthArea.bloodPressure,
        if (data.highCholesterol) HealthArea.cholesterol,
        if (data.weightManagement) HealthArea.weight,
      },
      providerSodiumMg: data.providerSodiumLimitMg,
      providerCarbsPerMealG: data.providerCarbsPerMealG,
      providerEnergyKcal: data.providerEnergyKcal,
    );
  }

  /// Areas to show: the selected ones, or all four for a
  /// user who chose general nutrition only.
  List<HealthArea> get areasToShow => areas.isEmpty
      ? HealthArea.values
      : HealthArea.values.where(areas.contains).toList();
}

// =======================================================
// THE SERVICE
// =======================================================

class NutritionAnalysisService {
  NutritionAnalysisService._();

  // Nutrients the rules use, with the unit they are
  // compared in.
  static const Map<String, String> _ruleUnits = <String, String>{
    'Energy': 'kcal',
    'Carbohydrate': 'g',
    'Total Sugars': 'g',
    'Total Fat': 'g',
    'Saturated Fat': 'g',
    'Trans Fat': 'g',
    'Sodium': 'mg',
    'Dietary Fibre': 'g',
    'Protein': 'g',
  };

  // Indented rows and the row they sit under. Dietary
  // fibre is its own row on Malaysian labels (carbohydrate
  // there excludes fibre), so it is never indented.
  static const Map<String, String> _subRowParent = <String, String>{
    'Saturated Fat': 'Total Fat',
    'Trans Fat': 'Total Fat',
    'Unsaturated Fat': 'Total Fat',
    'Monounsaturated Fat': 'Total Fat',
    'Polyunsaturated Fat': 'Total Fat',
    'Omega 3': 'Total Fat',
    'Total Sugars': 'Carbohydrate',
    'Added Sugars': 'Carbohydrate',
  };

  // =====================================================
  // LAYER 2: DAILY TARGETS
  // =====================================================

  /// NASEM 2023 maintenance energy (EER) with its standard
  /// error, or null when the profile cannot be estimated.
  static EnergyEstimate? maintenanceEnergy(NutritionProfile p) {
    return EnergyRequirement.estimate(
      sex: p.sex,
      ageYears: p.ageYears,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
      activity: p.activityLevel,
    );
  }

  /// Energy base, in this order:
  ///   1. a daily figure from the user's doctor or
  ///      dietitian (800-5,000 kcal), used as given
  ///   2. the NASEM EER (maintenance), with the weight goal
  ///      applied to the energy target only (GoalEnergy:
  ///      lose -500 by default with floors, gain +300)
  ///   3. the 2,000 kcal reference
  /// Every other limit is based on 1, 2 (maintenance) or 3.
  static DailyTargets targetsFor(NutritionProfile p) {
    final Set<String> provider = <String>{};

    double energy = AnalysisRules.referenceEnergyKcal;
    bool personal = false;
    double? low;
    double? high;
    GoalEnergyResult? goal;

    final EnergyEstimate? eer = maintenanceEnergy(p);

    if (EnergyRequirement.providerTargetOk(p.providerEnergyKcal)) {
      energy = p.providerEnergyKcal!;
      personal = true;
      provider.add('Energy');
    } else if (eer != null) {
      energy = eer.kcal;
      low = eer.lowKcal;
      high = eer.highKcal;
      personal = true;

      final GoalEnergyResult g = GoalEnergy.apply(
        maintenanceKcal: eer.kcal,
        goal: p.weightGoal,
        chosenKcal: p.energyChangeKcal,
        sex: p.sex,
        weightKg: p.weightKg,
        heightCm: p.heightCm,
      );

      // Kept for lose and gain, including "no deficit"
      // because of the floor or a low BMI, so the app can
      // say why.
      if (g.requestedKcal > 0) goal = g;
    }

    double sodium = AnalysisRules.sodiumLimitMg;

    if (p.providerSodiumMg != null && p.providerSodiumMg! > 0) {
      sodium = p.providerSodiumMg!;
      provider.add('Sodium');
    }

    final double carbsPerDay = energy * AnalysisRules.carbsShare / 4;

    double carbsPerMeal = carbsPerDay / AnalysisRules.mainMealsPerDay;

    if (p.providerCarbsPerMealG != null && p.providerCarbsPerMealG! > 0) {
      carbsPerMeal = p.providerCarbsPerMealG!;
      provider.add('Carbohydrate');
    }

    return DailyTargets(
      energyKcal: energy,
      goal: goal,
      energyIsPersonal: personal,
      energyLowKcal: low,
      energyHighKcal: high,
      sodiumMg: sodium,
      freeSugarsG: energy * AnalysisRules.freeSugarsShare / 4,
      totalFatG: energy * AnalysisRules.totalFatShare / 9,
      saturatedFatG: energy * AnalysisRules.saturatedFatShare / 9,
      transFatG: energy * AnalysisRules.transFatShare / 9,
      carbsPerDayG: carbsPerDay,
      carbsPerMealG: carbsPerMeal,
      fibreG: AnalysisRules.fibreTargetG,
      setByProvider: provider,
    );
  }

  // =====================================================
  // LAYER 1: FSA COLOUR
  // =====================================================

  static NutrientLevel? productLevel(
    String nutrient,
    double per100,
    ProductForm form,
  ) {
    final List<double>? t = (form == ProductForm.drink
        ? AnalysisRules.drinkThresholds
        : AnalysisRules.foodThresholds)[nutrient];

    if (t == null) return null;

    if (per100 <= t[0]) return NutrientLevel.low;
    if (per100 <= t[1]) return NutrientLevel.moderate;

    return NutrientLevel.high;
  }

  // =====================================================
  // LAYER 3: SHARE BAND
  // =====================================================

  static NutrientLevel shareLevel(double share) {
    if (share <= AnalysisRules.lowShare) return NutrientLevel.low;
    if (share <= AnalysisRules.highShare) return NutrientLevel.moderate;

    return NutrientLevel.high;
  }

  static NutrientLevel combine(
    NutrientLevel? product,
    NutrientLevel portion, {
    CombineRule rule = AnalysisRules.combineRule,
  }) {
    if (product == null || rule == CombineRule.portionDecides) return portion;

    return product.worse(portion);
  }

  // =====================================================
  // PRODUCT FORM
  // =====================================================

  static ProductForm formOf(NutritionLabelData data) {
    if (data.hasPer100mlColumn) return ProductForm.drink;
    if (data.hasPer100gColumn) return ProductForm.food;

    return data.servingSizeUnit?.toLowerCase() == 'ml'
        ? ProductForm.drink
        : ProductForm.food;
  }

  // =====================================================
  // PORTION OPTIONS
  // =====================================================

  static List<PortionOption> portionOptions(NutritionLabelData data) {
    final double? size = data.servingSizeAmount;
    final String unit = _portionUnit(data);
    final double? servings = data.servingsPerPackage;
    final HouseholdMeasure? measure = householdMeasure(data);

    // "1 cup (236 ml)" on the label: the serving IS one cup,
    // so the choices are named in cups. "3 biscuits (30 g)":
    // the serving stays, with the count shown underneath.
    final bool oneEach = measure != null && (measure.perServing - 1).abs() < 1e-6;

    // One serving per pack and no measure: say "pack".
    final bool singlePack = measure == null && servings != null && (servings - 1).abs() < 1e-6;

    String nameFor(double s, String fallback) {
      if (oneEach) return measure.label(s);
      if (singlePack) {
        if (s == 0.5) return '½ pack';
        if (s == 1) return 'Whole pack';
        if (s == 2) return '2 packs';
      }

      return fallback;
    }

    String subFor(double s) {
      final String amount = '${formatAmount(size! * s, unit)} $unit';

      if (measure != null && !oneEach && measure.readsNaturally(s)) {
        return '${measure.label(measure.countFor(s))} · $amount';
      }

      return amount;
    }

    final List<PortionOption> options = <PortionOption>[];

    if (size != null && size > 0) {
      options.add(PortionOption(
        label: nameFor(0.5, '½ serving'),
        sub: subFor(0.5),
        portion: const Portion.servings(0.5),
      ));
      options.add(PortionOption(
        label: nameFor(1, '1 serving'),
        sub: subFor(1),
        portion: const Portion.servings(1),
      ));

      // Always offered, even for a one-serving pack: the
      // user may have two cans.
      options.add(PortionOption(
        label: nameFor(2, '2 servings'),
        sub: subFor(2),
        portion: const Portion.servings(2),
      ));

      if (servings != null && servings > 2.05) {
        options.add(PortionOption(
          label: 'Whole pack',
          sub: '${formatAmount(size * servings, unit)} $unit',
          portion: Portion.servings(servings),
        ));
      }
    } else if (data.hasPerServingColumn) {
      options.add(const PortionOption(
        label: '1 serving',
        sub: 'as on label',
        portion: Portion.servings(1),
      ));
      options.add(const PortionOption(
        label: '2 servings',
        sub: 'as on label',
        portion: Portion.servings(2),
      ));
    }

    // 100 g / 100 ml only when the label gives no serving
    // to choose from (then it is the starting portion).
    if (options.isEmpty && (data.hasPer100gColumn || data.hasPer100mlColumn)) {
      options.add(PortionOption(
        label: '100 $unit',
        sub: 'label reference',
        portion: Portion.amount(100, unit),
      ));
    }

    return options;
  }

  // =====================================================
  // HOUSEHOLD MEASURE ("1 cup", "3 biscuits")
  // =====================================================

  // Words that are not an everyday measure.
  static const Set<String> _notAMeasure = <String>{
    'serving', 'servings', 'serve', 'hidangan', 'sajian', 'portion',
    'portions', 'g', 'ml', 'gram', 'grams', 'gm', 'l', 'kg',
  };

  static const Map<String, String> _singular = <String, String>{
    'pcs': 'piece',
    'pc': 'piece',
    'pieces': 'piece',
    'glasses': 'glass',
    'boxes': 'box',
    'pouches': 'pouch',
    'sandwiches': 'sandwich',
    'patties': 'patty',
  };

  /// The label's own everyday measure, or null when the
  /// label does not print one (then only servings, the
  /// pack and grams / ml are offered).
  static HouseholdMeasure? householdMeasure(NutritionLabelData data) {
    final double? size = data.servingSizeAmount;
    final double? count = data.servingUnitAmount;
    final String raw =
        (data.servingUnitName ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    if (size == null || size <= 0 || count == null || count <= 0 || raw.isEmpty) {
      return null;
    }

    if (_notAMeasure.contains(raw) || RegExp(r'\d').hasMatch(raw)) return null;

    String name = _singular[raw] ?? raw;

    // "chips" -> "chip", "biscuits" -> "biscuit"; not
    // "glass".
    if (name == raw && name.length > 3 && name.endsWith('s') && !name.endsWith('ss')) {
      name = name.substring(0, name.length - 1);
    }

    return HouseholdMeasure(
      name: name,
      perServing: count,
      amountEach: size / count,
      unit: _portionUnit(data),
    );
  }

  /// "½ cup" or "3 biscuits" for [servings], when it reads
  /// naturally; otherwise null.
  static String? householdText(NutritionLabelData data, double servings) {
    final HouseholdMeasure? m = householdMeasure(data);

    if (m == null || !m.readsNaturally(servings)) return null;

    return m.label(m.countFor(servings));
  }

  /// The portion shown first: one serving when the label
  /// has one, otherwise 100 g / 100 ml.
  static Portion defaultPortion(NutritionLabelData data) {
    if (data.servingSizeAmount != null || data.hasPerServingColumn) {
      return const Portion.servings(1);
    }

    return Portion.amount(100, _portionUnit(data));
  }

  static String _portionUnit(NutritionLabelData data) {
    final String? u = data.servingSizeUnit?.toLowerCase();

    if (u == 'g' || u == 'ml') return u!;

    return formOf(data) == ProductForm.drink ? 'ml' : 'g';
  }

  // =====================================================
  // ANALYSE
  // =====================================================

  static NutritionAnalysis analyse({
    required NutritionLabelData data,
    required NutritionProfile profile,
    Portion? portion,
    CombineRule rule = AnalysisRules.combineRule,
  }) {
    final Portion chosen = portion ?? defaultPortion(data);
    final ProductForm form = formOf(data);
    final DailyTargets targets = targetsFor(profile);
    final _Scale scale = _scaleFor(data, chosen);

    // ---- amounts of the rule nutrients -----------------

    final Map<String, NutrientAssessment> assessed =
        <String, NutrientAssessment>{};

    for (final MapEntry<String, String> entry in _ruleUnits.entries) {
      final String name = entry.key;
      final String unit = entry.value;

      final _Amounts? a = _amountsFor(data, name, unit, scale);

      if (a == null || a.portion == null) continue;

      final double amount = a.portion!;
      final double? per100 = a.per100;

      NutrientLevel? product;

      if (per100 != null) {
        if (name == 'Sodium') {
          product = productLevel(
            'Salt',
            per100 / 1000 * AnalysisRules.saltPerSodium,
            form,
          );
        } else {
          product = productLevel(name, per100, form);
        }
      }

      final (double? target, String? label) = switch (name) {
        'Energy' => (targets.goalEnergyKcal, 'daily energy'),
        'Carbohydrate' => (targets.carbsPerMealG, 'meal budget'),
        'Total Sugars' => (targets.freeSugarsG, 'daily sugar limit'),
        'Total Fat' => (targets.totalFatG, 'daily fat limit'),
        'Saturated Fat' => (targets.saturatedFatG, 'daily limit'),
        'Trans Fat' => (targets.transFatG, 'daily limit'),
        'Sodium' => (targets.sodiumMg, 'daily limit'),
        'Dietary Fibre' => (targets.fibreG, 'daily target'),
        _ => (null, null),
      };

      final double? share =
          target == null || target <= 0 ? null : amount / target;

      final bool benefit = name == 'Dietary Fibre';

      NutrientLevel? level;

      if (share != null && !benefit) {
        level = combine(product, shareLevel(share), rule: rule);
      }

      assessed[name] = NutrientAssessment(
        name: name,
        amount: amount,
        unit: unit,
        per100: per100,
        productLevel: product,
        share: share,
        target: target,
        targetLabel: label,
        level: level,
        isBenefit: benefit,
      );
    }

    // ---- areas -----------------------------------------

    final List<AreaAssessment> areas = <AreaAssessment>[];

    for (final HealthArea area in profile.areasToShow) {
      final List<String> names = AnalysisRules.areaNutrients[area]!;

      final List<NutrientAssessment> rated = <NutrientAssessment>[
        for (final String n in names)
          if (assessed[n]?.level != null) assessed[n]!,
      ];

      final List<String> missing = <String>[
        for (final String n in names)
          if (assessed[n] == null) n,
      ];

      // Cholesterol: saturated fat, or failing that total
      // fat, is enough to judge.
      final bool hasKey = area == HealthArea.cholesterol
          ? assessed['Saturated Fat'] != null || assessed['Total Fat'] != null
          : assessed[names.first] != null;

      NutrientLevel? level;
      String? decidedBy;

      if (hasKey) {
        for (final NutrientAssessment n in rated) {
          if (level == null || n.level!.index > level.index) {
            level = n.level;
            decidedBy = n.name;
          }
        }
      }

      areas.add(AreaAssessment(
        area: area,
        level: level,
        decidedBy: decidedBy,
        nutrients: rated,
        benefit: AnalysisRules.fibreAreas.contains(area)
            ? assessed['Dietary Fibre']
            : null,
        missing: missing,
      ));
    }

    NutrientLevel? overall;

    for (final AreaAssessment a in areas) {
      if (a.level == null) continue;

      overall = overall == null ? a.level : overall.worse(a.level!);
    }

    return NutritionAnalysis(
      portion: chosen,
      portionAmount: scale.amount,
      portionUnit: scale.amount == null ? null : _portionUnit(data),
      portionServings: scale.servings,
      form: form,
      per100Label: form == ProductForm.drink ? 'per 100 ml' : 'per 100 g',
      targets: targets,
      nutrients: assessed,
      areas: areas,
      overall: overall,
      facts: _facts(data, scale),
    );
  }

  // =====================================================
  // PORTION SCALE
  // =====================================================
  //
  // How to turn each column into the portion:
  //   servings chosen   ->  per serving x servings
  //   g / ml chosen     ->  per 100 x amount / 100
  //
  // So "1 serving" shows exactly what the label prints for
  // one serving (labels round, e.g. 6 mg per can but 2 mg
  // per 100 ml), and "100 ml" shows the per 100 column.
  // =====================================================

  static _Scale _scaleFor(NutritionLabelData data, Portion portion) {
    final double? size = data.servingSizeAmount;

    double? amount = portion.amount;
    double? servings = portion.servings;

    if (amount == null && servings != null && size != null && size > 0) {
      amount = servings * size;
    }

    if (servings == null && amount != null && size != null && size > 0) {
      servings = amount / size;
    }

    return _Scale(
      amount: amount,
      servings: servings,
      byServing: portion.servings != null,
    );
  }

  // =====================================================
  // ONE NUTRIENT -> PORTION + PER 100 AMOUNTS
  // =====================================================

  static _Amounts? _amountsFor(
    NutritionLabelData data,
    String name,
    String unit,
    _Scale scale,
  ) {
    NutrientRow? row = _row(data, name);

    // Labels that print salt but not sodium.
    double factor = 1;

    if (row == null && name == 'Sodium') {
      row = _row(data, 'Salt');
      factor = 1 / AnalysisRules.saltPerSodium;
    }

    if (row == null) return null;

    final int p100 = _per100Column(data);
    final int ps = data.columnIndexFor(NutritionColumnBasis.perServing);
    final double? size = data.servingSizeAmount;

    double? per100;
    double? perServing;

    if (p100 >= 0 && p100 < row.valuesByColumn.length) {
      per100 = _inUnit(row.valuesByColumn[p100], unit, name);
    }

    if (ps >= 0 && ps < row.valuesByColumn.length) {
      perServing = _inUnit(row.valuesByColumn[ps], unit, name);
    }

    if (per100 != null) per100 *= factor;
    if (perServing != null) perServing *= factor;

    // per 100 from per serving when only that is printed.
    if (per100 == null && perServing != null && size != null && size > 0) {
      per100 = perServing * 100 / size;
    }

    double? portion;

    if (scale.byServing && scale.servings != null && perServing != null) {
      portion = perServing * scale.servings!;
    } else if (scale.amount != null && per100 != null) {
      portion = per100 * scale.amount! / 100;
    } else if (scale.servings != null && perServing != null) {
      portion = perServing * scale.servings!;
    }

    if (per100 == null && portion == null) return null;

    return _Amounts(portion: portion, per100: per100);
  }

  static NutrientRow? _row(NutritionLabelData data, String name) {
    for (final NutrientRow row in data.nutrients) {
      if (row.name == name && row.hasAnyValue) return row;
    }

    return null;
  }

  static int _per100Column(NutritionLabelData data) {
    final int g = data.columnIndexFor(NutritionColumnBasis.per100g);

    return g >= 0 ? g : data.columnIndexFor(NutritionColumnBasis.per100ml);
  }

  /// First value of a cell converted to [unit]; energy
  /// prefers kcal and falls back to kJ.
  static double? _inUnit(
    List<NutritionValue> cell,
    String unit,
    String name,
  ) {
    if (cell.isEmpty) return null;

    if (unit == 'kcal') {
      for (final NutritionValue v in cell) {
        if (v.unit == 'kcal') return v.amount;
      }

      for (final NutritionValue v in cell) {
        if (v.unit == 'kJ') return v.amount / 4.184;
      }

      return cell.first.unit == '?' ? cell.first.amount : null;
    }

    for (final NutritionValue v in cell) {
      final double? converted = convertMass(v.amount, v.unit, unit);

      if (converted != null) return converted;
    }

    // Unit could not be read: assume the usual unit
    // (Quick verification asks the user first).
    final NutritionValue first = cell.first;

    if (first.unit == '?') return first.amount;

    return null;
  }

  static double? convertMass(double amount, String from, String to) {
    const Map<String, double> grams = <String, double>{
      'g': 1,
      'mg': 0.001,
      'µg': 0.000001,
    };

    final double? f = grams[from];
    final double? t = grams[to];

    if (f == null || t == null) return null;

    return amount * f / t;
  }

  // =====================================================
  // NUTRITION FACTS TABLE
  // =====================================================

  static List<FactRow> _facts(NutritionLabelData data, _Scale scale) {
    final int p100 = _per100Column(data);
    final int ps = data.columnIndexFor(NutritionColumnBasis.perServing);
    final double? size = data.servingSizeAmount;

    final List<FactRow> rows = <FactRow>[];

    // Parent of the rows that may be indented next
    // ("Total Fat" after Total Fat or one of its parts).
    String? group;

    for (final NutrientRow row in data.nutrients) {
      if (!row.hasAnyValue) continue;

      // Indent only directly under the parent or a sibling,
      // so a row read out of order is not shown as a part
      // of the wrong nutrient.
      final String? parent = _subRowParent[row.name];
      final bool isSubRow = parent != null && parent == group;
      group = isSubRow ? group : (_subRowParent.containsValue(row.name) ? row.name : null);

      List<NutritionValue>? per100Cell;
      List<NutritionValue>? servingCell;

      if (p100 >= 0 && p100 < row.valuesByColumn.length) {
        per100Cell = row.valuesByColumn[p100];
      }

      if (ps >= 0 && ps < row.valuesByColumn.length) {
        servingCell = row.valuesByColumn[ps];
      }

      // Pick the value to show (kcal before kJ).
      NutritionValue? pick(List<NutritionValue>? cell) {
        if (cell == null || cell.isEmpty) return null;

        for (final NutritionValue v in cell) {
          if (v.unit == 'kcal') return v;
        }

        return cell.first;
      }

      final NutritionValue? v100 = pick(per100Cell);
      final NutritionValue? vs = pick(servingCell);

      double? per100;
      String unit = v100?.unit ?? vs?.unit ?? '';

      // The label value itself, when a column is shown as
      // printed (not calculated), so it keeps the pack's
      // own digits: 2.66 µg, 3.0 g, <0.1 g.
      NutritionValue? per100Printed;
      NutritionValue? portionPrinted;

      if (v100 != null) {
        per100 = v100.amount;
        per100Printed = v100;
      } else if (vs != null && size != null && size > 0) {
        per100 = vs.amount * 100 / size;
      }

      double? portion;
      String portionUnit = unit;

      if (scale.byServing && scale.servings != null && vs != null) {
        portion = vs.amount * scale.servings!;
        portionUnit = vs.unit;
        if (scale.servings == 1) portionPrinted = vs;
      } else if (scale.amount != null && per100 != null) {
        portion = per100 * scale.amount! / 100;
        if (scale.amount == 100) portionPrinted = per100Printed;
      } else if (scale.servings != null && vs != null) {
        portion = vs.amount * scale.servings!;
        portionUnit = vs.unit;
        if (scale.servings == 1) portionPrinted = vs;
      }

      String text(double? value, String u, NutritionValue? printed) {
        if (value == null) return '–';

        final String number =
            printed != null ? printedAmount(printed) : formatAmount(value, u);

        return u == '?' || u.isEmpty ? number : '$number $u';
      }

      rows.add(FactRow(
        name: row.name,
        portion: text(portion, portionUnit, portionPrinted),
        per100: text(per100, unit, per100Printed),
        isSubRow: isSubRow,
      ));
    }

    return rows;
  }

  // =====================================================
  // DISPLAY
  // =====================================================

  /// 92 kcal, 40 mg, 7.1 g, 0.7 g, 0.05 g.
  static String formatAmount(double value, String unit) {
    final double v = value.abs();

    String text;

    if (v >= 100 || (v >= 10 && unit != 'g' && unit != 'ml')) {
      text = value.round().toString();
    } else if (v >= 1 || v == 0) {
      text = value.toStringAsFixed(1);
    } else if (v >= 0.1) {
      text = value.toStringAsFixed(1);
    } else {
      text = value.toStringAsFixed(2);
    }

    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }

    return text;
  }

  /// A label value exactly as the pack prints it: 2.66,
  /// 3.0, <0.1. The digits come from the printed text when
  /// it holds the same number; otherwise the stored amount
  /// is shown without rounding (only float noise removed).
  static String printedAmount(NutritionValue v) {
    final RegExpMatch? m =
        RegExp(r'^\s*(<)?\s*(\d+(?:[.,]\d+)?)').firstMatch(v.rawText);

    if (m != null) {
      final String digits = m.group(2)!.replaceAll(',', '.');
      final double? printed = double.tryParse(digits);

      // Labels print a few decimals at most; a long tail
      // ("0.30000000000000004") is a computed number.
      final int decimals = digits.contains('.') ? digits.split('.').last.length : 0;

      if (printed != null && decimals <= 3 && (printed - v.amount).abs() < 1e-9) {
        return '${m.group(1) ?? ''}$digits';
      }
    }

    String text = v.amount.toStringAsFixed(4);
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');

    return text;
  }

  /// "12%" (shares above 999 % are capped for display).
  static String formatShare(double share) {
    final double pct = share * 100;

    if (pct > 0 && pct < 1) return '<1%';

    return '${math.min(pct, 999).round()}%';
  }

  static String exchanges(double carbsG) =>
      formatAmount(carbsG / AnalysisRules.carbExchangeG, 'g');
}

class _Scale {
  final double? amount;
  final double? servings;

  // True when the user picked servings (not g / ml).
  final bool byServing;

  const _Scale({
    required this.amount,
    required this.servings,
    required this.byServing,
  });
}

class _Amounts {
  final double? portion;
  final double? per100;

  const _Amounts({required this.portion, required this.per100});
}
