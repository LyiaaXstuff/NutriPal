import 'dart:io';
import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/nutrition_label_data.dart';

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

  double get centerX =>
      (left + right) / 2;

  double get centerY =>
      (top + bottom) / 2;

  double get width =>
      right - left;

  double get height =>
      bottom - top;
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
    );

    result.sort(
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

    double total =
        0;

    for (final _OcrToken token
        in tokens) {
      total +=
          token.centerY;
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
        .join(
          ' ',
        )
        .trim();
  }
}

// =======================================================
// DETECTED NUTRITION VALUE
// =======================================================

class _DetectedValue {
  final double amount;

  final String unit;

  final String rawText;

  final double x;

  const _DetectedValue({
    required this.amount,
    required this.unit,
    required this.rawText,
    required this.x,
  });
}

// =======================================================
// TABLE HEADER
// =======================================================

class _HeaderCandidate {
  final NutritionColumnBasis basis;

  final String label;

  final double x;

  const _HeaderCandidate({
    required this.basis,
    required this.label,
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
// PHYSICAL SERVING
// =======================================================

class _PhysicalServingResult {
  final double amount;

  final String name;

  const _PhysicalServingResult({
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
// NUTRITION LABEL PARSER
// =======================================================

class NutritionLabelParserService {
  // =====================================================
  // NUTRITION VALUE
  // =====================================================
  //
  // Supports:
  //
  // 13.7 g
  // 69 mg
  // 55 kcal
  // 230 kJ
  // 0 mcg
  // 10 IU
  //
  // =====================================================

  static final RegExp _valuePattern =
      RegExp(
    r'(?:<|≤)?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(kcal|kj|mcg|µg|ug|mg|g|iu)\b',
    caseSensitive:
        false,
  );

  // =====================================================
  // NUMBER WITHOUT UNIT
  // =====================================================

  static final RegExp _numberOnlyPattern =
      RegExp(
    r'^(?:<|≤)?\s*'
    r'(\d+(?:[.,]\d+)?)$',
    caseSensitive:
        false,
  );

  // =====================================================
  // UNIT WITHOUT NUMBER
  // =====================================================

  static final RegExp _unitOnlyPattern =
      RegExp(
    r'^(kcal|kj|mcg|µg|ug|mg|g|iu)$',
    caseSensitive:
        false,
  );

  // =====================================================
  // EXPLICIT SERVING SIZE
  // =====================================================
  //
  // Serving Size: 250 ml
  // Saiz Hidangan: 1 g
  //
  // =====================================================

  static final RegExp _servingSizePattern =
      RegExp(
    r'(?:serving\s*size|saiz\s*hidangan)'
    r'\s*[:\-]?\s*'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)\b',
    caseSensitive:
        false,
  );

  // =====================================================
  // SERVING SIZE FROM COLUMN HEADER
  // =====================================================
  //
  // Per Serving (250 ml)
  // Setiap Hidangan (1 g)
  //
  // =====================================================

  static final RegExp _servingHeaderSizePattern =
      RegExp(
    r'(?:per\s*(?:serving|serve)|setiap\s*hidangan)'
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
  // PHYSICAL FRACTION
  // =====================================================
  //
  // 1/2 bottle
  //
  // =====================================================

  static final RegExp _fractionServingPattern =
      RegExp(
    r'(\d+(?:[.,]\d+)?)'
    r'\s*/\s*'
    r'(\d+(?:[.,]\d+)?)'
    r'\s*'
    r'(bottle|bottles|pack|packs|piece|pieces|'
    r'tablet|tablets|capsule|capsules|sachet|sachets|'
    r'cup|cups|bar|bars)',
    caseSensitive:
        false,
  );

  // =====================================================
  // PHYSICAL COUNT
  // =====================================================
  //
  // 15 chips
  // 1 tablet
  //
  // =====================================================

  static final RegExp _countServingPattern =
      RegExp(
    r'(?:about\s*)?'
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(chip|chips|biscuit|biscuits|cracker|crackers|'
    r'tablet|tablets|capsule|capsules|piece|pieces|'
    r'sachet|sachets|bottle|bottles|cup|cups|'
    r'bar|bars)',
    caseSensitive:
        false,
  );

  // =====================================================
  // PACKAGE RELATION
  // =====================================================
  //
  // 1 g x 30 tablets
  //
  // =====================================================

  static final RegExp _packageRelationPattern =
      RegExp(
    r'(\d+(?:[.,]\d+)?)\s*'
    r'(mg|g|ml|l)'
    r'\s*[x×]\s*'
    r'\d+(?:[.,]\d+)?\s*'
    r'(tablet|tablets|capsule|capsules|piece|pieces|'
    r'sachet|sachets|bar|bars)',
    caseSensitive:
        false,
  );

  // =====================================================
  // MAIN PARSER
  // =====================================================

  static Future<NutritionLabelData> parseImage(
    String imagePath,
  ) async {
    final File imageFile =
        File(
      imagePath,
    );

    if (!await imageFile.exists()) {
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

      final RecognizedText recognizedText =
          await recognizer.processImage(
        inputImage,
      );

      final String rawText =
          recognizedText.text.trim();

      if (rawText.isEmpty) {
        return const NutritionLabelData(
          rawText:
              '',
        );
      }

      // =================================================
      // READ EVERY OCR ELEMENT WITH ITS POSITION
      // =================================================

      final List<_OcrToken> tokens =
          [];

      for (final TextBlock block
          in recognizedText.blocks) {
        for (final TextLine line
            in block.lines) {
          for (final TextElement element
              in line.elements) {
            final String text =
                element.text.trim();

            if (text.isEmpty) {
              continue;
            }

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
      // RECONSTRUCT HORIZONTAL TABLE ROWS
      // =================================================

      final List<_OcrRow> rows =
          _buildRows(
        tokens,
      );

      final String normalisedText =
          _normalise(
        rawText,
      );

      // =================================================
      // SERVING INFORMATION
      // =================================================

      final _ServingSizeResult?
          servingSize =
          _findServingSize(
        normalisedText,
        rows,
      );

      final double? servingsPerPackage =
          _findServingsPerPackage(
        normalisedText,
      );

      _PhysicalServingResult?
          physicalServing =
          _findPhysicalServing(
        rows,
      );

      final _PackageRelation?
          packageRelation =
          _findPackageRelation(
        normalisedText,
      );

      // =================================================
      // INFER PHYSICAL UNIT
      //
      // Example:
      //
      // Serving size = 1 g
      // Package relation = 1 g × 30 tablets
      //
      // Therefore:
      //
      // 1 serving = 1 tablet
      // =================================================

      if (physicalServing == null &&
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
          physicalServing =
              _PhysicalServingResult(
            amount:
                1,
            name:
                packageRelation
                    .itemName,
          );
        }
      }

      // =================================================
      // DETECT TABLE HEADERS
      // =================================================

      final List<_HeaderCandidate>
          headers =
          _detectHeaders(
        rows,
      );

      // =================================================
      // FIND NUMERICAL TABLE COLUMN POSITIONS
      // =================================================

      final double clusterTolerance =
          _calculateColumnClusterTolerance(
        tokens,
      );

      final List<double> valueColumnCenters =
          _detectValueColumnCenters(
        rows:
            rows,
        tolerance:
            clusterTolerance,
      );

      // =================================================
      // BUILD FINAL COLUMN DEFINITIONS
      // =================================================

      final List<NutritionColumn> columns =
          _buildColumns(
        headers:
            headers,
        valueColumnCenters:
            valueColumnCenters,
      );

      // =================================================
      // EXTRACT EVERY NUTRIENT ROW
      // =================================================

      final List<NutrientRow> nutrients =
          _extractNutrientRows(
        rows:
            rows,
        columns:
            columns,
      );

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
            physicalServing?.amount,

        servingUnitName:
            physicalServing?.name,

        columns:
            columns,

        nutrients:
            nutrients,

        rawText:
            rawText,
      );
    } finally {
      await recognizer.close();
    }
  }

  // =====================================================
  // BUILD ROWS
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
                  height >
                  0,
            )
            .toList()
          ..sort();

    double medianHeight =
        14;

    if (heights.isNotEmpty) {
      medianHeight =
          _median(
        heights,
      );
    }

    // Strict tolerance helps prevent one nutrient row
    // from merging with the next.
    final double tolerance =
        math.max(
      4.0,
      medianHeight *
          0.52,
    );

    final List<_OcrRow> rows =
        [];

    for (final _OcrToken token
        in sorted) {
      _OcrRow? closestRow;

      double closestDistance =
          double.infinity;

      for (final _OcrRow row
          in rows) {
        final double distance =
            (
              token.centerY -
                  row.centerY
            ).abs();

        if (distance <=
                tolerance &&
            distance <
                closestDistance) {
          closestDistance =
              distance;

          closestRow =
              row;
        }
      }

      if (closestRow ==
          null) {
        rows.add(
          _OcrRow(
            tokens: [
              token,
            ],
          ),
        );
      } else {
        closestRow.tokens.add(
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
  // DETECT TABLE HEADERS
  // =====================================================

  static List<_HeaderCandidate> _detectHeaders(
    List<_OcrRow> rows,
  ) {
    final List<_HeaderCandidate> result =
        [];

    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      // =================================================
      // PER 100 G
      // =================================================

      if (_isPer100gHeader(
        text,
      )) {
        final double? x =
            _find100UnitX(
          row:
              row,
          wantedUnit:
              'g',
        );

        if (x != null) {
          _addHeaderIfMissing(
            result,
            _HeaderCandidate(
              basis:
                  NutritionColumnBasis
                      .per100g,
              label:
                  'Per 100 g',
              x:
                  x,
            ),
          );
        }
      }

      // =================================================
      // PER 100 ML
      // =================================================

      if (_isPer100mlHeader(
        text,
      )) {
        final double? x =
            _find100UnitX(
          row:
              row,
          wantedUnit:
              'ml',
        );

        if (x != null) {
          _addHeaderIfMissing(
            result,
            _HeaderCandidate(
              basis:
                  NutritionColumnBasis
                      .per100ml,
              label:
                  'Per 100 ml',
              x:
                  x,
            ),
          );
        }
      }

      // =================================================
      // PER SERVING
      // =================================================

      if (_isPerServingHeader(
        text,
      )) {
        final double? x =
            _findServingHeaderX(
          row,
        );

        if (x != null) {
          _addHeaderIfMissing(
            result,
            _HeaderCandidate(
              basis:
                  NutritionColumnBasis
                      .perServing,
              label:
                  'Per serving',
              x:
                  x,
            ),
          );
        }
      }
    }

    result.sort(
      (
        _HeaderCandidate a,
        _HeaderCandidate b,
      ) {
        return a.x.compareTo(
          b.x,
        );
      },
    );

    return result;
  }

  // =====================================================
  // ADD HEADER ONCE
  // =====================================================

  static void _addHeaderIfMissing(
    List<_HeaderCandidate> headers,
    _HeaderCandidate newHeader,
  ) {
    final bool alreadyExists =
        headers.any(
      (
        _HeaderCandidate existing,
      ) {
        return existing.basis ==
            newHeader.basis;
      },
    );

    if (!alreadyExists) {
      headers.add(
        newHeader,
      );
    }
  }

  // =====================================================
  // PER SERVING HEADER?
  // =====================================================

  static bool _isPerServingHeader(
    String text,
  ) {
    final bool english =
        RegExp(
      r'\bper\s+(?:serving|serve|portion)\b',
      caseSensitive:
          false,
    ).hasMatch(
      text,
    );

    final bool malay =
        RegExp(
      r'\bsetiap\s+hidangan\b',
      caseSensitive:
          false,
    ).hasMatch(
      text,
    );

    return english ||
        malay;
  }

  // =====================================================
  // PER 100G HEADER?
  // =====================================================

  static bool _isPer100gHeader(
    String text,
  ) {
    return RegExp(
      r'\b(?:per|setiap)?\s*100\s*g\b',
      caseSensitive:
          false,
    ).hasMatch(
      text,
    );
  }

  // =====================================================
  // PER 100ML HEADER?
  // =====================================================

  static bool _isPer100mlHeader(
    String text,
  ) {
    return RegExp(
      r'\b(?:per|setiap)?\s*100\s*ml\b',
      caseSensitive:
          false,
    ).hasMatch(
      text,
    );
  }

  // =====================================================
  // FIND SERVING HEADER X
  // =====================================================

  static double? _findServingHeaderX(
    _OcrRow row,
  ) {
    final List<_OcrToken> tokens =
        row.sortedTokens;

    for (int i = 0;
        i <
            tokens.length;
        i++) {
      final String value =
          _normalise(
        tokens[i].text,
      );

      if (value.contains(
            'serving',
          ) ||
          value.contains(
            'serve',
          ) ||
          value.contains(
            'portion',
          ) ||
          value.contains(
            'hidangan',
          )) {
        if (i >
            0) {
          final String previous =
              _normalise(
            tokens[i - 1]
                .text,
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
  // FIND 100G / 100ML HEADER X
  // =====================================================

  static double? _find100UnitX({
    required _OcrRow row,
    required String wantedUnit,
  }) {
    final List<_OcrToken> tokens =
        row.sortedTokens;

    for (int i = 0;
        i <
            tokens.length;
        i++) {
      final String value =
          _normalise(
        tokens[i].text,
      );

      final String compact =
          value.replaceAll(
        ' ',
        '',
      );

      if (compact ==
              '100$wantedUnit' ||
          compact.contains(
            '100$wantedUnit',
          )) {
        return tokens[i]
            .centerX;
      }

      if (value ==
              '100' &&
          i + 1 <
              tokens.length) {
        final String next =
            _normalise(
          tokens[i + 1]
              .text,
        );

        if (next ==
            wantedUnit) {
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
  // VALUE COLUMN CLUSTER TOLERANCE
  // =====================================================

  static double _calculateColumnClusterTolerance(
    List<_OcrToken> tokens,
  ) {
    final List<double> heights =
        tokens
            .map(
              (
                _OcrToken token,
              ) =>
                  token.height,
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

    if (heights.isEmpty) {
      return 40;
    }

    return math.max(
      20,
      _median(
            heights,
          ) *
          2.2,
    );
  }

  // =====================================================
  // DETECT ACTUAL VALUE COLUMN CENTRES
  // =====================================================

  static List<double> _detectValueColumnCenters({
    required List<_OcrRow> rows,
    required double tolerance,
  }) {
    final List<double> xValues =
        [];

    for (final _OcrRow row
        in rows) {
      final String text =
          _normalise(
        row.text,
      );

      if (_isNonNutrientRow(
        text,
      )) {
        continue;
      }

      final List<_DetectedValue> values =
          _extractValuesFromRow(
        row,
      );

      for (final _DetectedValue value
          in values) {
        xValues.add(
          value.x,
        );
      }
    }

    if (xValues.isEmpty) {
      return [];
    }

    xValues.sort();

    final List<List<double>> clusters =
        [];

    for (final double x
        in xValues) {
      if (clusters.isEmpty) {
        clusters.add(
          [
            x,
          ],
        );

        continue;
      }

      final List<double> currentCluster =
          clusters.last;

      final double currentCenter =
          currentCluster.reduce(
                (
                  double a,
                  double b,
                ) =>
                    a + b,
              ) /
              currentCluster.length;

      if ((x - currentCenter).abs() <=
          tolerance) {
        currentCluster.add(
          x,
        );
      } else {
        clusters.add(
          [
            x,
          ],
        );
      }
    }

    // Prefer columns appearing on multiple nutrient rows.
    final List<double> reliableCenters =
        clusters
            .where(
              (
                List<double> cluster,
              ) =>
                  cluster.length >=
                  2,
            )
            .map(
              (
                List<double> cluster,
              ) =>
                  cluster.reduce(
                        (
                          double a,
                          double b,
                        ) =>
                            a + b,
                      ) /
                      cluster.length,
            )
            .toList();

    if (reliableCenters.isNotEmpty) {
      return reliableCenters;
    }

    // Fallback if OCR only found a small number of rows.
    return clusters
        .map(
          (
            List<double> cluster,
          ) =>
              cluster.reduce(
                    (
                      double a,
                      double b,
                    ) =>
                        a + b,
                  ) /
                  cluster.length,
        )
        .toList();
  }

  // =====================================================
  // BUILD FINAL TABLE COLUMNS
  // =====================================================

  static List<NutritionColumn> _buildColumns({
    required List<_HeaderCandidate> headers,
    required List<double> valueColumnCenters,
  }) {
    final List<NutritionColumn> result =
        [];

    final Set<int> usedCenters =
        {};

    // ===================================================
    // MATCH EACH HEADER TO THE NEAREST VALUE COLUMN
    // ===================================================

    for (final _HeaderCandidate header
        in headers) {
      double finalX =
          header.x;

      if (valueColumnCenters.isNotEmpty) {
        int? closestIndex;

        double closestDistance =
            double.infinity;

        for (int i = 0;
            i <
                valueColumnCenters.length;
            i++) {
          if (usedCenters.contains(
            i,
          )) {
            continue;
          }

          final double distance =
              (
                header.x -
                    valueColumnCenters[i]
              ).abs();

          if (distance <
              closestDistance) {
            closestDistance =
                distance;

            closestIndex =
                i;
          }
        }

        if (closestIndex !=
            null) {
          finalX =
              valueColumnCenters[
                closestIndex
              ];

          usedCenters.add(
            closestIndex,
          );
        }
      }

      result.add(
        NutritionColumn(
          id:
              _basisId(
            header.basis,
          ),
          label:
              header.label,
          basis:
              header.basis,
          xCenter:
              finalX,
        ),
      );
    }

    // ===================================================
    // PRESERVE UNKNOWN COLUMNS
    //
    // Do not silently discard a column just because
    // OCR failed to recognise its header.
    // ===================================================

    for (int i = 0;
        i <
            valueColumnCenters.length;
        i++) {
      if (usedCenters.contains(
        i,
      )) {
        continue;
      }

      result.add(
        NutritionColumn(
          id:
              'unknown_$i',
          label:
              'Detected column ${i + 1}',
          basis:
              NutritionColumnBasis
                  .unknown,
          xCenter:
              valueColumnCenters[i],
        ),
      );
    }

    result.sort(
      (
        NutritionColumn a,
        NutritionColumn b,
      ) {
        return a.xCenter.compareTo(
          b.xCenter,
        );
      },
    );

    return result;
  }

  // =====================================================
  // EXTRACT EVERY NUTRIENT ROW
  // =====================================================

  static List<NutrientRow> _extractNutrientRows({
    required List<_OcrRow> rows,
    required List<NutritionColumn> columns,
  }) {
    final List<NutrientRow> result =
        [];

    int order =
        0;

    for (final _OcrRow row
        in rows) {
      final String rowText =
          _normalise(
        row.text,
      );

      // Ignore table headers / serving information.
      if (_isNonNutrientRow(
        rowText,
      )) {
        continue;
      }

      final List<_DetectedValue> detectedValues =
          _extractValuesFromRow(
        row,
      );

      if (detectedValues.isEmpty) {
        continue;
      }

      if (columns.isEmpty) {
        continue;
      }

      // =================================================
      // CREATE EMPTY CELLS
      // =================================================

      final List<List<NutritionValue>>
          valuesByColumn =
          List<List<NutritionValue>>.generate(
        columns.length,
        (
          int index,
        ) =>
            <NutritionValue>[],
      );

      // =================================================
      // ASSIGN EACH VALUE TO NEAREST COLUMN
      // =================================================

      for (final _DetectedValue detected
          in detectedValues) {
        final int columnIndex =
            _nearestColumnIndex(
          x:
              detected.x,
          columns:
              columns,
        );

        if (columnIndex <
            0) {
          continue;
        }

        valuesByColumn[
          columnIndex
        ].add(
          NutritionValue(
            amount:
                detected.amount,
            unit:
                detected.unit,
            rawText:
                detected.rawText,
          ),
        );
      }

      final bool hasAssignedValue =
          valuesByColumn.any(
        (
          List<NutritionValue> values,
        ) =>
            values.isNotEmpty,
      );

      if (!hasAssignedValue) {
        continue;
      }

      // =================================================
      // EXTRACT NUTRIENT NAME
      // =================================================

      final String? nutrientName =
          _extractNutrientName(
        row:
            row,
        detectedValues:
            detectedValues,
      );

      if (nutrientName ==
          null) {
        continue;
      }

      result.add(
        NutrientRow(
          name:
              nutrientName,
          order:
              order,
          valuesByColumn:
              valuesByColumn,
        ),
      );

      order++;
    }

    return result;
  }

  // =====================================================
  // EXTRACT DYNAMIC NUTRIENT NAME
  // =====================================================

  static String? _extractNutrientName({
    required _OcrRow row,
    required List<_DetectedValue> detectedValues,
  }) {
    if (detectedValues.isEmpty) {
      return null;
    }

    double firstValueX =
        detectedValues.first.x;

    for (final _DetectedValue value
        in detectedValues) {
      if (value.x <
          firstValueX) {
        firstValueX =
            value.x;
      }
    }

    final List<String> nutrientNameTokens =
        [];

    for (final _OcrToken token
        in row.sortedTokens) {
      // Nutrient name should appear before first
      // numerical nutrition column.
      if (token.centerX >=
          firstValueX) {
        continue;
      }

      final String cleaned =
          _cleanNameToken(
        token.text,
      );

      if (cleaned.isEmpty) {
        continue;
      }

      if (_isHeaderWord(
        cleaned,
      )) {
        continue;
      }

      nutrientNameTokens.add(
        token.text,
      );
    }

    String name =
        nutrientNameTokens
            .join(
              ' ',
            )
            .trim();

    // ===================================================
    // FALLBACK
    //
    // Sometimes OCR detects:
    //
    // "Sodium 69mg"
    //
    // as one element.
    // ===================================================

    if (name.isEmpty) {
      final RegExpMatch? firstValueMatch =
          _valuePattern
              .firstMatch(
        row.text,
      );

      if (firstValueMatch !=
          null) {
        name =
            row.text
                .substring(
                  0,
                  firstValueMatch.start,
                )
                .trim();
      }
    }

    name =
        name
            .replaceAll(
              RegExp(
                r'^[•·\-\–\—:\s]+',
              ),
              '',
            )
            .replaceAll(
              RegExp(
                r'[•·\-\–\—:\s]+$',
              ),
              '',
            )
            .trim();

    if (name.length <
        2) {
      return null;
    }

    if (_isInvalidNutrientName(
      name,
    )) {
      return null;
    }

    return _normaliseDisplayName(
      name,
    );
  }

  // =====================================================
  // EXTRACT VALUES FROM ROW
  // =====================================================

  static List<_DetectedValue> _extractValuesFromRow(
    _OcrRow row,
  ) {
    final List<_DetectedValue> result =
        [];

    final List<_OcrToken> tokens =
        row.sortedTokens;

    int i =
        0;

    while (i <
        tokens.length) {
      final _OcrToken token =
          tokens[i];

      final String tokenText =
          token.text.trim();

      // =================================================
      // CASE 1
      //
      // Number + unit in same OCR element.
      //
      // 13.7g
      // 69mg
      // 55kcal
      // =================================================

      final List<RegExpMatch> matches =
          _valuePattern
              .allMatches(
                tokenText,
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

          if (amount ==
                  null ||
              unit ==
                  null) {
            continue;
          }

          result.add(
            _DetectedValue(
              amount:
                  amount,
              unit:
                  _normaliseUnit(
                unit,
              ),
              rawText:
                  match.group(
                        0,
                      ) ??
                      tokenText,
              x:
                  token.centerX,
            ),
          );
        }

        i++;

        continue;
      }

      // =================================================
      // CASE 2
      //
      // Number and unit separated by OCR.
      //
      // "13.7" "g"
      // =================================================

      final RegExpMatch? numberMatch =
          _numberOnlyPattern
              .firstMatch(
        tokenText,
      );

      if (numberMatch !=
              null &&
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

        if (unitMatch !=
            null) {
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

          if (amount !=
                  null &&
              unit !=
                  null) {
            result.add(
              _DetectedValue(
                amount:
                    amount,
                unit:
                    _normaliseUnit(
                  unit,
                ),
                rawText:
                    '${token.text} ${nextToken.text}',
                x:
                    (
                          token.centerX +
                              nextToken.centerX
                        ) /
                        2,
              ),
            );

            i +=
                2;

            continue;
          }
        }
      }

      i++;
    }

    return result;
  }

  // =====================================================
  // FIND NEAREST COLUMN
  // =====================================================

  static int _nearestColumnIndex({
    required double x,
    required List<NutritionColumn> columns,
  }) {
    if (columns.isEmpty) {
      return -1;
    }

    int bestIndex =
        0;

    double bestDistance =
        (
          x -
              columns.first.xCenter
        ).abs();

    for (int i = 1;
        i <
            columns.length;
        i++) {
      final double distance =
          (
            x -
                columns[i]
                    .xCenter
          ).abs();

      if (distance <
          bestDistance) {
        bestDistance =
            distance;

        bestIndex =
            i;
      }
    }

    return bestIndex;
  }

  // =====================================================
  // NON-NUTRIENT ROW
  // =====================================================

  static bool _isNonNutrientRow(
    String text,
  ) {
    final String value =
        _normalise(
      text,
    );

    if (value.isEmpty) {
      return true;
    }

    if (_isPerServingHeader(
      value,
    )) {
      return true;
    }

    if (_isPer100gHeader(
      value,
    )) {
      return true;
    }

    if (_isPer100mlHeader(
      value,
    )) {
      return true;
    }

    const List<String> blockedPhrases = [
      'nutrition information',
      'nutritional information',
      'nutrition facts',
      'nutrition fact',
      'maklumat pemakanan',
      'fakta pemakanan',
      'serving size',
      'saiz hidangan',
      'servings per package',
      'servings per pack',
      'servings per container',
      'servings per bottle',
      'hidangan setiap bungkusan',
      'hidangan setiap pek',
      'net weight',
      'berat bersih',
      'daily value',
      '% daily value',
      'nilai harian',
      'recommended nutrient intake',
      '% rni',
      '% dv',
    ];

    for (final String phrase
        in blockedPhrases) {
      if (value.contains(
        phrase,
      )) {
        return true;
      }
    }

    return false;
  }

  // =====================================================
  // INVALID NUTRIENT NAME
  // =====================================================

  static bool _isInvalidNutrientName(
    String name,
  ) {
    final String value =
        _normalise(
      name,
    );

    const Set<String> invalid = {
      'setiap',
      'per',
      'hidangan',
      'serving',
      'serve',
      'portion',
      '100g',
      '100 g',
      '100ml',
      '100 ml',
      'daily value',
      'nilai harian',
      'rni',
      'dv',
    };

    if (invalid.contains(
      value,
    )) {
      return true;
    }

    // Purely numeric text is not a nutrient name.
    if (RegExp(
      r'^[\d.,%]+$',
    ).hasMatch(
      value,
    )) {
      return true;
    }

    return false;
  }

  // =====================================================
  // HEADER WORD
  // =====================================================

  static bool _isHeaderWord(
    String value,
  ) {
    final String text =
        _normalise(
      value,
    );

    const Set<String> headerWords = {
      'setiap',
      'per',
      'serving',
      'serve',
      'portion',
      'hidangan',
      'daily',
      'value',
      'nilai',
      'harian',
      'rni',
      'dv',
      '%',
    };

    return headerWords.contains(
      text,
    );
  }

  // =====================================================
  // FIND SERVING SIZE
  // =====================================================

  static _ServingSizeResult? _findServingSize(
    String allText,
    List<_OcrRow> rows,
  ) {
    // ===================================================
    // EXPLICIT SERVING SIZE
    // ===================================================

    final RegExpMatch? explicit =
        _servingSizePattern
            .firstMatch(
      allText,
    );

    if (explicit !=
        null) {
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

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeResult(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
        );
      }
    }

    // ===================================================
    // SERVING SIZE FROM TABLE HEADER
    // ===================================================

    final RegExpMatch? header =
        _servingHeaderSizePattern
            .firstMatch(
      allText,
    );

    if (header !=
        null) {
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

      if (amount !=
              null &&
          unit !=
              null) {
        return _ServingSizeResult(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
        );
      }
    }

    // ===================================================
    // CHECK EACH OCR ROW TOO
    // ===================================================

    for (final _OcrRow row
        in rows) {
      final String rowText =
          _normalise(
        row.text,
      );

      final RegExpMatch? match =
          _servingSizePattern
                  .firstMatch(
                rowText,
              ) ??
              _servingHeaderSizePattern
                  .firstMatch(
                rowText,
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
        return _ServingSizeResult(
          amount:
              amount,
          unit:
              unit.toLowerCase(),
        );
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

    if (match ==
        null) {
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

  static _PhysicalServingResult? _findPhysicalServing(
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

      if (fraction !=
          null) {
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

        final String? item =
            fraction.group(
          3,
        );

        if (numerator !=
                null &&
            denominator !=
                null &&
            denominator !=
                0 &&
            item !=
                null) {
          return _PhysicalServingResult(
            amount:
                numerator /
                    denominator,
            name:
                _singularise(
              item,
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

      if (count !=
          null) {
        final double? amount =
            _parseNumber(
          count.group(
            1,
          ),
        );

        final String? item =
            count.group(
          2,
        );

        if (amount !=
                null &&
            item !=
                null) {
          return _PhysicalServingResult(
            amount:
                amount,
            name:
                _singularise(
              item,
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

  static _PackageRelation? _findPackageRelation(
    String text,
  ) {
    final RegExpMatch? match =
        _packageRelationPattern
            .firstMatch(
      text,
    );

    if (match ==
        null) {
      return null;
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

    final String? item =
        match.group(
      3,
    );

    if (amount ==
            null ||
        unit ==
            null ||
        item ==
            null) {
      return null;
    }

    return _PackageRelation(
      amountPerUnit:
          amount,
      measurementUnit:
          unit.toLowerCase(),
      itemName:
          _singularise(
        item,
      ),
    );
  }

  // =====================================================
  // COLUMN BASIS ID
  // =====================================================

  static String _basisId(
    NutritionColumnBasis basis,
  ) {
    switch (basis) {
      case NutritionColumnBasis.perServing:
        return 'per_serving';

      case NutritionColumnBasis.per100g:
        return 'per_100g';

      case NutritionColumnBasis.per100ml:
        return 'per_100ml';

      case NutritionColumnBasis.unknown:
        return 'unknown';
    }
  }

  // =====================================================
  // DISPLAY NAME
  // =====================================================

  static String _normaliseDisplayName(
    String text,
  ) {
    return text
        .replaceAll(
          RegExp(
            r'\s+',
          ),
          ' ',
        )
        .trim();
  }

  // =====================================================
  // NORMALISE UNIT
  // =====================================================

  static String _normaliseUnit(
    String unit,
  ) {
    final String value =
        unit.toLowerCase();

    if (value ==
            'µg' ||
        value ==
            'ug') {
      return 'mcg';
    }

    if (value ==
        'kj') {
      return 'kJ';
    }

    if (value ==
        'iu') {
      return 'IU';
    }

    return value;
  }

  // =====================================================
  // CLEAN NUTRIENT NAME TOKEN
  // =====================================================

  static String _cleanNameToken(
    String text,
  ) {
    return _normalise(
      text
          .replaceAll(
            RegExp(
              r'^[•·:\-\–\—]+',
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'[•·:\-\–\—]+$',
            ),
            '',
          ),
    );
  }

  // =====================================================
  // SINGULARISE PHYSICAL UNIT
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
      'bars':
          'bar',
    };

    final String text =
        value.toLowerCase();

    return replacements[text] ??
        text;
  }

  // =====================================================
  // MEDIAN
  // =====================================================

  static double _median(
    List<double> sortedValues,
  ) {
    if (sortedValues.isEmpty) {
      return 0;
    }

    final int middle =
        sortedValues.length ~/
            2;

    if (sortedValues.length.isOdd) {
      return sortedValues[
        middle
      ];
    }

    return (
          sortedValues[middle - 1] +
              sortedValues[middle]
        ) /
        2;
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