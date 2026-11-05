class NutrientValue {
  final String name;
  final double amount;
  final String unit;

  const NutrientValue({
    required this.name,
    required this.amount,
    required this.unit,
  });

  @override
  String toString() {
    return '$name: $amount $unit';
  }
}

// =======================================================
// NUTRITION VALUES
// =======================================================

class NutritionValues {
  // =====================================================
  // CORE NUTRIPAL NUTRIENTS
  // =====================================================

  final double? energyKcal;
  final double? energyKj;

  final double? proteinG;

  final double? totalFatG;
  final double? saturatedFatG;
  final double? transFatG;

  final double? carbohydrateG;
  final double? sugarsG;

  final double? fibreG;

  final double? sodiumMg;

  final double? cholesterolMg;

  // =====================================================
  // OTHER NUTRIENTS
  //
  // Examples:
  //
  // Vitamin D
  // Calcium
  // Iron
  // Potassium
  // Vitamin C
  //
  // These are preserved even though NutriPal may not
  // currently use them for personalised interpretation.
  // =====================================================

  final Map<String, NutrientValue> otherNutrients;

  const NutritionValues({
    this.energyKcal,
    this.energyKj,
    this.proteinG,
    this.totalFatG,
    this.saturatedFatG,
    this.transFatG,
    this.carbohydrateG,
    this.sugarsG,
    this.fibreG,
    this.sodiumMg,
    this.cholesterolMg,
    this.otherNutrients =
        const {},
  });

  // =====================================================
  // HAS ANY VALUE
  // =====================================================

  bool get hasAnyValue {
    return energyKcal != null ||
        energyKj != null ||
        proteinG != null ||
        totalFatG != null ||
        saturatedFatG != null ||
        transFatG != null ||
        carbohydrateG != null ||
        sugarsG != null ||
        fibreG != null ||
        sodiumMg != null ||
        cholesterolMg != null ||
        otherNutrients.isNotEmpty;
  }

  // =====================================================
  // COPY WITH
  // =====================================================

  NutritionValues copyWith({
    double? energyKcal,
    double? energyKj,
    double? proteinG,
    double? totalFatG,
    double? saturatedFatG,
    double? transFatG,
    double? carbohydrateG,
    double? sugarsG,
    double? fibreG,
    double? sodiumMg,
    double? cholesterolMg,
    Map<String, NutrientValue>? otherNutrients,
  }) {
    return NutritionValues(
      energyKcal:
          energyKcal ??
              this.energyKcal,
      energyKj:
          energyKj ??
              this.energyKj,
      proteinG:
          proteinG ??
              this.proteinG,
      totalFatG:
          totalFatG ??
              this.totalFatG,
      saturatedFatG:
          saturatedFatG ??
              this.saturatedFatG,
      transFatG:
          transFatG ??
              this.transFatG,
      carbohydrateG:
          carbohydrateG ??
              this.carbohydrateG,
      sugarsG:
          sugarsG ??
              this.sugarsG,
      fibreG:
          fibreG ??
              this.fibreG,
      sodiumMg:
          sodiumMg ??
              this.sodiumMg,
      cholesterolMg:
          cholesterolMg ??
              this.cholesterolMg,
      otherNutrients:
          otherNutrients ??
              this.otherNutrients,
    );
  }

  @override
  String toString() {
    return '''
NutritionValues(
  energyKcal: $energyKcal,
  energyKj: $energyKj,
  proteinG: $proteinG,
  totalFatG: $totalFatG,
  saturatedFatG: $saturatedFatG,
  transFatG: $transFatG,
  carbohydrateG: $carbohydrateG,
  sugarsG: $sugarsG,
  fibreG: $fibreG,
  sodiumMg: $sodiumMg,
  cholesterolMg: $cholesterolMg,
  otherNutrients: $otherNutrients
)
''';
  }
}

// =======================================================
// MAIN NUTRITION LABEL DATA
// =======================================================

class NutritionLabelData {
  // =====================================================
  // SERVING INFORMATION
  // =====================================================

  final double? servingSizeAmount;

  // g / ml
  final String? servingSizeUnit;

  final double? servingsPerPackage;

  // =====================================================
  // PHYSICAL SERVING RELATION
  //
  // Examples:
  //
  // 1 tablet
  // 0.5 bottle
  // 15 chips
  // =====================================================

  final double? servingUnitAmount;

  final String? servingUnitName;

  // =====================================================
  // NUTRITION COLUMNS
  // =====================================================

  final NutritionValues? perServing;

  final NutritionValues? per100;

  // g = per 100 g
  // ml = per 100 ml
  final String? per100Unit;

  // =====================================================
  // ORIGINAL OCR TEXT
  // =====================================================

  final String rawText;

  const NutritionLabelData({
    this.servingSizeAmount,
    this.servingSizeUnit,
    this.servingsPerPackage,
    this.servingUnitAmount,
    this.servingUnitName,
    this.perServing,
    this.per100,
    this.per100Unit,
    required this.rawText,
  });

  bool get hasServingSize {
    return servingSizeAmount != null &&
        servingSizeUnit != null;
  }

  bool get hasPerServingValues {
    return perServing != null &&
        perServing!.hasAnyValue;
  }

  bool get hasPer100Values {
    return per100 != null &&
        per100!.hasAnyValue;
  }

  // =====================================================
  // CAN CALCULATE PORTION
  // =====================================================

  bool get canCalculatePortion {
    if (hasPerServingValues) {
      return true;
    }

    if (hasPer100Values &&
        hasServingSize) {
      return true;
    }

    return false;
  }

  // =====================================================
  // CAN CALCULATE PHYSICAL UNIT
  // =====================================================

  bool get hasServingUnitRelationship {
    return servingUnitAmount != null &&
        servingUnitName != null &&
        servingSizeAmount != null;
  }

  @override
  String toString() {
    return '''
NutritionLabelData(
  servingSizeAmount: $servingSizeAmount,
  servingSizeUnit: $servingSizeUnit,
  servingsPerPackage: $servingsPerPackage,
  servingUnitAmount: $servingUnitAmount,
  servingUnitName: $servingUnitName,
  per100Unit: $per100Unit,
  perServing: $perServing,
  per100: $per100,
  canCalculatePortion: $canCalculatePortion
)
''';
  }
}