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

enum HealthArea { diabetes, bloodPressure, cholesterol, weight }

extension HealthAreaText on HealthArea {
  String get title => switch (this) {
        HealthArea.diabetes => 'Diabetes',
        HealthArea.bloodPressure => 'Blood pressure',
        HealthArea.cholesterol => 'Cholesterol',
        HealthArea.weight => 'Weight',
      };

  String get focus => switch (this) {
        HealthArea.diabetes => 'Carbohydrate and sugar',
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
  final double energyKcal;

  // False when the profile lacks age, sex, weight, height
  // or activity and the 2,000 kcal reference was used.
  final bool energyIsPersonal;

  final double sodiumMg;

  final double freeSugarsG;

  final double totalFatG;

  final double saturatedFatG;

  final double transFatG;

  final double carbsPerDayG;

  final double carbsPerMealG;

  final double fibreG;

  // Targets that came from the user's doctor or dietitian.
  final Set<String> setByProvider;

  const DailyTargets({
    required this.energyKcal,
    required this.energyIsPersonal,
    required this.sodiumMg,
    required this.freeSugarsG,
    required this.totalFatG,
    required this.saturatedFatG,
    required this.transFatG,
    required this.carbsPerDayG,
    required this.carbsPerMealG,
    required this.fibreG,
    this.setByProvider = const <String>{},
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

  // Fibre: a share above 10 % is good, not a warning.
  final bool isBenefit;

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
  });
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

  const AreaAssessment({
    required this.area,
    required this.level,
    required this.decidedBy,
    required this.nutrients,
    required this.benefit,
    required this.missing,
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

  // Worst level across the areas shown; null if none of
  // them had enough information.
  final NutrientLevel? overall;

  final List<FactRow> facts;

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
  });
}
