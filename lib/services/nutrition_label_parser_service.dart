import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/nutrition_label_data.dart';

// =======================================================
// COLUMN TYPE
// =======================================================

enum _NutritionColumnType {
  perServing,
  per100,
}

// =======================================================
// OCR TOKEN
// =======================================================

class _OcrToken {
  final String text;

  final double left;
  final double right;
  final double top;
  final double bottom;

  const _OcrToken({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  double get centerX => (left + right) / 2;

  double get centerY => (top + bottom) / 2;

  double get height => bottom - top;
}

// =======================================================
// OCR ROW
// =======================================================

class _OcrRow {
  final List<_OcrToken> tokens;

  _OcrRow({
    required this.tokens,
  });

  List<_OcrToken> get sortedTokens {
    final List<_OcrToken> result =
        List<_OcrToken>.from(
      tokens,
    )
          ..sort(
            (
              _OcrToken a,
              _OcrToken b,
            ) {
              return a.left.compareTo(
                b.left,
              );
            },
          );

    return result;
  }

  double get centerY {
    if (tokens.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final _OcrToken token
        in tokens) {
      total += token.centerY;
    }

    return total /
        tokens.length;
  }

  String get text {
    return sortedTokens
        .map(
          (
            _OcrToken token,
          ) =>
              token.text,
        )
        .join(' ')
        .trim();
  }
}

// =======================================================
// POSITIONED NUTRITION VALUE
// =======================================================

class _PositionedNutritionValue {
  final double amount;

  final String unit;

  final double x;

  const _PositionedNutritionValue({
    required this.amount,
    required this.unit,
    required this.x,
  });
}

// =======================================================
// SERVING SIZE
// =======================================================

class _ServingSizeResult {
  final double amount;

  final String unit;

  const _ServingSizeResult({
    required this.amount,
    required this.unit,
  });
}

// =======================================================
// SERVING UNIT
// =======================================================

class _ServingUnitResult {
  final double amount;

  final String name;

  const _ServingUnitResult({
    required this.amount,
    required this.name,
  });
}

// =======================================================
// PACKAGE RELATION
// =======================================================

class _PackageRelation {
  final double amountPerUnit;

  final String measurementUnit;

  final String itemName;

  const _PackageRelation({
    required this.amountPerUnit,
    required this.measurementUnit,
    required this.itemName,
  });
}

// =======================================================
// COLUMN LAYOUT
// =======================================================

class _ColumnLayout {
  final double? perServingX;

  final double? per100X;

  final String? per100Unit;

  const _ColumnLayout({
    this.perServingX,
    this.per100X,
    this.per100Unit,
  });

  bool get hasPerServing =>
      perServingX != null;

  bool get hasPer100 =>
      per100X != null;
}

// =======================================================
// NUTRITION VALUES BUILDER
// =======================================================

class _NutritionValuesBuilder {
  double? energyKcal;
  double? energyKj;

  double? proteinG;

  double? totalFatG;
  double? saturatedFatG;
  double? transFatG;

  double? carbohydrateG;
  double? sugarsG;

  double? fibreG;

  double? sodiumMg;

  double? cholesterolMg;

  final Map<String, NutrientValue>
      otherNutrients = {};

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

  NutritionValues build() {
    return NutritionValues(
      energyKcal:
          energyKcal,
      energyKj:
          energyKj,
      proteinG:
          proteinG,
      totalFatG:
          totalFatG,
      saturatedFatG:
          saturatedFatG,
      transFatG:
          transFatG,
      carbohydrateG:
          carbohydrateG,
      sugarsG:
          sugarsG,
      fibreG:
          fibreG,
      sodiumMg:
          sodiumMg,
      cholesterolMg:
          cholesterolMg,
      otherNutrients:
          Map.unmodifiable(
        otherNutrients,
      ),
    );
  }
}

// =======================================================
// NUTRITION LABEL PARSER SERVICE
// =======================================================

class NutritionLabelParserService {
  // =====================================================
  // KNOWN / CORE NUTRIENTS
  // =====================================================

  static const Map<String, List<String>>
      _nutrientKeywords = {
    'energy': [
      'energy',
      'tenaga',
      'calorie',
      'calories',
    ],

    'protein': [
      'protein',
    ],

    'saturatedFat': [
      'saturated fat',
      'saturated fatty acid',
      'saturates',
      'lemak tepu',
    ],

    'transFat': [
      'trans fat',
      'trans-fat',
      'lemak trans',
    ],

    'carbohydrate': [
      'total carbohydrate',
      'carbohydrate',
      'carbohydrates',
      'karbohidrat',
      'carbs',
    ],

    'sugars': [
      'total sugars',
      'total sugar',
      'jumlah gula',
      'sugars',
      'sugar',
      'gula',
    ],

    'fibre': [
      'dietary fibre',
      'dietary fiber',
      'fibre',
      'fiber',
      'serat',
      'serabut',
    ],

    'sodium': [
      'sodium',
      'natrium',
    ],

    'cholesterol': [
      'cholesterol',
      'kolesterol',
    ],

    'totalFat': [
      'total fat',
      'fat, total',
      'jumlah lemak',
      'lemak',
      'fat',
    ],
  };

  // =====================================================
  // ADDITIONAL NUTRIENT HINTS
  // =====================================================

  static const List<String> _otherNutrientHints = [
    'vitamin',
    'calcium',
    'iron',
    'potassium',
    'magnesium',
    'phosphorus',
    'zinc',
    'copper',
    'manganese',
    'selenium',
    'iodine',
    'folate',
    'folic acid',
    'niacin',
    'thiamin',
    'thiamine',
    'riboflavin',
    'biotin',
    'choline',
    'chloride',
    'chromium',
    'molybdenum',
    'omega',
    'dha',
    'epa',
  ];

  // =====================================================
  // PER SERVING HEADERS
  // =====================================================

  static const List<String> _perServingKeywords = [
    'per serving',
    'per serve',
    'per portion',
    'setiap hidangan',
  ];

  // =====================================================
  // PER 100G / 100ML HEADERS
  // =====================================================

  static const List<String> _per100Keywords = [
    'per 100g',
    'per 100 g',
    'per 100ml',
    'per 100 ml',
    'setiap 100g',
    'setiap 100 g',
    'setiap 100ml',
    'setiap 100 ml',
  ];

  // =====================================================
  // NUTRITION VALUE
  // =====================================================

  static final RegExp _valuePattern =
      RegExp(
    r'(?:<|≤)?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(kcal|kj|mcg|µg|ug|mg|g)\b',
    caseSensitive:
        false,
  );

  // =====================================================
  // NUMBER ONLY
  // =====================================================

  static final RegExp _numberOnlyPattern =
      RegExp(
    r'^(?:<|≤)?\s*'
    r'(\d+(?:[.,]\d+)?)$',
    caseSensitive:
        false,
  );

  // =====================================================
  // UNIT ONLY
  // =====================================================

  static final RegExp _unitOnlyPattern =
      RegExp(
    r'^(kcal|kj|mcg|µg|ug|mg|g)$',
    caseSensitive:
        false,
  );

  // =====================================================
  // EXPLICIT SERVING SIZE
  // =====================================================

  static final RegExp _explicitServingSizePattern =
      RegExp(
    r'(?:serving\s*size|saiz\s*hidangan)'
    r'\s*[:\-]?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)\b',
    caseSensitive:
        false,
  );

  // =====================================================
  // SERVING SIZE FROM HEADER
  // =====================================================

  static final RegExp _servingHeaderPattern =
      RegExp(
    r'(?:per\s*serving|per\s*serve|setiap\s*hidangan)'
    r'\s*'
    r'[\(\[]?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)'
    r'\s*[\)\]]?',
    caseSensitive:
        false,
  );

  // =====================================================
  // SERVINGS PER PACKAGE
  // =====================================================

  static final RegExp _servingsPerPackagePattern =
      RegExp(
    r'(?:'
    r'servings?\s*per\s*'
    r'(?:package|pack|container|bottle)'
    r'|'
    r'hidangan\s*setiap\s*'
    r'(?:bungkusan|pek)'
    r')'
    r'\s*[:\-]?\s*'
    r'(\d+(?:[.,]\d+)?)',
    caseSensitive:
        false,
  );

  // =====================================================
  // FRACTION SERVING
  // =====================================================

  static final RegExp _fractionServingPattern =
      RegExp(
    r'(\d+(?:[.,]\d+)?)'
    r'\s*/\s*'
    r'(\d+(?:[.,]\d+)?)'
    r'\s*'
    r'(bottle|bottles|pack|packs|piece|pieces|'
    r'tablet|tablets|capsule|capsules|sachet|sachets|'
    r'cup|cups)',
    caseSensitive:
        false,
  );

  // =====================================================
  // COUNT SERVING
  // =====================================================

  static final RegExp _countServingPattern =
      RegExp(
    r'(?:about\s*)?'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(chip|chips|biscuit|biscuits|cracker|crackers|'
    r'tablet|tablets|capsule|capsules|piece|pieces|'
    r'sachet|sachets|bottle|bottles|cup|cups)',
    caseSensitive:
        false,
  );

  // =====================================================
  // PACKAGE RELATION
  // =====================================================

  static final RegExp _packageRelationPattern =
      RegExp(
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)'
    r'\s*[x×]\s*'
    r'\d+(?:[.,]\d+)?\s*'
    r'(tablet|tablets|capsule|capsules|piece|pieces|'
    r'sachet|sachets)',
    caseSensitive:
        false,
  );

  // =====================================================
  // PUBLIC PARSE METHOD
  // =====================================================

  static Future<NutritionLabelData> parseImage(
    String imagePath,
  ) async {
    final File file =
        File(
      imagePath,
    );

    if (!await file.exists()) {
      throw Exception(
        'Nutrition label image could not be found.',
      );
    }

    final TextRecognizer recognizer =
        TextRecognizer(
      script:
          TextRecognitionScript.latin,
    );

    try {
      // =================================================
      // RUN OCR
      // =================================================

      final InputImage inputImage =
          InputImage.fromFilePath(
        imagePath,
      );

      final RecognizedText result =
          await recognizer.processImage(
        inputImage,
      );

      final String rawText =
          result.text.trim();

      if (rawText.isEmpty) {
        return const NutritionLabelData(
          rawText:
              '',
        );
      }

      // =================================================
      // GET OCR ELEMENTS
      // =================================================

      final List<_OcrToken> tokens =
          [];

      for (final TextBlock block
          in result.blocks) {
        for (final TextLine line
            in block.lines) {
          for (final TextElement element
              in line.elements) {
            final String text =
                element.text.trim();

            if (text.isEmpty) {
              continue;
            }

            // IMPORTANT:
            // Do not explicitly declare Rect here.
            // Dart infers the boundingBox type.
            final rect =
                element.boundingBox;

            tokens.add(
              _OcrToken(
                text:
                    text,
                left:
                    rect.left,
                right:
                    rect.right,
                top:
                    rect.top,
                bottom:
                    rect.bottom,
              ),
            );
          }
        }
      }

      // =================================================
      // RECONSTRUCT TABLE ROWS
      // =================================================

      final List<_OcrRow> rows =
          _buildRows(
        tokens,
      );

      final String allText =
          _normalise(
        rawText,
      );

      // =================================================
      // SERVING INFORMATION
      // =================================================

      final _ServingSizeResult?
          servingSize =
          _findServingSize(
        allText,
        rows,
      );

      final double? servingsPerPackage =
          _findServingsPerPackage(
        allText,
      );

      _ServingUnitResult?
          servingUnit =
          _findPhysicalServingUnit(
        rows,
      );

      final _PackageRelation?
          packageRelation =
          _findPackageRelation(
        allText,
      );

      // =================================================
      // PACKAGE RELATION
      // =================================================

      if (servingUnit == null &&
          servingSize != null &&
          packageRelation != null) {
        final bool sameUnit =
            servingSize.unit ==
                packageRelation
                    .measurementUnit;

        final bool sameAmount =
            (
              servingSize.amount -
                  packageRelation
                      .amountPerUnit
            ).abs() <
                0.001;

        if (sameUnit &&
            sameAmount) {
          servingUnit =
              _ServingUnitResult(
            amount:
                1,
            name:
                packageRelation
                    .itemName,
          );
        }
      }

      // =================================================
      // DETECT COLUMN LOCATIONS
      // =================================================

      final _ColumnLayout layout =
          _detectColumnLayout(
        rows,
      );

      // =================================================
      // BUILDERS
      // =================================================

      final _NutritionValuesBuilder
          perServingBuilder =
          _NutritionValuesBuilder();

      final _NutritionValuesBuilder
          per100Builder =
          _NutritionValuesBuilder();

      // =================================================
      // PARSE NUTRIENT ROWS
      // =================================================

      for (final _OcrRow row
          in rows) {
        final String rowText =
            _normalise(
          row.text,
        );

        // =================================================
        // REMOVE HEADERS / NON-NUTRIENT ROWS
        // =================================================

        if (_isNonNutrientRow(
          rowText,
        )) {
          continue;
        }

        // =================================================
        // VALUES + X POSITIONS
        // =================================================

        final List<_PositionedNutritionValue>
            values =
            _extractPositionedValues(
          row,
        );

        if (values.isEmpty) {
          continue;
        }

        // =================================================
        // CORE NUTRIENT
        // =================================================

        final String? knownNutrient =
            _identifyKnownNutrient(
          rowText,
        );

        if (knownNutrient !=
            null) {
          _assignKnownNutrient(
            nutrient:
                knownNutrient,
            values:
                values,
            layout:
                layout,
            perServing:
                perServingBuilder,
            per100:
                per100Builder,
          );

          continue;
        }

        // =================================================
        // OTHER NUTRIENT
        // =================================================

        final String? otherName =
            _extractOtherNutrientName(
          row,
          values,
        );

        if (otherName ==
            null) {
          continue;
        }

        if (!_looksLikeAdditionalNutrient(
          otherName,
        )) {
          continue;
        }

        _assignOtherNutrient(
          nutrientName:
              otherName,
          values:
              values,
          layout:
              layout,
          perServing:
              perServingBuilder,
          per100:
              per100Builder,
        );
      }

      // =================================================
      // RETURN STRUCTURED DATA
      // =================================================

      return NutritionLabelData(
        servingSizeAmount:
            servingSize?.amount,

        servingSizeUnit:
            servingSize?.unit,

        servingsPerPackage:
            servingsPerPackage,

        servingUnitAmount:
            servingUnit?.amount,

        servingUnitName:
            servingUnit?.name,

        perServing:
            perServingBuilder.hasAnyValue
                ? perServingBuilder
                    .build()
                : null,

        per100:
            per100Builder.hasAnyValue
                ? per100Builder
                    .build()
                : null,

        per100Unit:
            layout.per100Unit,

        rawText:
            rawText,
      );
    } finally {
      await recognizer.close();
    }
  }

  // =====================================================
  // BUILD OCR ROWS
  // =====================================================

  static List<_OcrRow> _buildRows(
    List<_OcrToken> tokens,
  ) {
    if (tokens.isEmpty) {
      return [];
    }

    final List<_OcrToken> sorted =
        List<_OcrToken>.from(
      tokens,
    )
          ..sort(
            (
              _OcrToken a,
              _OcrToken b,
            ) {
              return a.centerY.compareTo(
                b.centerY,
              );
            },
          );

    // ===================================================
    // FIND MEDIAN TEXT HEIGHT
    // ===================================================

    final List<double> heights =
        sorted
            .map(
              (
                _OcrToken token,
              ) =>
                  token.height,
            )
            .where(
              (
                double height,
              ) =>
                  height > 0,
            )
            .toList()
          ..sort();

    double medianHeight =
        14;

    if (heights.isNotEmpty) {
      final int middle =
          heights.length ~/
              2;

      if (heights.length.isOdd) {
        medianHeight =
            heights[middle];
      } else {
        medianHeight =
            (
                  heights[middle - 1] +
                      heights[middle]
                ) /
                2;
      }
    }

    // ===================================================
    // STRICTER ROW GROUPING
    // ===================================================

    final double tolerance =
        math
            .max(
              5.0,
              medianHeight *
                  0.55,
            )
            .toDouble();

    final List<_OcrRow> rows =
        [];

    for (final _OcrToken token
        in sorted) {
      _OcrRow? bestRow;

      double bestDistance =
          double.infinity;

      for (final _OcrRow row
          in rows) {
        final double distance =
            (
              row.centerY -
                  token.centerY
            ).abs();

        if (distance <=
                tolerance &&
            distance <
                bestDistance) {
          bestDistance =
              distance;

          bestRow =
              row;
        }
      }

      if (bestRow ==
          null) {
        rows.add(
          _OcrRow(
            tokens: [
              token,
            ],
          ),
        );
      } else {
        bestRow.tokens.add(
          token,
        );
      }
    }

    rows.sort(
      (
        _OcrRow a,
        _OcrRow b,
      ) {
        return a.centerY.compareTo(
          b.centerY,
        );
      },
    );

    return rows;
  }

  // =====================================================
  // DETECT COLUMN LAYOUT
  // =====================================================

  static _ColumnLayout _detectColumnLayout(
    List<_OcrRow> rows,
  ) {
    double? perServingX;

    double? per100X;

    String? per100Unit;

    for (final _OcrRow row
        in rows) {
      final String rowText =
          _normalise(
        row.text,
      );

      // =================================================
      // PER 100 HEADER
      // =================================================

      if (_containsAny(
        rowText,
        _per100Keywords,
      )) {
        per100X ??=
            _findPer100X(
          row,
        );

        if (rowText.contains(
              '100ml',
            ) ||
            rowText.contains(
              '100 ml',
            )) {
          per100Unit =
              'ml';
        } else if (rowText.contains(
              '100g',
            ) ||
            rowText.contains(
              '100 g',
            )) {
          per100Unit =
              'g';
        }
      }

      // =================================================
      // PER SERVING HEADER
      // =================================================

      if (_containsAny(
        rowText,
        _perServingKeywords,
      )) {
        perServingX ??=
            _findPerServingX(
          row,
        );
      }
    }

    return _ColumnLayout(
      perServingX:
          perServingX,
      per100X:
          per100X,
      per100Unit:
          per100Unit,
    );
  }

  // =====================================================
  // FIND PER SERVING X
  // =====================================================

  static double? _findPerServingX(
    _OcrRow row,
  ) {
    final List<_OcrToken> tokens =
        row.sortedTokens;

    for (int i = 0;
        i < tokens.length;
        i++) {
      final String text =
          _normalise(
        tokens[i].text,
      );

      if (text.contains(
            'serving',
          ) ||
          text.contains(
            'hidangan',
          )) {
        if (i > 0) {
          final String previous =
              _normalise(
            tokens[i - 1].text,
          );

          if (previous ==
                  'per' ||
              previous ==
                  'setiap') {
            return (
                  tokens[i - 1]
                          .centerX +
                      tokens[i]
                          .centerX
                ) /
                2;
          }
        }

        return tokens[i]
            .centerX;
      }
    }

    return null;
  }

  // =====================================================
  // FIND PER 100 X
  // =====================================================

  static double? _findPer100X(
    _OcrRow row,
  ) {
    final List<_OcrToken> tokens =
        row.sortedTokens;

    for (int i = 0;
        i < tokens.length;
        i++) {
      final String text =
          _normalise(
        tokens[i].text,
      );

      if (text.contains(
            '100g',
          ) ||
          text.contains(
            '100ml',
          )) {
        return tokens[i]
            .centerX;
      }

      if (text == '100' &&
          i + 1 <
              tokens.length) {
        final String next =
            _normalise(
          tokens[i + 1].text,
        );

        if (next == 'g' ||
            next == 'ml') {
          return (
                tokens[i].centerX +
                    tokens[i + 1]
                        .centerX
              ) /
              2;
        }
      }
    }

    return null;
  }

  // =====================================================
  // EXTRACT VALUES + X POSITIONS
  // =====================================================

  static List<_PositionedNutritionValue>
      _extractPositionedValues(
    _OcrRow row,
  ) {
    final List<_PositionedNutritionValue>
        result =
        [];

    final List<_OcrToken> tokens =
        row.sortedTokens;

    int i = 0;

    while (i <
        tokens.length) {
      final _OcrToken token =
          tokens[i];

      final String text =
          token.text.trim();

      // =================================================
      // VALUE AND UNIT IN SAME ELEMENT
      // =================================================

      final List<RegExpMatch> matches =
          _valuePattern
              .allMatches(
                text,
              )
              .toList();

      if (matches.isNotEmpty) {
        for (final RegExpMatch match
            in matches) {
          final double? amount =
              _parseNumber(
            match.group(
              1,
            ),
          );

          final String? unit =
              match.group(
            2,
          );

          if (amount == null ||
              unit == null) {
            continue;
          }

          result.add(
            _PositionedNutritionValue(
              amount:
                  amount,
              unit:
                  _normaliseUnit(
                unit,
              ),
              x:
                  token.centerX,
            ),
          );
        }

        i++;

        continue;
      }

      // =================================================
      // NUMBER AND UNIT SPLIT INTO TWO ELEMENTS
      // =================================================

      final RegExpMatch? numberMatch =
          _numberOnlyPattern
              .firstMatch(
        text,
      );

      if (numberMatch != null &&
          i + 1 <
              tokens.length) {
        final _OcrToken nextToken =
            tokens[i + 1];

        final String nextText =
            _normalise(
          nextToken.text,
        );

        final RegExpMatch? unitMatch =
            _unitOnlyPattern
                .firstMatch(
          nextText,
        );

        if (unitMatch != null) {
          final double? amount =
              _parseNumber(
            numberMatch.group(
              1,
            ),
          );

          final String? unit =
              unitMatch.group(
            1,
          );

          if (amount != null &&
              unit != null) {
            result.add(
              _PositionedNutritionValue(
                amount:
                    amount,
                unit:
                    _normaliseUnit(
                  unit,
                ),
                x:
                    (
                          token.centerX +
                              nextToken.centerX
                        ) /
                        2,
              ),
            );

            i += 2;

            continue;
          }
        }
      }

      i++;
    }

    return result;
  }

  // =====================================================
  // ASSIGN KNOWN NUTRIENT
  // =====================================================

  static void _assignKnownNutrient({
    required String nutrient,
    required List<_PositionedNutritionValue> values,
    required _ColumnLayout layout,
    required _NutritionValuesBuilder perServing,
    required _NutritionValuesBuilder per100,
  }) {
    for (final _PositionedNutritionValue value
        in values) {
      final _NutritionColumnType? column =
          _nearestColumn(
        value.x,
        layout,
      );

      if (column == null) {
        continue;
      }

      final _NutritionValuesBuilder builder =
          column ==
                  _NutritionColumnType
                      .perServing
              ? perServing
              : per100;

      _applyKnownValue(
        builder:
            builder,
        nutrient:
            nutrient,
        value:
            value,
      );
    }
  }

  // =====================================================
  // ASSIGN OTHER NUTRIENT
  // =====================================================

  static void _assignOtherNutrient({
    required String nutrientName,
    required List<_PositionedNutritionValue> values,
    required _ColumnLayout layout,
    required _NutritionValuesBuilder perServing,
    required _NutritionValuesBuilder per100,
  }) {
    final String key =
        _normalise(
      nutrientName,
    );

    for (final _PositionedNutritionValue value
        in values) {
      final _NutritionColumnType? column =
          _nearestColumn(
        value.x,
        layout,
      );

      if (column == null) {
        continue;
      }

      final _NutritionValuesBuilder builder =
          column ==
                  _NutritionColumnType
                      .perServing
              ? perServing
              : per100;

      builder.otherNutrients[
        key
      ] =
          NutrientValue(
        name:
            nutrientName,
        amount:
            value.amount,
        unit:
            value.unit,
      );
    }
  }

  // =====================================================
  // FIND NEAREST COLUMN
  // =====================================================

  static _NutritionColumnType? _nearestColumn(
    double x,
    _ColumnLayout layout,
  ) {
    // Only per serving.
    if (layout.hasPerServing &&
        !layout.hasPer100) {
      return _NutritionColumnType
          .perServing;
    }

    // Only per 100.
    if (!layout.hasPerServing &&
        layout.hasPer100) {
      return _NutritionColumnType
          .per100;
    }

    // No valid columns detected.
    if (!layout.hasPerServing &&
        !layout.hasPer100) {
      return null;
    }

    // Two columns.
    final double servingDistance =
        (
          x -
              layout.perServingX!
        ).abs();

    final double per100Distance =
        (
          x -
              layout.per100X!
        ).abs();

    if (servingDistance <
        per100Distance) {
      return _NutritionColumnType
          .perServing;
    }

    return _NutritionColumnType
        .per100;
  }

  // =====================================================
  // APPLY KNOWN VALUE
  // =====================================================

  static void _applyKnownValue({
    required _NutritionValuesBuilder builder,
    required String nutrient,
    required _PositionedNutritionValue value,
  }) {
    switch (nutrient) {
      // =================================================
      // ENERGY
      // =================================================

      case 'energy':
        if (value.unit ==
            'kcal') {
          builder.energyKcal =
              value.amount;
        } else if (value.unit ==
            'kj') {
          builder.energyKj =
              value.amount;
        }

        break;

      // =================================================
      // PROTEIN
      // =================================================

      case 'protein':
        builder.proteinG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // TOTAL FAT
      // =================================================

      case 'totalFat':
        builder.totalFatG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // SATURATED FAT
      // =================================================

      case 'saturatedFat':
        builder.saturatedFatG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // TRANS FAT
      // =================================================

      case 'transFat':
        builder.transFatG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // CARBOHYDRATE
      // =================================================

      case 'carbohydrate':
        builder.carbohydrateG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // SUGAR
      // =================================================

      case 'sugars':
        builder.sugarsG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // FIBRE
      // =================================================

      case 'fibre':
        builder.fibreG =
            _toGrams(
          value,
        );

        break;

      // =================================================
      // SODIUM
      // =================================================

      case 'sodium':
        builder.sodiumMg =
            _toMilligrams(
          value,
        );

        break;

      // =================================================
      // CHOLESTEROL
      // =================================================

      case 'cholesterol':
        builder.cholesterolMg =
            _toMilligrams(
          value,
        );

        break;
    }
  }

  // =====================================================
  // IDENTIFY CORE NUTRIENT
  // =====================================================

  static String? _identifyKnownNutrient(
    String text,
  ) {
    // More specific nutrients before generic fat.
    const List<String> priority = [
      'saturatedFat',
      'transFat',
      'carbohydrate',
      'sugars',
      'fibre',
      'sodium',
      'cholesterol',
      'energy',
      'protein',
      'totalFat',
    ];

    for (final String nutrient
        in priority) {
      final List<String>? keywords =
          _nutrientKeywords[
        nutrient
      ];

      if (keywords == null) {
        continue;
      }

      if (_containsAny(
        text,
        keywords,
      )) {
        return nutrient;
      }
    }

    return null;
  }

  // =====================================================
  // EXTRACT OTHER NUTRIENT NAME
  // =====================================================

  static String? _extractOtherNutrientName(
    _OcrRow row,
    List<_PositionedNutritionValue> values,
  ) {
    if (values.isEmpty) {
      return null;
    }

    // ===================================================
    // FIRST VALUE COLUMN
    // ===================================================

    final double firstValueX =
        values
            .map(
              (
                _PositionedNutritionValue value,
              ) =>
                  value.x,
            )
            .reduce(
              math.min,
            );

    final List<String> nameParts =
        [];

    for (final _OcrToken token
        in row.sortedTokens) {
      // Nutrient name must be left of the first value.
      if (token.centerX >=
          firstValueX) {
        continue;
      }

      final String cleaned =
          _normalise(
        token.text,
      );

      if (cleaned.isEmpty) {
        continue;
      }

      // Remove column header words.
      if (_isHeaderWord(
        cleaned,
      )) {
        continue;
      }

      nameParts.add(
        token.text,
      );
    }

    if (nameParts.isEmpty) {
      return null;
    }

    String name =
        nameParts
            .join(' ')
            .trim();

    name = name
        .replaceAll(
          RegExp(
            r'[:\-]+$',
          ),
          '',
        )
        .trim();

    if (name.length < 2) {
      return null;
    }

    return _titleCase(
      name,
    );
  }

  // =====================================================
  // CHECK ADDITIONAL NUTRIENT
  // =====================================================

  static bool _looksLikeAdditionalNutrient(
    String name,
  ) {
    final String text =
        _normalise(
      name,
    );

    for (final String hint
        in _otherNutrientHints) {
      if (text.contains(
        hint,
      )) {
        return true;
      }
    }

    return false;
  }

  // =====================================================
  // FILTER NON-NUTRIENT ROWS
  // =====================================================

  static bool _isNonNutrientRow(
    String text,
  ) {
    final String value =
        _normalise(
      text,
    );

    // Per serving header.
    if (_containsAny(
      value,
      _perServingKeywords,
    )) {
      return true;
    }

    // Per 100 header.
    if (_containsAny(
      value,
      _per100Keywords,
    )) {
      return true;
    }

    const List<String> blocked = [
      'serving size',
      'saiz hidangan',
      'servings per',
      'hidangan setiap bungkusan',
      'hidangan setiap pek',
      'net weight',
      'berat bersih',
      'daily value',
      '% daily value',
      'nilai harian',
      '% dv',
      'rni',
      'recommended nutrient intake',
      'nutrition information',
      'nutritional information',
      'nutrition facts',
      'maklumat pemakanan',
      'fakta pemakanan',
    ];

    for (final String blockedText
        in blocked) {
      if (value.contains(
        blockedText,
      )) {
        return true;
      }
    }

    return false;
  }

  // =====================================================
  // HEADER WORD CHECK
  // =====================================================

  static bool _isHeaderWord(
    String text,
  ) {
    const Set<String> words = {
      'setiap',
      'per',
      'serving',
      'serve',
      'portion',
      'hidangan',
      '100g',
      '100ml',
      '100',
      'g',
      'ml',
      '%',
      'daily',
      'value',
      'nilai',
      'harian',
      'rni',
    };

    return words.contains(
      text,
    );
  }

  // =====================================================
  // FIND SERVING SIZE
  // =====================================================

  static _ServingSizeResult?
      _findServingSize(
    String allText,
    List<_OcrRow> rows,
  ) {
    // ===================================================
    // EXPLICIT
    //
    // Saiz Hidangan: 1g
    // Serving Size: 250ml
    // ===================================================

    final RegExpMatch? explicit =
        _explicitServingSizePattern
            .firstMatch(
      allText,
    );

    if (explicit != null) {
      final double? amount =
          _parseNumber(
        explicit.group(
          1,
        ),
      );

      final String? unit =
          explicit.group(
        2,
      );

      if (amount != null &&
          unit != null) {
        return _ServingSizeResult(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
        );
      }
    }

    // ===================================================
    // HEADER
    //
    // Setiap Hidangan (1g)
    // ===================================================

    final RegExpMatch? header =
        _servingHeaderPattern
            .firstMatch(
      allText,
    );

    if (header != null) {
      final double? amount =
          _parseNumber(
        header.group(
          1,
        ),
      );

      final String? unit =
          header.group(
        2,
      );

      if (amount != null &&
          unit != null) {
        return _ServingSizeResult(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
        );
      }
    }

    // ===================================================
    // CHECK INDIVIDUAL ROWS
    // ===================================================

    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      final RegExpMatch? explicitRow =
          _explicitServingSizePattern
              .firstMatch(
        text,
      );

      if (explicitRow != null) {
        final double? amount =
            _parseNumber(
          explicitRow.group(
            1,
          ),
        );

        final String? unit =
            explicitRow.group(
          2,
        );

        if (amount != null &&
            unit != null) {
          return _ServingSizeResult(
            amount:
                amount,
            unit:
                unit.toLowerCase(),
          );
        }
      }

      final RegExpMatch? headerRow =
          _servingHeaderPattern
              .firstMatch(
        text,
      );

      if (headerRow != null) {
        final double? amount =
            _parseNumber(
          headerRow.group(
            1,
          ),
        );

        final String? unit =
            headerRow.group(
          2,
        );

        if (amount != null &&
            unit != null) {
          return _ServingSizeResult(
            amount:
                amount,
            unit:
                unit.toLowerCase(),
          );
        }
      }
    }

    return null;
  }

  // =====================================================
  // FIND SERVINGS PER PACKAGE
  // =====================================================

  static double? _findServingsPerPackage(
    String text,
  ) {
    final RegExpMatch? match =
        _servingsPerPackagePattern
            .firstMatch(
      text,
    );

    if (match == null) {
      return null;
    }

    return _parseNumber(
      match.group(
        1,
      ),
    );
  }

  // =====================================================
  // FIND PHYSICAL SERVING
  // =====================================================

  static _ServingUnitResult?
      _findPhysicalServingUnit(
    List<_OcrRow> rows,
  ) {
    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      if (!text.contains(
            'serving size',
          ) &&
          !text.contains(
            'saiz hidangan',
          )) {
        continue;
      }

      // =================================================
      // FRACTION
      //
      // 1/2 bottle
      // =================================================

      final RegExpMatch? fraction =
          _fractionServingPattern
              .firstMatch(
        text,
      );

      if (fraction != null) {
        final double? numerator =
            _parseNumber(
          fraction.group(
            1,
          ),
        );

        final double? denominator =
            _parseNumber(
          fraction.group(
            2,
          ),
        );

        final String? name =
            fraction.group(
          3,
        );

        if (numerator != null &&
            denominator != null &&
            denominator != 0 &&
            name != null) {
          return _ServingUnitResult(
            amount:
                numerator /
                    denominator,
            name:
                _singularise(
              name,
            ),
          );
        }
      }

      // =================================================
      // COUNT
      //
      // 15 chips
      // 1 tablet
      // =================================================

      final RegExpMatch? count =
          _countServingPattern
              .firstMatch(
        text,
      );

      if (count != null) {
        final double? amount =
            _parseNumber(
          count.group(
            1,
          ),
        );

        final String? name =
            count.group(
          2,
        );

        if (amount != null &&
            name != null) {
          return _ServingUnitResult(
            amount:
                amount,
            name:
                _singularise(
              name,
            ),
          );
        }
      }
    }

    return null;
  }

  // =====================================================
  // FIND PACKAGE RELATION
  // =====================================================

  static _PackageRelation?
      _findPackageRelation(
    String text,
  ) {
    final RegExpMatch? match =
        _packageRelationPattern
            .firstMatch(
      text,
    );

    if (match == null) {
      return null;
    }

    final double? amount =
        _parseNumber(
      match.group(
        1,
      ),
    );

    final String? measurementUnit =
        match.group(
      2,
    );

    final String? item =
        match.group(
      3,
    );

    if (amount == null ||
        measurementUnit == null ||
        item == null) {
      return null;
    }

    return _PackageRelation(
      amountPerUnit:
          amount,
      measurementUnit:
          measurementUnit
              .toLowerCase(),
      itemName:
          _singularise(
        item,
      ),
    );
  }

  // =====================================================
  // CONVERT TO GRAMS
  // =====================================================

  static double? _toGrams(
    _PositionedNutritionValue value,
  ) {
    switch (value.unit) {
      case 'g':
        return value.amount;

      case 'mg':
        return value.amount /
            1000;

      case 'mcg':
        return value.amount /
            1000000;

      default:
        return null;
    }
  }

  // =====================================================
  // CONVERT TO MILLIGRAMS
  // =====================================================

  static double? _toMilligrams(
    _PositionedNutritionValue value,
  ) {
    switch (value.unit) {
      case 'mg':
        return value.amount;

      case 'g':
        return value.amount *
            1000;

      case 'mcg':
        return value.amount /
            1000;

      default:
        return null;
    }
  }

  // =====================================================
  // NORMALISE UNIT
  // =====================================================

  static String _normaliseUnit(
    String unit,
  ) {
    final String value =
        unit.toLowerCase();

    if (value == 'µg' ||
        value == 'ug') {
      return 'mcg';
    }

    return value;
  }

  // =====================================================
  // SINGULARISE
  // =====================================================

  static String _singularise(
    String value,
  ) {
    const Map<String, String> replacements = {
      'bottles':
          'bottle',
      'packs':
          'pack',
      'pieces':
          'piece',
      'tablets':
          'tablet',
      'capsules':
          'capsule',
      'sachets':
          'sachet',
      'cups':
          'cup',
      'chips':
          'chip',
      'biscuits':
          'biscuit',
      'crackers':
          'cracker',
    };

    final String text =
        value.toLowerCase();

    return replacements[text] ??
        text;
  }

  // =====================================================
  // TITLE CASE
  // =====================================================

  static String _titleCase(
    String value,
  ) {
    return value
        .split(' ')
        .where(
          (
            String part,
          ) =>
              part.isNotEmpty,
        )
        .map(
          (
            String part,
          ) {
            if (part.length == 1) {
              return part
                  .toUpperCase();
            }

            return '${part[0].toUpperCase()}'
                '${part.substring(1)}';
          },
        )
        .join(' ');
  }

  // =====================================================
  // PARSE NUMBER
  // =====================================================

  static double? _parseNumber(
    String? value,
  ) {
    if (value == null) {
      return null;
    }

    return double.tryParse(
      value.replaceAll(
        ',',
        '.',
      ),
    );
  }

  // =====================================================
  // CONTAINS ANY KEYWORD
  // =====================================================

  static bool _containsAny(
    String text,
    List<String> keywords,
  ) {
    for (final String keyword
        in keywords) {
      if (text.contains(
        keyword,
      )) {
        return true;
      }
    }

    return false;
  }

  // =====================================================
  // NORMALISE TEXT
  // =====================================================

  static String _normalise(
    String text,
  ) {
    return text
        .toLowerCase()
        .replaceAll(
          '\r',
          ' ',
        )
        .replaceAll(
          '\n',
          ' ',
        )
        .replaceAll(
          '–',
          '-',
        )
        .replaceAll(
          '—',
          '-',
        )
        .replaceAll(
          RegExp(
            r'\s+',
          ),
          ' ',
        )
        .trim();
  }
}