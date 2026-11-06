import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../models/nutrition_label_data.dart';
import 'nutrition_table_parser.dart';
import 'ocr_geometry.dart';

// =======================================================
// ON-DEVICE READING RESULT
// =======================================================

class OnDeviceLabelReading {
  // Table read by ML Kit + NutritionTableParser.
  final NutritionLabelData data;

  // JPEG of the nutrition table only (or of the whole photo
  // when the table could not be located). This is what is
  // sent for AI reading, so nothing outside the table is
  // shared.
  final Uint8List tableImage;

  // True when [tableImage] is cropped to the table.
  final bool tableImageIsCropped;

  // OCR text of the table area, used to verify AI values.
  final String tableText;

  const OnDeviceLabelReading({
    required this.data,
    required this.tableImage,
    required this.tableImageIsCropped,
    required this.tableText,
  });
}

// =======================================================
// NUTRITION LABEL PARSER SERVICE
// =======================================================
//
// 1. OCR the whole photo only to FIND the nutrition table.
// 2. Crop the photo to the table border (plus a small
//    margin) and OCR that crop. Only text inside the table
//    is read from here on.
// 3. Parse the cropped table. The full-photo parse is used
//    only if the crop could not be made or read.
//
// =======================================================

class NutritionLabelParserService {
  NutritionLabelParserService._();

  /// Prints a step-by-step parse log in debug builds.
  static bool debugLogging = kDebugMode;

  // Crops narrower than this are enlarged for OCR.
  static const int _targetOcrWidth = 1600;

  // Longest side of the image sent for AI reading.
  static const int _maxAiImageSide = 2000;

  // =====================================================
  // SIMPLE ENTRY (kept for existing callers)
  // =====================================================

  static Future<NutritionLabelData> parseImage(String imagePath) async {
    return (await readLabel(imagePath)).data;
  }

  // =====================================================
  // FULL ENTRY
  // =====================================================

  static Future<OnDeviceLabelReading> readLabel(String imagePath) async {
    final File sourceFile = File(imagePath);

    if (!await sourceFile.exists()) {
      throw Exception('Nutrition label image could not be found.');
    }

    final TextRecognizer recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    Directory? temporaryDirectory;

    try {
      // =================================================
      // PASS 1: WHOLE PHOTO (to locate the table)
      // =================================================

      final RecognizedText fullText = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );

      final List<OcrTextLine> fullLines = OcrGeometry.linesFrom(fullText);

      final double fullSkew = OcrGeometry.estimateSkew(fullText);

      final StringBuffer? fullLog = debugLogging ? StringBuffer() : null;

      fullLog?.write(OcrGeometry.describe(fullLines));

      final List<OcrBounds> found = <OcrBounds>[];

      final NutritionLabelData fullResult = fullLines.isEmpty
          ? const NutritionLabelData(rawText: '')
          : NutritionTableParser.parse(
              fullLines,
              rawText: fullText.text,
              skewRadians: fullSkew,
              debug: fullLog,
              boundsOut: found,
            );

      final OcrBounds? bounds =
          found.isNotEmpty
          ? found.first
          : NutritionTableParser.tableBounds(fullLines, skewRadians: fullSkew);

      // =================================================
      // CROP TO THE TABLE
      // =================================================

      temporaryDirectory = await Directory.systemTemp.createTemp(
        'nutripal_nutrition_ocr_',
      );

      final String cropPath = '${temporaryDirectory.path}'
          '${Platform.pathSeparator}'
          'nutrition_table.jpg';

      final _PreparedImages prepared = await _prepareImages(
        sourcePath: imagePath,
        ocrCropPath: cropPath,
        bounds: bounds,
      );

      // =================================================
      // PASS 2: TABLE ONLY
      // =================================================

      NutritionLabelData? cropResult;
      StringBuffer? cropLog;
      String cropText = '';

      if (prepared.cropWritten) {
        final RecognizedText recognized = await recognizer.processImage(
          InputImage.fromFilePath(cropPath),
        );

        cropText = recognized.text;

        if (recognized.text.trim().isNotEmpty) {
          cropLog = debugLogging ? StringBuffer() : null;

          final List<OcrTextLine> cropLines = OcrGeometry.linesFrom(recognized);

          cropLog?.write(OcrGeometry.describe(cropLines));

          cropResult = NutritionTableParser.parse(
            cropLines,
            rawText: recognized.text,
            skewRadians: OcrGeometry.estimateSkew(recognized),
            debug: cropLog,
          );
        }
      }

      // =================================================
      // CHOOSE: table-only pass unless it found nothing
      // =================================================

      final bool useCrop = cropResult != null && cropResult.nutrients.isNotEmpty;

      NutritionLabelData data;

      if (cropResult != null && useCrop) {
        data = _fillServingGaps(cropResult, fullResult);
      } else {
        data = fullResult;
      }

      if (debugLogging) {
        _log('===== NutriPal OCR: whole photo (used to find the table) =====');
        _log(fullLog.toString());

        if (cropLog != null) {
          _log('===== NutriPal OCR: table only =====');
          _log(cropLog.toString());
        }

        _log('===== NutriPal OCR: using ${useCrop ? 'table-only' : 'whole-photo'} pass =====');
      }

      return OnDeviceLabelReading(
        data: data,
        tableImage: prepared.aiImage,
        tableImageIsCropped: prepared.cropWritten,
        tableText: useCrop ? cropText : fullText.text,
      );
    } finally {
      await recognizer.close();

      if (temporaryDirectory != null) {
        try {
          if (await temporaryDirectory.exists()) {
            await temporaryDirectory.delete(recursive: true);
          }
        } catch (_) {
          // Ignore temporary-file cleanup failure.
        }
      }
    }
  }

  // =====================================================
  // SERVING DETAILS FROM THE WHOLE-PHOTO PASS
  //
  // Only serving size / servings per pack, which are
  // printed inside the table's header area anyway.
  // =====================================================

  static NutritionLabelData _fillServingGaps(
    NutritionLabelData chosen,
    NutritionLabelData other,
  ) {
    final bool takeSize = !chosen.hasServingSize && other.hasServingSize;

    final bool takePhysical =
        chosen.servingUnitName == null && other.servingUnitName != null;

    final bool takePackage =
        chosen.servingsPerPackage == null && other.servingsPerPackage != null;

    if (!takeSize && !takePhysical && !takePackage) return chosen;

    return chosen.copyWith(
      servingSizeAmount: takeSize ? other.servingSizeAmount : null,
      servingSizeUnit: takeSize ? other.servingSizeUnit : null,
      servingsPerPackage: takePackage ? other.servingsPerPackage : null,
      servingUnitAmount: takePhysical ? other.servingUnitAmount : null,
      servingUnitName: takePhysical ? other.servingUnitName : null,
    );
  }

  // =====================================================
  // IMAGES (background isolate: decoding a 12 MP photo
  // on the UI thread would freeze the app)
  // =====================================================
  //
  // Writes the OCR crop (enlarged if small) and returns a
  // JPEG for AI reading: the table crop, or the whole
  // photo when the table could not be located.
  // =====================================================

  static Future<_PreparedImages> _prepareImages({
    required String sourcePath,
    required String ocrCropPath,
    required OcrBounds? bounds,
  }) async {
    final bool hasBounds = bounds != null;
    final double left = bounds?.left ?? 0;
    final double top = bounds?.top ?? 0;
    final double right = bounds?.right ?? 0;
    final double bottom = bounds?.bottom ?? 0;

    return Isolate.run<_PreparedImages>(() {
      final Uint8List bytes = File(sourcePath).readAsBytesSync();

      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        return _PreparedImages(cropWritten: false, aiImage: bytes);
      }

      // ML Kit reports coordinates for the upright image.
      image = img.bakeOrientation(image);

      img.Image? crop;

      if (hasBounds) {
        final int x = left.floor().clamp(0, image.width - 1);
        final int y = top.floor().clamp(0, image.height - 1);
        final int r = right.ceil().clamp(x + 1, image.width);
        final int b = bottom.ceil().clamp(y + 1, image.height);

        if (r - x > 10 && b - y > 10) {
          crop = img.copyCrop(image, x: x, y: y, width: r - x, height: b - y);
        }
      }

      bool cropWritten = false;

      if (crop != null) {
        img.Image forOcr = crop;

        if (forOcr.width < _targetOcrWidth) {
          final double scale = math.min(2.5, _targetOcrWidth / forOcr.width);

          forOcr = img.copyResize(
            forOcr,
            width: (forOcr.width * scale).round(),
            interpolation: img.Interpolation.cubic,
          );
        }

        File(ocrCropPath).writeAsBytesSync(
          img.encodeJpg(forOcr, quality: 95),
          flush: true,
        );

        cropWritten = true;
      }

      img.Image forAi = crop ?? image;

      final int longest = math.max(forAi.width, forAi.height);

      if (longest > _maxAiImageSide) {
        final double scale = _maxAiImageSide / longest;

        forAi = img.copyResize(
          forAi,
          width: (forAi.width * scale).round(),
          height: (forAi.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }

      return _PreparedImages(
        cropWritten: cropWritten,
        aiImage: img.encodeJpg(forAi, quality: 90),
      );
    });
  }

  // =====================================================
  // LOG (debugPrint truncates long strings, so split)
  // =====================================================

  static void _log(String text) {
    for (final String line in text.split('\n')) {
      if (line.trim().isNotEmpty) debugPrint(line);
    }
  }
}

class _PreparedImages {
  final bool cropWritten;
  final Uint8List aiImage;

  const _PreparedImages({
    required this.cropWritten,
    required this.aiImage,
  });
}
