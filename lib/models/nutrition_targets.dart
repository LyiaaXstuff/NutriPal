// =======================================================
// NUTRITION TARGETS (Profile > Nutrition Targets)
// =======================================================
//
// Optional targets the user enters themselves, usually
// from their doctor or dietitian. Each one replaces
// NutriPal's default for that nutrient in the analysis
// (Layer 2). Empty fields keep the default.
//
// Saved in users/{uid}.profile.nutritionTargets. Older
// profiles kept sodium and carbohydrate under
// providerLimits; fromJson still reads those.
//
// Energy is not here: it is set on the Weight Management
// Goal screen (providerLimits.energyKcal).
// =======================================================

import 'nutrition_analysis.dart' show HealthArea;

/// One field on the Nutrition Targets screen.
class NutritionTargetField {
  /// Key in [NutritionTargets.toJson].
  final String key;

  /// "Carbohydrate goal".
  final String label;

  /// 'g' or 'mg'.
  final String unit;

  /// "per meal" or "a day".
  final String basis;

  /// Canonical nutrient name in the analysis.
  final String nutrient;

  /// Accepted range (inclusive).
  final double min;
  final double max;

  /// Health areas this field helps; empty = always shown.
  final Set<HealthArea> areas;

  /// One line under the field.
  final String help;

  const NutritionTargetField({
    required this.key,
    required this.label,
    required this.unit,
    required this.basis,
    required this.nutrient,
    required this.min,
    required this.max,
    this.areas = const <HealthArea>{},
    required this.help,
  });

  bool get isMain => areas.isEmpty;
}

class NutritionTargets {
  double? carbsPerMealG;
  double? proteinG;
  double? fatG;
  double? sugarsG;
  double? sodiumMg;
  double? saturatedFatG;
  double? fibreG;

  NutritionTargets({
    this.carbsPerMealG,
    this.proteinG,
    this.fatG,
    this.sugarsG,
    this.sodiumMg,
    this.saturatedFatG,
    this.fibreG,
  });

  // =====================================================
  // FIELDS (screen order)
  // =====================================================

  static const List<NutritionTargetField> fields = <NutritionTargetField>[
    NutritionTargetField(
      key: 'carbsPerMealG',
      label: 'Carbohydrate goal',
      unit: 'g',
      basis: 'per meal',
      nutrient: 'Carbohydrate',
      min: 10,
      max: 150,
      help: 'Carbohydrate for one main meal. 1 carb exchange = 15 g.',
    ),
    NutritionTargetField(
      key: 'proteinG',
      label: 'Protein goal',
      unit: 'g',
      basis: 'a day',
      nutrient: 'Protein',
      min: 10,
      max: 250,
      help: 'Shown as how much of your goal a portion gives.',
    ),
    NutritionTargetField(
      key: 'fatG',
      label: 'Fat goal',
      unit: 'g',
      basis: 'a day',
      nutrient: 'Total Fat',
      min: 10,
      max: 200,
      help: 'The most total fat you aim for in a day.',
    ),
    NutritionTargetField(
      key: 'sugarsG',
      label: 'Sugar limit',
      unit: 'g',
      basis: 'a day',
      nutrient: 'Total Sugars',
      min: 5,
      max: 100,
      areas: <HealthArea>{HealthArea.diabetes, HealthArea.weight},
      help: 'Helps with blood sugar and weight.',
    ),
    NutritionTargetField(
      key: 'sodiumMg',
      label: 'Sodium limit',
      unit: 'mg',
      basis: 'a day',
      nutrient: 'Sodium',
      min: 500,
      max: 4000,
      areas: <HealthArea>{HealthArea.bloodPressure},
      help: 'Helps with blood pressure. 1 teaspoon of salt has about 2,000 mg.',
    ),
    NutritionTargetField(
      key: 'saturatedFatG',
      label: 'Saturated fat limit',
      unit: 'g',
      basis: 'a day',
      nutrient: 'Saturated Fat',
      min: 5,
      max: 50,
      areas: <HealthArea>{HealthArea.cholesterol},
      help: 'Helps with LDL cholesterol.',
    ),
    NutritionTargetField(
      key: 'fibreG',
      label: 'Fibre goal',
      unit: 'g',
      basis: 'a day',
      nutrient: 'Dietary Fibre',
      min: 10,
      max: 60,
      areas: <HealthArea>{HealthArea.diabetes, HealthArea.cholesterol, HealthArea.weight},
      help: 'Helps with blood sugar, cholesterol and feeling full.',
    ),
  ];

  static NutritionTargetField field(String key) =>
      fields.firstWhere((NutritionTargetField f) => f.key == key);

  // =====================================================
  // VALUES
  // =====================================================

  double? valueOf(String key) => switch (key) {
        'carbsPerMealG' => carbsPerMealG,
        'proteinG' => proteinG,
        'fatG' => fatG,
        'sugarsG' => sugarsG,
        'sodiumMg' => sodiumMg,
        'saturatedFatG' => saturatedFatG,
        'fibreG' => fibreG,
        _ => null,
      };

  void setValue(String key, double? value) {
    switch (key) {
      case 'carbsPerMealG':
        carbsPerMealG = value;
      case 'proteinG':
        proteinG = value;
      case 'fatG':
        fatG = value;
      case 'sugarsG':
        sugarsG = value;
      case 'sodiumMg':
        sodiumMg = value;
      case 'saturatedFatG':
        saturatedFatG = value;
      case 'fibreG':
        fibreG = value;
    }
  }

  /// Target for a canonical nutrient name, if set.
  double? forNutrient(String nutrient) {
    for (final NutritionTargetField f in fields) {
      if (f.nutrient == nutrient) return valueOf(f.key);
    }

    return null;
  }

  bool get isEmpty => fields.every((NutritionTargetField f) => valueOf(f.key) == null);

  int get count => fields.where((NutritionTargetField f) => valueOf(f.key) != null).length;

  /// The number when it is inside the field's range,
  /// otherwise null (ignored).
  static double? valid(NutritionTargetField f, double? value) {
    if (value == null || value.isNaN) return null;
    if (value < f.min || value > f.max) return null;

    return value;
  }

  /// Parses "45", "45 g", "1,500"; null when empty or not a
  /// number.
  static double? parse(String text) {
    final String t = text.replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '');

    if (t.isEmpty) return null;

    return double.tryParse(t);
  }

  NutritionTargets copy() => NutritionTargets.fromJson(toJson());

  @override
  bool operator ==(Object other) =>
      other is NutritionTargets &&
      fields.every((NutritionTargetField f) => valueOf(f.key) == other.valueOf(f.key));

  @override
  int get hashCode => Object.hashAll(fields.map((NutritionTargetField f) => valueOf(f.key)));

  // =====================================================
  // SAVE / LOAD
  // =====================================================

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final NutritionTargetField f in fields) f.key: valueOf(f.key),
      };

  /// [legacy] is the old providerLimits map (sodiumMg,
  /// carbsPerMealG), used when the new map has no value.
  static NutritionTargets fromJson(
    Map<String, dynamic>? json, {
    Map<String, dynamic>? legacy,
  }) {
    final NutritionTargets t = NutritionTargets();

    for (final NutritionTargetField f in fields) {
      final Object? v = json?[f.key] ?? legacy?[f.key];

      t.setValue(f.key, valid(f, v is num ? v.toDouble() : null));
    }

    return t;
  }
}
