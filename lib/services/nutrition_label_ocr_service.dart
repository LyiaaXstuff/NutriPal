import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../models/label_detection_status.dart';
import '../models/nutrition_label_data.dart';
import 'nutrition_table_parser.dart';
import 'ocr_geometry.dart';

// =======================================================
// VALIDATION RESULT
// =======================================================

class NutritionLabelValidationResult {
  final LabelDetectionStatus status;

  final String rawText;

  final int score;

  // Number of different nutrient names recognised.
  final int nutrientMatches;

  // Number of nutrients with at least one readable value.
  final int pairedNutrientMatches;

  // Number of core NutriPal nutrients with readable values.
  final int coreNutrientPairMatches;

  // Number of recognised values such as:
  // 10 g, 120 mg, 400 kcal, etc.
  final int unitMatches;

  final bool hasNutritionHeading;

  // General serving information exists.
  final bool hasServingInformation;

  // TRUE only when an actual serving amount is known,
  // for example:
  //
  // Saiz Hidangan: 1g
  // Setiap Hidangan (1g)
  // 30g (1g x 30 tablet)
  final bool hasServingSizeValue;

  final bool hasReferenceBasis;

  final bool hasPerServingReference;

  final bool hasPer100Reference;

  // Helpful for future nutrient calculation.
  final double? servingSizeAmount;

  final String? servingSizeUnit;

  // Example:
  // "explicit"
  // "servingHeader"
  // "packageRelation"
  final String? servingSizeSource;

  // Why the label is not complete, in plain words for the
  // user, most important first. Empty when complete.
  final List<String> issues;

  const NutritionLabelValidationResult({
    required this.status,
    required this.rawText,
    required this.score,
    required this.nutrientMatches,
    required this.pairedNutrientMatches,
    required this.coreNutrientPairMatches,
    required this.unitMatches,
    required this.hasNutritionHeading,
    required this.hasServingInformation,
    required this.hasServingSizeValue,
    required this.hasReferenceBasis,
    required this.hasPerServingReference,
    required this.hasPer100Reference,
    required this.servingSizeAmount,
    required this.servingSizeUnit,
    required this.servingSizeSource,
    this.issues = const [],
  });

  NutritionLabelValidationResult withStatus(
    LabelDetectionStatus newStatus,
    List<String> newIssues,
  ) {
    return NutritionLabelValidationResult(
      status: newStatus,
      rawText: rawText,
      score: score,
      nutrientMatches: nutrientMatches,
      pairedNutrientMatches: pairedNutrientMatches,
      coreNutrientPairMatches: coreNutrientPairMatches,
      unitMatches: unitMatches,
      hasNutritionHeading: hasNutritionHeading,
      hasServingInformation: hasServingInformation,
      hasServingSizeValue: hasServingSizeValue,
      hasReferenceBasis: hasReferenceBasis,
      hasPerServingReference: hasPerServingReference,
      hasPer100Reference: hasPer100Reference,
      servingSizeAmount: servingSizeAmount,
      servingSizeUnit: servingSizeUnit,
      servingSizeSource: servingSizeSource,
      issues: newIssues,
    );
  }
}

// =======================================================
// SERVING SIZE EVIDENCE
// =======================================================

class _ServingSizeEvidence {
  final double amount;

  final String unit;

  final String source;

  const _ServingSizeEvidence({
    required this.amount,
    required this.unit,
    required this.source,
  });
}

// =======================================================
// POSITIONED OCR FRAGMENT
// =======================================================

class _OcrFragment {
  final String text;

  final double left;

  final double top;

  final double bottom;

  const _OcrFragment({
    required this.text,
    required this.left,
    required this.top,
    required this.bottom,
  });

  double get centerY =>
      (top + bottom) / 2;

  double get height =>
      bottom - top;
}

// =======================================================
// RECONSTRUCTED OCR ROW
// =======================================================

class _OcrRow {
  final List<_OcrFragment> fragments;

  _OcrRow({
    required this.fragments,
  });

  double get centerY {
    if (fragments.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final _OcrFragment fragment
        in fragments) {
      total += fragment.centerY;
    }

    return total /
        fragments.length;
  }

  String get text {
    final List<_OcrFragment> sorted =
        List<_OcrFragment>.from(
      fragments,
    )
          ..sort(
            (
              _OcrFragment a,
              _OcrFragment b,
            ) {
              return a.left.compareTo(
                b.left,
              );
            },
          );

    return sorted
        .map(
          (
            _OcrFragment fragment,
          ) =>
              fragment.text,
        )
        .join(' ')
        .trim();
  }
}

// =======================================================
// NUTRITION LABEL OCR SERVICE
// =======================================================

class NutritionLabelOcrService {
  // =====================================================
  // NUTRITION LABEL HEADINGS
  // =====================================================

  static const List<String> _nutritionHeadings = [
    // English
    'nutrition information',
    'nutritional information',
    'nutrition facts',
    'nutrition fact',
    'nutrition panel',

    // Malay
    'maklumat pemakanan',
    'fakta pemakanan',
    'nilai pemakanan',
  ];

  // =====================================================
  // GENERAL SERVING INFORMATION
  // =====================================================

  static const List<String> _servingKeywords = [
    // English
    'serving size',
    'servings per package',
    'servings per pack',
    'servings per container',
    'serving per package',
    'serving per pack',

    // Malay
    'saiz hidangan',
    'hidangan setiap pek',
    'hidangan setiap bungkusan',
  ];

  // =====================================================
  // PER SERVING REFERENCE
  // =====================================================

  static const List<String> _perServingKeywords = [
    'per serving',
    'per serve',
    'per portion',
    'setiap hidangan',
    'setiap sajian',
    'per sachet',
    'per bar',
    'per bottle',
    'per piece',
    'per packet',
    'setiap uncang',
    'setiap paket',
    'setiap biji',
    'setiap keping',
    'setiap botol',
  ];

  // "Per 30 g" column (serving expressed in grams).
  static final RegExp _perGramServingPattern = RegExp(
    r'\b(?:per|setiap)\s*(?!1[0o]{2}\s*(?:g|ml)\b)\d+(?:[.,]\d+)?\s*(?:g|ml)\b',
    caseSensitive: false,
  );

  // "per 100g", "setiap 100 g", OCR "1OOg", "100 m1".
  static final RegExp _per100Pattern = RegExp(
    r'\b(?:per|setiap)\s*1[0o]{2}\s*(?:g|ml|m1|mi)\b',
    caseSensitive: false,
  );

  // Unit printed in the nutrient name:
  // "Protein (g)   3.2   12.8"
  static final RegExp _unitHintPattern = RegExp(
    r'\(\s*(?:g|mg|kcal|kj|mcg|µg)\s*\)|\b(?:kcal|kj)\b',
    caseSensitive: false,
  );

  // =====================================================
  // PER 100G / 100ML REFERENCE
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
  // NUTRIENT KEYWORDS
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
      'saturated',
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
  // CORE NUTRIENTS
  //
  // These increase confidence that a real usable
  // nutrition table has been captured.
  // =====================================================

  static const Set<String> _coreNutrients = {
    'energy',
    'carbohydrate',
    'sugars',
    'protein',
    'totalFat',
    'sodium',
  };

  // =====================================================
  // NUTRIENT VALUE
  // =====================================================

  static final RegExp _nutritionValuePattern =
      RegExp(
    r'(?:<|≤)?\s*\d+(?:[.,]\d+)?\s*(?:mg|rng|g|kcal|kj|mcg|µg|ug)\b',
    caseSensitive: false,
  );

  // =====================================================
  // EXPLICIT SERVING SIZE
  //
  // Examples:
  //
  // Serving Size: 25 g
  // Saiz Hidangan: 1g
  // =====================================================

  static final RegExp _explicitServingSizePattern =
      RegExp(
    // Also handles "Saiz hidangan / Serving size: 2 keping (30 g)"
    // and "Serving size 1 cup (240 ml)".
    r'(?:serving\s*size|saiz\s*hidangan|saiz\s*sajian)'
    r'[^0-9]{0,30}?'
    r'(?:\d+(?:[.,]\d+)?\s*(?!(?:mg|g|ml|l)\b)[a-z]+(?:\s+(?:besar|teh))?\s*)?'
    r'[\(\[]?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)\b',
    caseSensitive: false,
  );

  // =====================================================
  // SERVING SIZE FROM TABLE HEADER
  //
  // Examples:
  //
  // Per Serving (25g)
  // Setiap Hidangan (1g)
  // Setiap Hidangan 1 g
  // =====================================================

  static final RegExp _servingHeaderSizePattern =
      RegExp(
    r'(?:per\s*serving|per\s*serve|setiap\s*hidangan)'
    r'\s*'
    r'[\(\[]?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)'
    r'\s*[\)\]]?',
    caseSensitive: false,
  );

  // =====================================================
  // PACKAGE RELATION
  //
  // Examples:
  //
  // 30g (1g x 30 tablet)
  // 30 g (1 g × 30 tablets)
  // 1g x 30tablet
  //
  // This can tell NutriPal:
  //
  // 1 tablet = 1 g
  // =====================================================

  static final RegExp _packageRelationPattern =
      RegExp(
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)'
    r'\s*[x×]\s*'
    r'\d+\s*'
    r'(?:tablet|tablets|piece|pieces|sachet|sachets|capsule|capsules)',
    caseSensitive: false,
  );

  // =====================================================
  // SIMPLE STATUS METHOD
  // =====================================================

  static Future<LabelDetectionStatus> validateStatus(
    String imagePath,
  ) async {
    final NutritionLabelValidationResult result =
        await validateImage(
      imagePath,
    );

    return result.status;
  }

  // Last result per image, so the preview screen can tell
  // the user WHY a photo is incomplete.
  static final Map<String, List<String>> _issuesByImage = {};

  static List<String> issuesFor(
    String imagePath,
  ) {
    return _issuesByImage[imagePath] ?? const [];
  }

  // =====================================================
  // OCR + VALIDATION
  // =====================================================

  static Future<NutritionLabelValidationResult>
      validateImage(
    String imagePath,
  ) async {
    final File imageFile =
        File(
      imagePath,
    );

    if (!await imageFile.exists()) {
      return _emptyResult();
    }

    final TextRecognizer recognizer =
        TextRecognizer(
      script:
          TextRecognitionScript.latin,
    );

    try {
      final InputImage inputImage =
          InputImage.fromFilePath(
        imagePath,
      );

      final RecognizedText recognizedText =
          await recognizer.processImage(
        inputImage,
      );

      final String rawText =
          recognizedText.text.trim();

      // =================================================
      // POSITIONED OCR FRAGMENTS
      // =================================================

      final List<_OcrFragment> fragments =
          [];

      // Tilted photos: rotate positions back so a nutrient
      // name and its values end up on the same row.
      final double skew =
          OcrGeometry.estimateSkew(
        recognizedText,
      );

      final double cosSkew =
          math.cos(skew);

      final double sinSkew =
          math.sin(skew);

      for (final TextBlock block
          in recognizedText.blocks) {
        for (final TextLine line
            in block.lines) {
          final String text =
              line.text.trim();

          if (text.isEmpty) {
            continue;
          }

          final rect =
              line.boundingBox;

          final double centerX =
              rect.center.dx;

          final double centerY =
              rect.center.dy;

          final double rotatedX =
              centerX * cosSkew +
                  centerY * sinSkew;

          final double rotatedY =
              -centerX * sinSkew +
                  centerY * cosSkew;

          final double trueHeight =
              math.max(
            rect.height * 0.5,
            (
                  rect.height -
                      rect.width *
                          sinSkew.abs()
                ) /
                cosSkew,
          );

          fragments.add(
            _OcrFragment(
              text:
                  text,
              left:
                  rotatedX -
                      rect.width / 2,
              top:
                  rotatedY -
                      trueHeight / 2,
              bottom:
                  rotatedY +
                      trueHeight / 2,
            ),
          );
        }
      }

      final List<_OcrRow> rows =
          _buildRows(
        fragments,
      );

      final NutritionLabelValidationResult keywordCheck =
          _classify(
        rawText:
            rawText,
        rows:
            rows,
      );

      // =================================================
      // COMPLETENESS CHECK
      //
      // Read the table the same way the analysis does and
      // make sure the WHOLE table is inside the photo:
      // every value row has a name, nothing touches the
      // photo edge, and the serving basis is readable.
      // =================================================

      final List<NutritionTableDiagnostics> diagnostics =
          [];

      final NutritionLabelData table =
          NutritionTableParser.parse(
        OcrGeometry.linesFrom(
          recognizedText,
        ),
        rawText:
            rawText,
        skewRadians:
            skew,
        diagnosticsOut:
            diagnostics,
      );

      final math.Point<double>? imageSize =
          await _uprightImageSize(
        imagePath,
      );

      final List<String> issues =
          completenessIssues(
        table:
            table,
        diagnostics:
            diagnostics.isEmpty
                ? null
                : diagnostics.first,
        imageWidth:
            imageSize?.x,
        imageHeight:
            imageSize?.y,
      );

      late final LabelDetectionStatus status;

      if (issues.isEmpty) {
        status =
            LabelDetectionStatus.detected;
      } else if (keywordCheck.status ==
              LabelDetectionStatus.notDetected &&
          table.nutrients.isEmpty) {
        status =
            LabelDetectionStatus.notDetected;
      } else {
        status =
            LabelDetectionStatus.unclear;
      }

      _issuesByImage[imagePath] =
          issues;

      return keywordCheck.withStatus(
        status,
        issues,
      );
    } finally {
      await recognizer.close();
    }
  }

  // =====================================================
  // COMPLETENESS RULES
  // =====================================================
  //
  // Public and pure so it can be unit-tested.
  // =====================================================

  static List<String> completenessIssues({
    required NutritionLabelData table,
    required NutritionTableDiagnostics? diagnostics,
    required double? imageWidth,
    required double? imageHeight,
  }) {
    final List<String> issues = [];

    // ---------------------------------------------------
    // 1. Table touching the photo edge = cut off
    // ---------------------------------------------------

    if (diagnostics != null &&
        imageWidth != null &&
        imageHeight != null) {
      final OcrBounds b =
          diagnostics.contentBounds;

      final double margin =
          math.max(
        4,
        diagnostics.textHeight * 0.5,
      );

      final List<String> sides = [
        if (b.left < margin) 'left',
        if (b.right > imageWidth - margin) 'right',
        if (b.top < margin) 'top',
        if (b.bottom > imageHeight - margin) 'bottom',
      ];

      if (sides.isNotEmpty) {
        final String where = sides.length == 1
            ? 'the ${sides.first} edge'
            : 'the ${sides.sublist(0, sides.length - 1).join(', ')} and ${sides.last} edges';

        issues.add(
          'The nutrition table is cut off at $where of the photo. '
          'Move back so the whole table border fits inside the frame.',
        );
      }
    }

    // ---------------------------------------------------
    // 2. Values without names = names cut off / unreadable
    // ---------------------------------------------------

    if (diagnostics != null &&
        diagnostics.unnamedValueRows > 0) {
      issues.add(
        diagnostics.unnamedValueRows == 1
            ? 'One nutrient name is cut off or unreadable.'
            : '${diagnostics.unnamedValueRows} nutrient names are cut off or unreadable.',
      );
    }

    // ---------------------------------------------------
    // 3. Enough of the table to analyse
    // ---------------------------------------------------

    if (table.nutrients.length < 4) {
      issues.add(
        table.nutrients.isEmpty
            ? 'No nutrient rows could be read.'
            : 'Only ${table.nutrients.length} nutrient rows could be read.',
      );
    }

    final bool hasEnergy =
        table.nutrients.any(
      (NutrientRow row) =>
          RegExp(
            r'energy|tenaga|calorie|kalori',
            caseSensitive: false,
          ).hasMatch(
            row.name,
          ),
    );

    if (table.nutrients.isNotEmpty &&
        !hasEnergy) {
      issues.add(
        'The energy (Tenaga) row could not be read.',
      );
    }

    if (table.nutrients.isNotEmpty &&
        !table.canCalculatePortion) {
      issues.add(
        'The serving size or the per serving / per 100 g headings could not be read.',
      );
    }

    return issues;
  }

  // =====================================================
  // PHOTO SIZE (as ML Kit sees it: EXIF rotation applied)
  // =====================================================

  static Future<math.Point<double>?> _uprightImageSize(
    String imagePath,
  ) async {
    try {
      return await Isolate.run<math.Point<double>?>(
        () {
          final Uint8List bytes =
              File(
            imagePath,
          ).readAsBytesSync();

          final img.DecodeInfo? info =
              img.findDecoderForData(
            bytes,
          )?.startDecode(
            bytes,
          );

          if (info == null) {
            return null;
          }

          double width =
              info.width.toDouble();

          double height =
              info.height.toDouble();

          final int orientation =
              img.decodeJpgExif(
                    bytes,
                  )?.imageIfd.orientation ??
                  1;

          // EXIF orientations 5-8 are rotated 90 degrees.
          if (orientation >= 5 &&
              orientation <= 8) {
            final double swap =
                width;

            width =
                height;

            height =
                swap;
          }

          return math.Point<double>(
            width,
            height,
          );
        },
      );
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  // EMPTY RESULT
  // =====================================================

  static NutritionLabelValidationResult
      _emptyResult() {
    return const NutritionLabelValidationResult(
      status:
          LabelDetectionStatus.notDetected,
      rawText:
          '',
      score:
          0,
      nutrientMatches:
          0,
      pairedNutrientMatches:
          0,
      coreNutrientPairMatches:
          0,
      unitMatches:
          0,
      hasNutritionHeading:
          false,
      hasServingInformation:
          false,
      hasServingSizeValue:
          false,
      hasReferenceBasis:
          false,
      hasPerServingReference:
          false,
      hasPer100Reference:
          false,
      servingSizeAmount:
          null,
      servingSizeUnit:
          null,
      servingSizeSource:
          null,
    );
  }

  // =====================================================
  // BUILD ROWS FROM OCR POSITIONS
  // =====================================================

  static List<_OcrRow> _buildRows(
    List<_OcrFragment> fragments,
  ) {
    if (fragments.isEmpty) {
      return [];
    }

    final List<_OcrFragment> sorted =
        List<_OcrFragment>.from(
      fragments,
    )
          ..sort(
            (
              _OcrFragment a,
              _OcrFragment b,
            ) {
              return a.centerY.compareTo(
                b.centerY,
              );
            },
          );

    // ===================================================
    // MEDIAN TEXT HEIGHT
    // ===================================================

    final List<double> heights =
        sorted
            .map(
              (
                _OcrFragment fragment,
              ) =>
                  fragment.height,
            )
            .where(
              (
                double value,
              ) =>
                  value >
                  0,
            )
            .toList()
          ..sort();

    double medianHeight =
        16;

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

    final double rowTolerance =
        math
            .max(
              7.0,
              medianHeight *
                  0.70,
            )
            .toDouble();

    final List<_OcrRow> rows =
        [];

    // ===================================================
    // GROUP FRAGMENTS BY HORIZONTAL ROW
    // ===================================================

    for (final _OcrFragment fragment
        in sorted) {
      _OcrRow? nearestRow;

      double nearestDistance =
          double.infinity;

      for (final _OcrRow row
          in rows) {
        final double distance =
            (
              row.centerY -
                  fragment.centerY
            ).abs();

        if (distance <=
                rowTolerance &&
            distance <
                nearestDistance) {
          nearestDistance =
              distance;

          nearestRow =
              row;
        }
      }

      if (nearestRow ==
          null) {
        rows.add(
          _OcrRow(
            fragments: [
              fragment,
            ],
          ),
        );
      } else {
        nearestRow.fragments.add(
          fragment,
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
  // CLASSIFY LABEL
  // =====================================================

  static NutritionLabelValidationResult
      _classify({
    required String rawText,
    required List<_OcrRow> rows,
  }) {
    final String allText =
        _normalise(
      rawText,
    );

    if (allText.isEmpty) {
      return _emptyResult();
    }

    // ===================================================
    // BASIC LABEL EVIDENCE
    // ===================================================

    final bool hasNutritionHeading =
        _containsAny(
      allText,
      _nutritionHeadings,
    );

    final bool hasServingInformation =
        _containsAny(
      allText,
      _servingKeywords,
    );

    // ===================================================
    // REFERENCE BASIS
    // ===================================================

    final bool hasPerServingReference =
        _containsAny(
              allText,
              _perServingKeywords,
            ) ||
            _perGramServingPattern.hasMatch(
              allText,
            );

    final bool hasPer100Reference =
        _containsAny(
              allText,
              _per100Keywords,
            ) ||
            _per100Pattern.hasMatch(
              allText,
            );

    final bool hasReferenceBasis =
        hasPerServingReference ||
            hasPer100Reference;

    // ===================================================
    // FIND ACTUAL SERVING SIZE
    // ===================================================

    final _ServingSizeEvidence?
        servingSize =
        _findServingSize(
      allText:
          allText,
      rows:
          rows,
    );

    final bool hasServingSizeValue =
        servingSize !=
            null;

    // ===================================================
    // RECOGNISED NUTRIENTS
    // ===================================================

    final Set<String> recognisedNutrients =
        {};

    for (final MapEntry<String, List<String>>
        entry
        in _nutrientKeywords.entries) {
      if (_containsAny(
        allText,
        entry.value,
      )) {
        recognisedNutrients.add(
          entry.key,
        );
      }
    }

    final int nutrientMatches =
        recognisedNutrients.length;

    // ===================================================
    // NUTRIENT + VALUE PAIRS
    // ===================================================

    final Set<String> pairedNutrients =
        _findPairedNutrients(
      rows,
    );

    final int pairedNutrientMatches =
        pairedNutrients.length;

    final int coreNutrientPairMatches =
        pairedNutrients
            .intersection(
              _coreNutrients,
            )
            .length;

    // ===================================================
    // ALL NUTRITION VALUES
    // ===================================================

    final int unitMatches =
        _nutritionValuePattern
            .allMatches(
              allText,
            )
            .length;

    // ===================================================
    // COVERAGE
    // ===================================================

    final double pairCoverage =
        nutrientMatches ==
                0
            ? 0
            : pairedNutrientMatches /
                nutrientMatches;

    // ===================================================
    // IMPORTANT:
    //
    // "Servings per package: 30"
    //
    // DOES NOT make:
    //
    // hasServingSizeValue = true
    //
    // Only an actual measurable serving amount does.
    // ===================================================

    // ===================================================
    // CAN NUTRIPAL USE THE VALUE COLUMN?
    // ===================================================

    // ---------------------------------------------------
    // PER SERVING
    //
    // The numeric column already refers to one serving.
    //
    // It can therefore be analysed directly.
    // ---------------------------------------------------

    final bool hasUsablePerServingColumn =
        hasPerServingReference;

    // ---------------------------------------------------
    // PER 100 G / 100 ML
    //
    // NutriPal MUST know the serving amount before it
    // can calculate intended portions.
    //
    // Example:
    //
    // Carbohydrate = 78.5 g / 100 g
    //
    // Serving size = 1 g
    //
    // Per serving:
    //
    // 78.5 × 1 / 100
    // ---------------------------------------------------

    final bool hasUsablePer100Column =
        hasPer100Reference &&
            hasServingSizeValue;

    final bool hasUsableValueBasis =
        hasUsablePerServingColumn ||
            hasUsablePer100Column;

    // ===================================================
    // STRONG LABEL EVIDENCE
    // ===================================================

    final bool hasStrongLabelEvidence =
        hasNutritionHeading ||
            (
              hasReferenceBasis &&
                  nutrientMatches >=
                      2
            ) ||
            (
              hasServingInformation &&
                  nutrientMatches >=
                      2
            ) ||
            nutrientMatches >=
                4;

    // ===================================================
    // ONE COMPLETE COLUMN IS ENOUGH
    // ===================================================

    final bool hasEnoughValueRows =
        pairedNutrientMatches >=
            4;

    final bool hasGoodPairCoverage =
        pairCoverage >=
            0.70;

    final bool hasEnoughCoreRows =
        coreNutrientPairMatches >=
            3;

    // ===================================================
    // FINAL COMPLETENESS RULE
    // ===================================================

    final bool isCompleteEnough =
        hasStrongLabelEvidence &&
            hasUsableValueBasis &&
            hasEnoughValueRows &&
            hasGoodPairCoverage &&
            hasEnoughCoreRows;

    // ===================================================
    // SCORE
    // ===================================================

    int score =
        0;

    if (hasNutritionHeading) {
      score +=
          3;
    }

    if (hasServingInformation) {
      score +=
          2;
    }

    if (hasServingSizeValue) {
      score +=
          3;
    }

    if (hasReferenceBasis) {
      score +=
          2;
    }

    if (hasUsableValueBasis) {
      score +=
          3;
    }

    score +=
        pairedNutrientMatches *
            2;

    if (hasGoodPairCoverage) {
      score +=
          2;
    }

    if (hasEnoughCoreRows) {
      score +=
          2;
    }

    // ===================================================
    // STATUS
    // ===================================================

    late final LabelDetectionStatus status;

    if (isCompleteEnough) {
      status =
          LabelDetectionStatus.detected;
    } else if (
        hasNutritionHeading ||
        hasServingInformation ||
        hasReferenceBasis ||
        nutrientMatches >=
            2 ||
        pairedNutrientMatches >=
            2) {
      status =
          LabelDetectionStatus.unclear;
    } else {
      status =
          LabelDetectionStatus.notDetected;
    }

    return NutritionLabelValidationResult(
      status:
          status,
      rawText:
          rawText,
      score:
          score,
      nutrientMatches:
          nutrientMatches,
      pairedNutrientMatches:
          pairedNutrientMatches,
      coreNutrientPairMatches:
          coreNutrientPairMatches,
      unitMatches:
          unitMatches,
      hasNutritionHeading:
          hasNutritionHeading,
      hasServingInformation:
          hasServingInformation,
      hasServingSizeValue:
          hasServingSizeValue,
      hasReferenceBasis:
          hasReferenceBasis,
      hasPerServingReference:
          hasPerServingReference,
      hasPer100Reference:
          hasPer100Reference,
      servingSizeAmount:
          servingSize?.amount,
      servingSizeUnit:
          servingSize?.unit,
      servingSizeSource:
          servingSize?.source,
    );
  }

  // =====================================================
  // FIND SERVING SIZE
  // =====================================================
  //
  // Priority:
  //
  // 1. Explicit:
  //    Saiz Hidangan: 1g
  //
  // 2. Column header:
  //    Setiap Hidangan (1g)
  //
  // 3. Package relationship:
  //    30g (1g x 30 tablet)
  //
  // IMPORTANT:
  //
  // "Hidangan Setiap Bungkusan: 30"
  //
  // is NEVER treated as serving size.
  // =====================================================

  static _ServingSizeEvidence?
      _findServingSize({
    required String allText,
    required List<_OcrRow> rows,
  }) {
    // ===================================================
    // 1. EXPLICIT SERVING SIZE
    // ===================================================

    final RegExpMatch? explicitMatch =
        _explicitServingSizePattern
            .firstMatch(
      allText,
    );

    if (explicitMatch !=
        null) {
      final double? amount =
          _parseNumber(
        explicitMatch.group(
          1,
        ),
      );

      final String? unit =
          explicitMatch.group(
        2,
      );

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeEvidence(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
          source:
              'explicit',
        );
      }
    }

    // ===================================================
    // ALSO CHECK RECONSTRUCTED ROWS
    //
    // Useful when OCR spacing is unusual.
    // ===================================================

    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      final RegExpMatch? match =
          _explicitServingSizePattern
              .firstMatch(
        text,
      );

      if (match ==
          null) {
        continue;
      }

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

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeEvidence(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
          source:
              'explicit',
        );
      }
    }

    // ===================================================
    // 2. SERVING SIZE FROM HEADER
    //
    // Setiap Hidangan (1g)
    // ===================================================

    final RegExpMatch? headerMatch =
        _servingHeaderSizePattern
            .firstMatch(
      allText,
    );

    if (headerMatch !=
        null) {
      final double? amount =
          _parseNumber(
        headerMatch.group(
          1,
        ),
      );

      final String? unit =
          headerMatch.group(
        2,
      );

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeEvidence(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
          source:
              'servingHeader',
        );
      }
    }

    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      final RegExpMatch? match =
          _servingHeaderSizePattern
              .firstMatch(
        text,
      );

      if (match ==
          null) {
        continue;
      }

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

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeEvidence(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
          source:
              'servingHeader',
        );
      }
    }

    // ===================================================
    // 3. PACKAGE RELATION
    //
    // Example:
    //
    // Berat Bersih:
    // 30g (1g x 30 tablet)
    //
    // NutriPal may infer:
    //
    // 1 tablet = 1g
    // ===================================================

    final RegExpMatch? packageMatch =
        _packageRelationPattern
            .firstMatch(
      allText,
    );

    if (packageMatch !=
        null) {
      final double? amount =
          _parseNumber(
        packageMatch.group(
          1,
        ),
      );

      final String? unit =
          packageMatch.group(
        2,
      );

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeEvidence(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
          source:
              'packageRelation',
        );
      }
    }

    return null;
  }

  // =====================================================
  // FIND NUTRIENT + VALUE PAIRS
  // =====================================================

  static Set<String> _findPairedNutrients(
    List<_OcrRow> rows,
  ) {
    final Set<String> paired =
        {};

    for (final _OcrRow row
        in rows) {
      final String rowText =
          _normalise(
        row.text,
      );

      final String? nutrient =
          _identifyNutrient(
        rowText,
      );

      if (nutrient ==
          null) {
        continue;
      }

      // One readable value column is enough.
      if (_nutritionValuePattern.hasMatch(
        rowText,
      )) {
        paired.add(
          nutrient,
        );

        continue;
      }

      // Unit printed in the name, numbers without units:
      // "Protein (g)   3.2   12.8"
      final String withoutHint =
          rowText.replaceAll(
        _unitHintPattern,
        ' ',
      );

      if (_unitHintPattern.hasMatch(
            rowText,
          ) &&
          RegExp(
            r'(?<![a-z])\d+(?:[.,]\d+)?(?![a-z%])',
          ).hasMatch(
            withoutHint,
          )) {
        paired.add(
          nutrient,
        );
      }
    }

    return paired;
  }

  // =====================================================
  // IDENTIFY NUTRIENT
  // =====================================================

  static String? _identifyNutrient(
    String rowText,
  ) {
    // Specific fat types must be checked before
    // generic "fat" / "lemak".
    const List<String> priorityOrder = [
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
        in priorityOrder) {
      final List<String>? keywords =
          _nutrientKeywords[
        nutrient
      ];

      if (keywords ==
          null) {
        continue;
      }

      if (_containsAny(
        rowText,
        keywords,
      )) {
        return nutrient;
      }
    }

    return null;
  }

  // =====================================================
  // PARSE NUMBER
  // =====================================================

  static double? _parseNumber(
    String? value,
  ) {
    if (value ==
        null) {
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
  // NORMALISE OCR TEXT
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

  // =====================================================
  // KEYWORD SEARCH
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
}