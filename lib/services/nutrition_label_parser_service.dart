import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/nutrition_label_data.dart';
import 'nutrition_table_parser.dart';

/// Platform OCR adapter. Table reconstruction is independently testable.
class NutritionLabelParserService {
  static Future<NutritionLabelData> parseImage(String imagePath) async {
    if (!await File(imagePath).exists()) {
      throw Exception('Nutrition label image could not be found.');
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      return parseRecognizedText(result);
    } finally {
      await recognizer.close();
    }
  }

  static NutritionLabelData parseRecognizedText(RecognizedText result) {
    final tokens = <NutritionOcrToken>[];
    final slopes = <double>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        // Correct modest camera tilt before grouping rows. Block enumeration
        // order is not the reading order of a multi-column table.
        if (line.cornerPoints.length >= 2) {
          final a = line.cornerPoints[0];
          final b = line.cornerPoints[1];
          if (b.x - a.x > line.boundingBox.height * 3) {
            final slope = (b.y - a.y) / (b.x - a.x);
            if (slope.abs() <= 0.25) slopes.add(slope);
          }
        }
        if (line.elements.isEmpty) {
          final box = line.boundingBox;
          tokens.add(
            NutritionOcrToken(
              text: line.text,
              left: box.left,
              top: box.top,
              right: box.right,
              bottom: box.bottom,
              confidence: line.confidence,
            ),
          );
        } else {
          for (final element in line.elements) {
            final box = element.boundingBox;
            tokens.add(
              NutritionOcrToken(
                text: element.text,
                left: box.left,
                top: box.top,
                right: box.right,
                bottom: box.bottom,
                confidence: element.confidence,
              ),
            );
          }
        }
      }
    }
    slopes.sort();
    return NutritionTableParser.parse(
      tokens,
      rawText: result.text,
      skew: slopes.isEmpty ? 0 : slopes[slopes.length ~/ 2],
    );
  }
}
