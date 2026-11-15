// =======================================================
// NUTRITION ANALYSIS RESULT
// =======================================================
//
// What NutritionAnalysisService returns for one product,
// one portion and one user. Pure data: no Flutter imports,
// so it can be unit tested.
//
// See "NutriPal Nutrition Analysis Rules" (the rules
// document) for where every threshold comes from.
// =======================================================

import '../services/energy_requirement.dart' show GoalEnergyResult;

enum NutrientLevel { low, moderate, high }

extension NutrientLevelText on NutrientLevel {
  String get label => switch (this) {
        NutrientLevel.low => 'Low',
        NutrientLevel.moderate => 'Moderate',
        NutrientLevel.high => 'High',
      };

  /// Worse (higher) of two levels.
  NutrientLevel worse(NutrientLevel other) =>
      index >= other.index ? this : other;
}

// cholesterol is the high LDL cholesterol card. Its title
// "Cholesterol" is the area name the Cloud Functions and
// the knowledge base use; the card says "High LDL
// cholesterol". Diabetes is one card for every user who
// selects it (no types).
enum HealthArea { diabetes, bloodPressure, cholesterol, weight }

extension HealthAreaText on HealthArea {
  String get title => switch (this) {
        HealthArea.diabetes => 'Diabetes',
        HealthArea.bloodPressure => 'Blood pressure',
        HealthArea.cholesterol => 'Cholesterol',
        HealthArea.weight => 'Weight',
      };

  String get focus => switch (this) {
        HealthArea.diabetes => 'Carbohydrate and sugars',
        HealthArea.bloodPressure => 'Sodium',
        HealthArea.cholesterol => 'Saturated and trans fat',
        HealthArea.weight => 'Energy, fat and sugar',
      };

  String get short => switch (this) {
        HealthArea.diabetes => 'DM',
        HealthArea.bloodPressure => 'BP',
        HealthArea.cholesterol => 'CH',
        HealthArea.weight => 'WT',
      };
}

/// Where the carbohydrate meal budget comes from.
enum CarbBudgetBasis {
  // The user's own Carbohydrate goal (Nutrition Targets).
  userGoal,
  // Carb-counting guide by sex (users with diabetes).
  carbCounting,
  // 50 % of energy over 3 meals (no diabetes).
  energyShare,
}

/// Food or drink decides which Layer 1 table is used.
enum ProductForm { food, drink }

// =======================================================
// PORTION
// =======================================================
//
// Either a number of servings ("1 serving") or an amount
// in g / ml ("150 ml"). When the label gives a serving
// size, the two can be converted into each other.
// =======================================================

class Portion {
  final double? servings;

  final double? amount;

  // 'g' or 'ml' when [amount] is set.
  final String? unit;

  const Portion.servings(double this.servings)
      : amount = null,
        unit = null;

  const Portion.amount(double this.amount, String this.unit)
      : servings = null;

  @override
  bool operator ==(Object other) =>
      other is Portion &&
      other.servings == servings &&
      other.amount == amount &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(servings, amount, unit);
}

// =======================================================
// HOUSEHOLD MEASURE
// =======================================================
//
// The everyday measure printed next to the serving size,
// e.g. "236 ml (1 cup)" or "30 g (3 biscuits)". Only built
// when the label states it; NutriPal never guesses the
// size of a cup or a biscuit.

class HouseholdMeasure {
  /// Singular name as on the label ("cup", "biscuit",
  /// "keping").
  final String name;

  /// How many make one serving (3 for "3 biscuits").
  final double perServing;

  /// Weight or volume of one (10 for one 10 g biscuit).
  final double amountEach;

  /// 'g' or 'ml'.
  final String unit;

  const HouseholdMeasure({
    required this.name,
    required this.perServing,
    required this.amountEach,
    required this.unit,
  });

  // Malay measures and abbreviations have no plural form.
  static const Set<String> _samePlural = <String>{
    'keping', 'biji', 'paket', 'uncang', 'cawan', 'botol', 'tin',
    'bungkus', 'batang', 'sudu', 'sudu besar', 'sudu teh', 'pek',
    'kotak', 'tbsp', 'tsp',
  };

  /// "cup" / "cups", "glass" / "glasses", "keping" / "keping".
  String nameFor(double count) {
    if (count <= 1 || _samePlural.contains(name)) return name;

    if (RegExp(r'(s|x|ch|sh)$').hasMatch(name)) return '${name}es';
    if (RegExp(r'[^aeiou]y$').hasMatch(name)) {
      return '${name.substring(0, name.length - 1)}ies';
    }

    return '${name}s';
  }

  /// "½", "1", "1½", "2.4".
  static String countText(double count) {
    final double whole = count.floorToDouble();
    final double rest = count - whole;

    String fraction(double r) {
      if ((r - 0.5).abs() < 1e-6) return '½';
      if ((r - 0.25).abs() < 1e-6) return '¼';
      if ((r - 0.75).abs() < 1e-6) return '¾';

      return '';
    }

    if (rest.abs() < 1e-6) return whole.toInt().toString();

    final String f = fraction(rest);

    if (f.isNotEmpty) return whole == 0 ? f : '${whole.toInt()}$f';

    return count.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  /// "½ cup", "3 biscuits".
  String label(double count) => '${countText(count)} ${nameFor(count)}';

  /// Servings for [count] of them (1 biscuit = 1/3 serving).
  double servingsFor(double count) => count / perServing;

  /// How many of them [servings] is (1/3 serving = 1).
  double countFor(double servings) => servings * perServing;

  /// True when [servings] is a whole number of them, or a
  /// half, so it reads naturally ("2 biscuits", "½ cup").
  bool readsNaturally(double servings) {
    final double c = countFor(servings);

    return ((c * 2) - (c * 2).roundToDouble()).abs() < 1e-6 && c > 0;
  }
}

/// A ready-made choice for the "How much will you have?"
/// picker.
class PortionOption {
  final String label;

  final String sub;

  final Portion portion;

  const PortionOption({
    required this.label,
    required this.sub,
    required this.portion,
  });
}

// =======================================================
// LAYER 2: DAILY TARGETS
// =======================================================

class DailyTargets {
  // Energy base for every limit: the provider's figure,
  // the NASEM maintenance estimate or the 2,000 kcal
  // reference.
  final double energyKcal;

  // Always null now: lose, maintain and gain all use the
  // maintenance estimate (Weight Management Analysis
  // Guidance), so no goal change is applied. Kept so older
  // code paths still compile.
  final GoalEnergyResult? goal;

  /// Energy target for judging each product's energy.
  double get goalEnergyKcal => goal?.kcal ?? energyKcal;

  /// True when the energy target differs from maintenance.
  bool get goalAdjusted => goal?.adjusted ?? false;

  // False when the profile lacks age, sex, weight, height
  // or activity and the 2,000 kcal reference was used.
  final bool energyIsPersonal;

  // Likely range of the NASEM estimate (EER plus or minus
  // one standard error). Null for a provider figure or the
  // 2,000 kcal reference.
  final double? energyLowKcal;

  final double? energyHighKcal;

  final double sodiumMg;

  final double freeSugarsG;

  final double totalFatG;

  final double saturatedFatG;

  final double transFatG;

  final double carbsPerDayG;

  final double carbsPerMealG;

  final double fibreG;

  // Where carbsPerMealG comes from.
  final CarbBudgetBasis carbsBasis;

  // The user's protein goal (a benefit, not a limit), or
  // null when not set.
  final double? proteinG;

  // The daily energy figure from the user's doctor or
  // dietitian ('Energy'), when set.
  final Set<String> setByProvider;

  // Nutrients whose target the user entered in Nutrition
  // Targets ('Carbohydrate', 'Sodium', ...).
  final Set<String> setByUser;

  const DailyTargets({
    required this.energyKcal,
    this.goal,
    required this.energyIsPersonal,
    this.energyLowKcal,
    this.energyHighKcal,
    required this.sodiumMg,
    required this.freeSugarsG,
    required this.totalFatG,
    required this.saturatedFatG,
    required this.transFatG,
    required this.carbsPerDayG,
    required this.carbsPerMealG,
    required this.fibreG,
    this.carbsBasis = CarbBudgetBasis.energyShare,
    this.proteinG,
    this.setByProvider = const <String>{},
    this.setByUser = const <String>{},
  });
}

// =======================================================
// ONE ASSESSED NUTRIENT
// =======================================================

class NutrientAssessment {
  // Canonical name: 'Sodium', 'Total Sugars'...
  final String name;

  // Amount in the user's portion, in [unit].
  final double amount;

  final String unit;

  // Amount per 100 g / 100 ml (Layer 1 input), if known.
  final double? per100;

  // Layer 1 colour (FSA). Null for nutrients outside the
  // FSA scheme.
  final NutrientLevel? productLevel;

  // Layer 3: portion as a share of the target, 0.12 = 12 %.
  final double? share;

  final double? target;

  // "daily limit", "meal budget", "daily target".
  final String? targetLabel;

  // Final level after combining Layer 1 and Layer 3. Null
  // for nutrients shown only (protein, vitamins) and for
  // fibre, which is a benefit instead.
  final NutrientLevel? level;

  // Fibre and protein: a share above 10 % is good, not a
  // warning.
  final bool isBenefit;

  // Share bands for this nutrient: up to [lowShareMax] is
  // Low, up to [highShareMax] Moderate, above is High.
  // Daily limits use 10 % / 30 %; the carbohydrate meal
  // budget uses 25 % / 50 % (one product is part of a meal).
  final double lowShareMax;
  final double highShareMax;

  const NutrientAssessment({
    required this.name,
    required this.amount,
    required this.unit,
    this.per100,
    this.productLevel,
    this.share,
    this.target,
    this.targetLabel,
    this.level,
    this.isBenefit = false,
    this.lowShareMax = 0.10,
    this.highShareMax = 0.30,
  });

  /// The same nutrient with another final level (null on
  /// the health-area cards, which show findings only).
  NutrientAssessment withLevel(NutrientLevel? newLevel) => NutrientAssessment(
        name: name,
        amount: amount,
        unit: unit,
        per100: per100,
        productLevel: productLevel,
        share: share,
        target: target,
        targetLabel: targetLabel,
        level: newLevel,
        isBenefit: isBenefit,
        lowShareMax: lowShareMax,
        highShareMax: highShareMax,
      );

  /// The same nutrient with no level, share or target: amount
  /// and product-level traffic light only (diabetes cards).
  NutrientAssessment withoutTarget() => NutrientAssessment(
        name: name,
        amount: amount,
        unit: unit,
        per100: per100,
        productLevel: productLevel,
        isBenefit: isBenefit,
      );

  /// Layer 3 band of [share] alone, or null without a
  /// target.
  NutrientLevel? get bandLevel {
    final double? s = share;

    if (s == null) return null;
    if (s <= lowShareMax) return NutrientLevel.low;
    if (s <= highShareMax) return NutrientLevel.moderate;

    return NutrientLevel.high;
  }
}

// =======================================================
// ONE HEALTH AREA
// =======================================================

class AreaAssessment {
  final HealthArea area;

  // Null = not enough information on the label.
  final NutrientLevel? level;

  // Nutrient that decided the level ('Carbohydrate').
  final String? decidedBy;

  // Rated nutrients of this area, in rule order.
  final List<NutrientAssessment> nutrients;

  // Fibre when present (shown as a benefit).
  final NutrientAssessment? benefit;

  // Nutrients this area uses that the label does not show.
  final List<String> missing;

  // Nutrients that can decide this area, in rule order.
  final List<String> ruleNutrients;

  // At least one of these must be on the label to judge.
  final List<String> keyNutrients;

  // Shown first as amounts only, with no share of a
  // target (diabetes: carbohydrate and total sugars).
  final List<NutrientAssessment> watch;

  // True for every health-area card: they show key
  // nutrients (amount, share of the daily reference where
  // there is one, product-level traffic light) with no
  // level, so [level] is null and no area feeds an overall
  // result.
  final bool partial;

  const AreaAssessment({
    required this.area,
    required this.level,
    required this.decidedBy,
    required this.nutrients,
    required this.benefit,
    required this.missing,
    this.ruleNutrients = const <String>[],
    this.keyNutrients = const <String>[],
    this.watch = const <NutrientAssessment>[],
    this.partial = false,
  });

  bool get hasEnoughInformation => level != null;
}

// =======================================================
// NUTRITION FACTS ROW (portion + per 100)
// =======================================================

class FactRow {
  final String name;

  // e.g. "92 kcal", "1.7 g". Empty when not computable.
  final String portion;

  final String per100;

  // Indented sub-row (Saturated Fat under Total Fat).
  final bool isSubRow;

  const FactRow({
    required this.name,
    required this.portion,
    required this.per100,
    required this.isSubRow,
  });
}

// =======================================================
// NUTRIENT CATEGORY IN THE INTENDED PORTION
// (UK front-of-pack traffic-light criteria)
// =======================================================
//
// Fat, saturated fat, total sugars and salt, each put in
// a low (green), medium (amber) or high (red) category for
// the user's intended portion (Chapter 3, Equation 3.1):
//
//   N_portion = N_100 x P / 100
//
// * Food portions over 100 g and drink portions over
//   150 ml: high when N_portion is above the high-per-
//   portion threshold, otherwise the per 100 criteria.
// * Smaller portions: the per 100 criteria only, so a
//   small portion never lowers a high category.
//
// Each nutrient is classified on its own. The categories
// describe nutrient levels; they are not an overall rating
// of the product and not a personal intake limit.

enum TrafficCategory { low, medium, high }

extension TrafficCategoryText on TrafficCategory {
  String get label => switch (this) {
        TrafficCategory.low => 'Low',
        TrafficCategory.medium => 'Medium',
        TrafficCategory.high => 'High',
      };
}

/// Why a nutrient got its category.
enum TrafficBasis {
  // Standard per 100 g / per 100 ml criteria.
  per100,
  // Above the high-per-portion threshold (portion over
  // 100 g / 150 ml).
  portionThreshold,
}

class TrafficLightResult {
  // 'Fat', 'Saturated fat', 'Total sugars', 'Salt'.
  final String name;

  // Amount in the intended portion (g), or null when the
  // portion size in g / ml is not known.
  final double? portionAmount;

  // Amount per 100 g / 100 ml (g).
  final double per100;

  final TrafficCategory category;

  final TrafficBasis basis;

  // High-per-portion threshold in g for this nutrient.
  final double portionHighThreshold;

  // True for salt worked out from sodium (salt = sodium x 2.5).
  final bool saltFromSodium;

  const TrafficLightResult({
    required this.name,
    required this.portionAmount,
    required this.per100,
    required this.category,
    required this.basis,
    required this.portionHighThreshold,
    this.saltFromSodium = false,
  });
}

/// The four categories for one product and portion.
class PortionTrafficLights {
  // Nutrients on the label, in the order fat, saturated
  // fat, total sugars, salt.
  final List<TrafficLightResult> results;

  // Scheme nutrients the label does not show.
  final List<String> missing;

  // Intended portion in g / ml, or null when not known.
  final double? portionSize;

  // 'g' (food) or 'ml' (drink).
  final String unit;

  // True when the portion is over 100 g (food) or 150 ml
  // (drink), so the high-per-portion thresholds apply.
  final bool portionRuleApplies;

  const PortionTrafficLights({
    required this.results,
    required this.missing,
    required this.portionSize,
    required this.unit,
    required this.portionRuleApplies,
  });

  static const PortionTrafficLights empty = PortionTrafficLights(
    results: <TrafficLightResult>[],
    missing: <String>[],
    portionSize: null,
    unit: 'g',
    portionRuleApplies: false,
  );
}

// =======================================================
// THE WHOLE RESULT
// =======================================================

class NutritionAnalysis {
  final Portion portion;

  // Portion in g / ml when known (for display).
  final double? portionAmount;

  final String? portionUnit;

  // Portion in servings when the serving size is known.
  final double? portionServings;

  final ProductForm form;

  // 'per 100 ml' or 'per 100 g'.
  final String per100Label;

  final DailyTargets targets;

  // Every nutrient the rules know about that is on the
  // label, keyed by canonical name.
  final Map<String, NutrientAssessment> nutrients;

  final List<AreaAssessment> areas;

  // Worst level across the areas that have a level. Every
  // health area shows findings without a level, so this is
  // null.
  final NutrientLevel? overall;

  final List<FactRow> facts;

  // Low / medium / high category of fat, saturated fat,
  // total sugars and salt in the intended portion.
  final PortionTrafficLights trafficLights;

  /// True when an area shows key nutrients without a level
  /// (every card), so the summary says "review key
  /// nutrients" instead of "fits your goals".
  bool get needsDetails => areas.any((AreaAssessment a) => a.partial);

  const NutritionAnalysis({
    required this.portion,
    required this.portionAmount,
    required this.portionUnit,
    required this.portionServings,
    required this.form,
    required this.per100Label,
    required this.targets,
    required this.nutrients,
    required this.areas,
    required this.overall,
    required this.facts,
    this.trafficLights = PortionTrafficLights.empty,
  });
}
