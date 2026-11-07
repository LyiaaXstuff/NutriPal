// =======================================================
// NUTRITION COLUMN BASIS
// =======================================================

enum NutritionColumnBasis {
  perServing,
  per100g,
  per100ml,
  unknown,
}

// =======================================================
// NUTRIENT NAME FORMAT
// =======================================================
//
// "JUMLAH GULA"                -> "Jumlah gula"
// "Jumlah Gula / Total Sugars" -> "Jumlah gula / Total sugars"
// "VITAMIN B12"                -> "Vitamin B12"
// "omega-3"                    -> "Omega-3"
//
// Only the first letter (of each language, when the name
// is bilingual) is a capital. Short codes with digits such
// as B12 or D3 keep their capitals.
// =======================================================

String formatNutrientName(String name) {
  final List<String> segments = name
      .split(RegExp(r'\s*/\s*'))
      .map((String segment) => segment.trim())
      .where((String segment) => segment.isNotEmpty)
      .toList();

  final List<String> formatted = <String>[];

  for (final String segment in segments) {
    final List<String> words = segment
        .split(RegExp(r'\s+'))
        .map((String word) {
          final bool code =
              word.length <= 4 && RegExp(r'\d').hasMatch(word);

          return code ? word.toUpperCase() : word.toLowerCase();
        })
        .toList();

    // "Vitamin a" -> "Vitamin A": a vitamin letter is a code.
    for (int i = 1; i < words.length; i++) {
      if (RegExp(r'^\(?vit(?:amin)?\.?$').hasMatch(words[i - 1]) &&
          RegExp(r'^[a-z]\)?[.,:]?$').hasMatch(words[i])) {
        words[i] = words[i].toUpperCase();
      }
    }

    String text = words.join(' ');

    final int firstLetter = text.indexOf(RegExp(r'[a-z]'));

    if (firstLetter >= 0) {
      text = text.substring(0, firstLetter) +
          text[firstLetter].toUpperCase() +
          text.substring(firstLetter + 1);
    }

    formatted.add(text);
  }

  return formatted.join(' / ');
}

// =======================================================
// HOW THE TABLE WAS READ
// =======================================================

enum NutritionExtractionMethod {
  // On-device ML Kit OCR + NutriPal table parser.
  onDevice,

  // Claude vision via the extractNutritionLabel Cloud
  // Function, cross-checked against on-device OCR.
  ai,

  // Product barcode looked up in the Open Food Facts
  // database (no label photo).
  barcode,
}

// =======================================================
// ONE NUTRITION VALUE
// =======================================================
//
// Examples:
//
// 13.7 g
// 69 mg
// 55 kcal
// 230 kJ
//
// =======================================================

class NutritionValue {
  final double amount;

  final String unit;

  // Original OCR value.
  //
  // Useful for debugging later.
  final String rawText;

  const NutritionValue({
    required this.amount,
    required this.unit,
    required this.rawText,
  });
}

// =======================================================
// NUTRITION TABLE COLUMN
// =======================================================
//
// Examples:
//
// Per serving
// Per 100 g
// Per 100 ml
//
// =======================================================

class NutritionColumn {
  final String id;

  final String label;

  final NutritionColumnBasis basis;

  // Horizontal centre of the column in the source image.
  final double xCenter;

  const NutritionColumn({
    required this.id,
    required this.label,
    required this.basis,
    required this.xCenter,
  });
}

// =======================================================
// DYNAMIC NUTRIENT ROW
// =======================================================
//
// NutriPal does NOT depend on a fixed nutrient list.
//
// Examples:
//
// Energy
// Protein
// Total Fat
// Vitamin D
// Potassium
// Calcium
// Iron
// Omega-3
//
// Any readable nutrient can be preserved.
//
// =======================================================

class NutrientRow {
  // Canonical English name from NutrientNameNormalizer
  // ("Sodium", "Total Sugars"), or the cleaned label name
  // when the nutrient is not in its dictionary. Health
  // rules should look nutrients up by this name.
  final String name;

  // The label's own wording, cleaned of OCR artefacts
  // ("Natrium", "Jumlah gula / Total sugars"). Null when
  // not available; use [labelName].
  final String? rawName;

  // Original top-to-bottom row order.
  final int order;

  // One entry for each NutritionColumn.
  //
  // A cell contains a List because some nutrients,
  // especially Energy, may contain:
  //
  // 230 kJ
  // 55 kcal
  //
  // in the same table cell.
  final List<List<NutritionValue>> valuesByColumn;

  const NutrientRow({
    required this.name,
    required this.order,
    required this.valuesByColumn,
    this.rawName,
  });

  // Wording printed on the label (falls back to [name]).
  String get labelName => rawName ?? name;

  // True when the label's wording differs from the
  // canonical name, e.g. "Natrium" vs "Sodium".
  bool get hasDifferentLabelName =>
      rawName != null &&
      rawName!.trim().toLowerCase() != name.trim().toLowerCase();

  bool get hasAnyValue {
    for (final List<NutritionValue> values
        in valuesByColumn) {
      if (values.isNotEmpty) {
        return true;
      }
    }

    return false;
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

  // Usually:
  //
  // g
  // ml
  final String? servingSizeUnit;

  // Examples:
  //
  // 2
  // 5
  // 30
  final double? servingsPerPackage;

  // =====================================================
  // PHYSICAL SERVING
  // =====================================================
  //
  // Examples:
  //
  // 1 tablet
  // 0.5 bottle
  // 15 chips
  //
  // =====================================================

  final double? servingUnitAmount;

  final String? servingUnitName;

  // =====================================================
  // TABLE
  // =====================================================

  final List<NutritionColumn> columns;

  final List<NutrientRow> nutrients;

  // =====================================================
  // RAW OCR TEXT
  // =====================================================

  final String rawText;

  // =====================================================
  // HOW IT WAS READ
  // =====================================================

  final NutritionExtractionMethod extractionMethod;

  // Corrections and checks made while reading, e.g.
  // "0.59 read as 0.5 g" or "Vitamin B12 per serving
  // could not be confirmed by on-device OCR".
  final List<String> notes;

  // Rows whose name had a second language the phone could
  // not read (Arabic, Thai...), e.g. "Protein / 3".
  final int unreadableScriptRows;

  // Enough such rows to say the label uses a script that
  // on-device OCR cannot read.
  bool get hasUnreadableScript => unreadableScriptRows >= 2;

  // =====================================================
  // PRODUCT (barcode lookups; null for label photos)
  // =====================================================

  final String? productName;

  final String? productBrand;

  final String? barcode;

  const NutritionLabelData({
    this.servingSizeAmount,
    this.servingSizeUnit,
    this.servingsPerPackage,
    this.servingUnitAmount,
    this.servingUnitName,
    this.columns = const [],
    this.nutrients = const [],
    required this.rawText,
    this.extractionMethod = NutritionExtractionMethod.onDevice,
    this.notes = const [],
    this.unreadableScriptRows = 0,
    this.productName,
    this.productBrand,
    this.barcode,
  });

  // =====================================================
  // COPY
  // =====================================================

  NutritionLabelData copyWith({
    double? servingSizeAmount,
    String? servingSizeUnit,
    double? servingsPerPackage,
    double? servingUnitAmount,
    String? servingUnitName,
    List<NutritionColumn>? columns,
    List<NutrientRow>? nutrients,
    String? rawText,
    NutritionExtractionMethod? extractionMethod,
    List<String>? notes,
    int? unreadableScriptRows,
    String? productName,
    String? productBrand,
    String? barcode,
  }) {
    return NutritionLabelData(
      servingSizeAmount: servingSizeAmount ?? this.servingSizeAmount,
      servingSizeUnit: servingSizeUnit ?? this.servingSizeUnit,
      servingsPerPackage: servingsPerPackage ?? this.servingsPerPackage,
      servingUnitAmount: servingUnitAmount ?? this.servingUnitAmount,
      servingUnitName: servingUnitName ?? this.servingUnitName,
      columns: columns ?? this.columns,
      nutrients: nutrients ?? this.nutrients,
      rawText: rawText ?? this.rawText,
      extractionMethod: extractionMethod ?? this.extractionMethod,
      notes: notes ?? this.notes,
      unreadableScriptRows: unreadableScriptRows ?? this.unreadableScriptRows,
      productName: productName ?? this.productName,
      productBrand: productBrand ?? this.productBrand,
      barcode: barcode ?? this.barcode,
    );
  }

  // =====================================================
  // SERVING SIZE AVAILABLE?
  // =====================================================

  bool get hasServingSize {
    return servingSizeAmount != null &&
        servingSizeUnit != null;
  }

  // =====================================================
  // ANY NUTRIENTS?
  // =====================================================

  bool get hasNutrients {
    return nutrients.any(
      (
        NutrientRow nutrient,
      ) =>
          nutrient.hasAnyValue,
    );
  }

  // =====================================================
  // COLUMN CHECKS
  // =====================================================

  bool get hasPerServingColumn {
    return columns.any(
      (
        NutritionColumn column,
      ) =>
          column.basis ==
          NutritionColumnBasis.perServing,
    );
  }

  bool get hasPer100gColumn {
    return columns.any(
      (
        NutritionColumn column,
      ) =>
          column.basis ==
          NutritionColumnBasis.per100g,
    );
  }

  bool get hasPer100mlColumn {
    return columns.any(
      (
        NutritionColumn column,
      ) =>
          column.basis ==
          NutritionColumnBasis.per100ml,
    );
  }

  // =====================================================
  // CAN CALCULATE PORTION?
  // =====================================================

  bool get canCalculatePortion {
    if (!hasNutrients) {
      return false;
    }

    // Best case:
    //
    // Label already provides values per serving.
    if (hasPerServingColumn) {
      return true;
    }

    if (!hasServingSize) {
      return false;
    }

    // Per 100 g requires a serving size in grams.
    if (hasPer100gColumn &&
        servingSizeUnit?.toLowerCase() ==
            'g') {
      return true;
    }

    // Per 100 ml requires a serving size in ml.
    if (hasPer100mlColumn &&
        servingSizeUnit?.toLowerCase() ==
            'ml') {
      return true;
    }

    return false;
  }

  // =====================================================
  // FIND COLUMN INDEX
  // =====================================================

  int columnIndexFor(
    NutritionColumnBasis basis,
  ) {
    return columns.indexWhere(
      (
        NutritionColumn column,
      ) =>
          column.basis ==
          basis,
    );
  }
}