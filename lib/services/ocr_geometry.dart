import 'dart:math' as math;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'nutrition_table_parser.dart';

// =======================================================
// OCR GEOMETRY HELPERS
// =======================================================
//
// Converts ML Kit results into the plain OcrTextLine /
// OcrWord types used by NutritionTableParser, and
// estimates how much the photo is tilted.
//
// =======================================================

class OcrGeometry {
  OcrGeometry._();

  // =====================================================
  // ML KIT -> PARSER LINES
  // =====================================================

  static List<OcrTextLine> linesFrom(RecognizedText recognized) {
    final List<OcrTextLine> result = <OcrTextLine>[];

    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        // Sideways text ("CARA HIDANGAN" up the edge of the
        // table, barcode digits) is never part of a row.
        if (_isSideways(line.cornerPoints)) continue;

        final List<OcrWord> words = <OcrWord>[];

        for (final TextElement element in line.elements) {
          final String text = element.text.trim();

          if (text.isEmpty) continue;

          final rect = element.boundingBox;

          words.add(
            OcrWord(
              text: text,
              left: rect.left,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
            ),
          );
        }

        // Rare: a line without elements.
        if (words.isEmpty && line.text.trim().isNotEmpty) {
          final rect = line.boundingBox;

          words.add(
            OcrWord(
              text: line.text.trim(),
              left: rect.left,
              top: rect.top,
              right: rect.right,
              bottom: rect.bottom,
            ),
          );
        }

        if (words.isNotEmpty) result.add(OcrTextLine(words));
      }
    }

    return result;
  }

  static bool _isSideways(List<math.Point<int>> corners) {
    if (corners.length < 2) return false;

    final double dx = (corners[1].x - corners[0].x).toDouble();
    final double dy = (corners[1].y - corners[0].y).toDouble();

    if (dx == 0 && dy == 0) return false;

    // More than ~35 degrees from horizontal.
    return math.atan2(dy, dx).abs() > 0.6;
  }

  // =====================================================
  // DEBUG DUMP
  // =====================================================
  //
  // One line per OCR line: position and text. Paste this
  // from the console to turn a real scan into a test.
  // =====================================================

  static String describe(List<OcrTextLine> lines) {
    final StringBuffer buffer = StringBuffer();

    final List<OcrTextLine> sorted = List<OcrTextLine>.of(lines)
      ..sort((OcrTextLine a, OcrTextLine b) => a.centerY.compareTo(b.centerY));

    for (final OcrTextLine line in sorted) {
      buffer.writeln(
        '[ocr] ${line.words.map((OcrWord w) => '${w.text}@${w.left.round()},${w.top.round()},${w.right.round()},${w.bottom.round()}').join(' ')}',
      );
    }

    return buffer.toString();
  }

  // =====================================================
  // SKEW ESTIMATE
  // =====================================================
  //
  // ML Kit corner points run clockwise from the top-left
  // corner of each line. The angle of the top edge of
  // every long line is measured and the length-weighted
  // median is used.
  //
  // Returns radians. Positive = text runs downhill to the
  // right. 0 when the photo is straight enough.
  // =====================================================

  static double estimateSkew(RecognizedText recognized) {
    final List<List<double>> samples = <List<double>>[];

    for (final TextBlock block in recognized.blocks) {
      for (final TextLine line in block.lines) {
        final List<math.Point<int>> corners = line.cornerPoints;

        if (corners.length < 2) continue;

        final double dx = (corners[1].x - corners[0].x).toDouble();
        final double dy = (corners[1].y - corners[0].y).toDouble();

        final double length = math.sqrt(dx * dx + dy * dy);

        final double height = line.boundingBox.height;

        // Short lines ("5g") give noisy angles.
        if (dx <= 0 || length < 3 * height) continue;

        final double angle = math.atan2(dy, dx);

        // Ignore vertical / rotated text.
        if (angle.abs() > 0.35) continue;

        samples.add(<double>[angle, length]);
      }
    }

    if (samples.length < 3) return 0;

    samples.sort((List<double> a, List<double> b) => a[0].compareTo(b[0]));

    final double totalWeight =
        samples.fold<double>(0, (double sum, List<double> s) => sum + s[1]);

    double running = 0;
    double median = 0;

    for (final List<double> sample in samples) {
      running += sample[1];

      if (running >= totalWeight / 2) {
        median = sample[0];
        break;
      }
    }

    // Below ~0.5 degrees is not worth correcting.
    if (median.abs() < 0.009) return 0;

    return median;
  }
}
