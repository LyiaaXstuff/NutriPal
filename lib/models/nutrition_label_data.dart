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
    this.otherNutrients = const {},
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
      energyKcal: energyKcal ?? this.energyKcal,
      energyKj: energyKj ?? this.energyKj,
      proteinG: proteinG ?? this.proteinG,
      totalFatG: totalFatG ?? this.totalFatG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      transFatG: transFatG ?? this.transFatG,
      carbohydrateG: carbohydrateG ?? this.carbohydrateG,
      sugarsG: sugarsG ?? this.sugarsG,
      fibreG: fibreG ?? this.fibreG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      cholesterolMg: cholesterolMg ?? this.cholesterolMg,
      otherNutrients: otherNutrients ?? this.otherNutrients,
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

  /// The photographed table, in reading order. This is the source of truth;
  /// the legacy perServing/per100 fields are only projections for calculations.
  final List<NutritionColumn> columns;
  final List<NutritionRow> rows;
  final List<String> extractionWarnings;
  final String extractionMethod;

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
    this.columns = const [],
    this.rows = const [],
    this.extractionWarnings = const [],
    this.extractionMethod = 'On-device text recognition',
  });

  bool get hasServingSize {
    return servingSizeAmount != null && servingSizeUnit != null;
  }

  bool get hasPerServingValues {
    return perServing != null && perServing!.hasAnyValue;
  }

  bool get hasPer100Values {
    return per100 != null && per100!.hasAnyValue;
  }

  // =====================================================
  // CAN CALCULATE PORTION
  // =====================================================

  bool get canCalculatePortion {
    if (hasPerServingValues) {
      return true;
    }

    if (hasPer100Values && hasServingSize && per100Unit == servingSizeUnit) {
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

enum NutritionColumnBasis { perServing, per100g, per100ml, dailyValue, unknown }

class NutritionColumn {
  final String id;
  final String label;
  final NutritionColumnBasis basis;

  const NutritionColumn({
    required this.id,
    required this.label,
    required this.basis,
  });
}

/// A quantity as printed, including inequalities and its original precision.
/// Empty units are retained for review, never silently assumed to be grams.
class NutritionQuantity {
  final double amount;
  final String numberText;
  final String unit;
  final String comparator;
  final String rawText;

  const NutritionQuantity({
    required this.amount,
    required this.numberText,
    required this.unit,
    this.comparator = '',
    required this.rawText,
  });

  String get displayText =>
      '$comparator$numberText${unit.isEmpty ? '' : ' $unit'}';
}

class NutritionCell {
  /// A cell can contain both kJ and kcal. Neither overwrites the other.
  final List<NutritionQuantity> quantities;
  final bool needsReview;
  final String rawText;

  const NutritionCell({
    this.quantities = const [],
    this.needsReview = false,
    this.rawText = '',
  });

  String get displayText => quantities.isEmpty
      ? (rawText.isEmpty ? 'Not read' : rawText)
      : quantities.map((q) => q.displayText).join(' / ');
}

class NutritionRow {
  final String id;
  final String name;
  final Map<String, NutritionCell> cells;
  final String sourceText;
  final bool needsReview;

  const NutritionRow({
    required this.id,
    required this.name,
    required this.cells,
    required this.sourceText,
    this.needsReview = false,
  });
}
