// =======================================================
// NUTRITION TABLE PARSER
// =======================================================
//
// Pure Dart (no Flutter / ML Kit imports) so it can be
// unit-tested with `flutter test` using synthetic OCR
// layouts.
//
// Input:  OCR lines + words with bounding boxes.
// Output: NutritionLabelData (columns + nutrient rows).
//
// Pipeline:
//
//   1. Deskew word positions (tilted photos).
//   2. Measure the typical text height. Every distance
//      threshold below is a multiple of it, so the parser
//      works the same on a 600 px crop or a 4000 px photo.
//   3. Read serving information (size, servings/pack,
//      physical serving such as "2 keping").
//   4. Find where nutrient rows start (first nutrient name
//      with a value on the same row) and end (footer).
//   5. Read column headers only above the first nutrient
//      row ("Per serving", "Setiap 100 g", "Per 30 g").
//   6. Collect values, including numbers whose unit is
//      printed in the name, e.g. "Protein (g)  3.2  12.8".
//   7. Group values into columns by horizontal overlap.
//   8. Read nutrient names left of the first column and
//      merge bilingual / wrapped names.
//   9. Assign each value to the nearest name row and
//      nearest column.
//  10. Fix units, energy kJ/kcal pairs, and cross-check
//      per-serving vs per-100 g values with the serving
//      size (catches OCR errors like "5.59" for "5.5g").
//
// =======================================================

import 'dart:math' as math;

import '../models/nutrition_label_data.dart';

// =======================================================
// PUBLIC OCR INPUT TYPES
// =======================================================

class OcrWord {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;

  double get height => bottom - top;

  double get centerX => (left + right) / 2;

  double get centerY => (top + bottom) / 2;
}

class OcrTextLine {
  final List<OcrWord> words;

  OcrTextLine(List<OcrWord> words)
      : words = List<OcrWord>.of(words)
          ..sort((OcrWord a, OcrWord b) => a.left.compareTo(b.left));

  String get text => words.map((OcrWord w) => w.text).join(' ');

  double get left => words.map((OcrWord w) => w.left).reduce(math.min);

  double get right => words.map((OcrWord w) => w.right).reduce(math.max);

  double get top => words.map((OcrWord w) => w.top).reduce(math.min);

  double get bottom => words.map((OcrWord w) => w.bottom).reduce(math.max);

  double get centerY => (top + bottom) / 2;
}

class OcrBounds {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const OcrBounds({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;

  double get height => bottom - top;
}

// =======================================================
// DIAGNOSTICS (used by the scan check)
// =======================================================

class NutritionTableDiagnostics {
  // Box around the table content (title, headings, names,
  // values) in ORIGINAL image coordinates, no margin.
  final OcrBounds contentBounds;

  // Rows of values that have no readable nutrient name,
  // e.g. because the names are cut off by the photo edge.
  final int unnamedValueRows;

  final bool titleFound;

  // Typical text height in pixels.
  final double textHeight;

  const NutritionTableDiagnostics({
    required this.contentBounds,
    required this.unnamedValueRows,
    required this.titleFound,
    required this.textHeight,
  });
}

// =======================================================
// INTERNAL TYPES
// =======================================================

class _Tok {
  final String text;
  final double left;
  final double right;
  final double cy;

  const _Tok({
    required this.text,
    required this.left,
    required this.right,
    required this.cy,
  });
}

class _Parsed {
  final double amount;
  final String unit;

  const _Parsed(this.amount, this.unit);
}

class _Value {
  double amount;
  String unit; // '?' when OCR did not show a unit.
  final String raw;
  final double left;
  final double right;
  final double cy;
  final bool explicitUnit;

  _Value({
    required this.amount,
    required this.unit,
    required this.raw,
    required this.left,
    required this.right,
    required this.cy,
    required this.explicitUnit,
  });

  double get cx => (left + right) / 2;
}

class _Header {
  final NutritionColumnBasis basis;
  final String label;
  final double x;
  final double? servingAmount;
  final String? servingUnit;

  const _Header({
    required this.basis,
    required this.label,
    required this.x,
    this.servingAmount,
    this.servingUnit,
  });
}

class _Column {
  final double left;
  final double right;
  final double center;
  final int count;
  final int explicitCount;

  NutritionColumnBasis basis = NutritionColumnBasis.unknown;
  String label = '';
  bool headed = false;

  _Column({
    required this.left,
    required this.right,
    required this.center,
    required this.count,
    required this.explicitCount,
  });

  double distanceTo(double x) {
    if (x < left) return left - x;
    if (x > right) return x - right;
    return 0;
  }
}

class _Anchor {
  String name;
  double left;
  double right;
  double top;
  double bottom;
  String? key;
  String? unit;

  _Anchor({
    required this.name,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.key,
    required this.unit,
  });

  double get cy => (top + bottom) / 2;

  double distanceTo(double y) {
    if (y < top) return top - y;
    if (y > bottom) return y - bottom;
    return 0;
  }
}

class _Row {
  final String text;
  final double cy;

  const _Row(this.text, this.cy);
}

class _Serving {
  double? amount;
  String? unit;
  double? perPackage;
  double? unitAmount;
  String? unitName;
}

// =======================================================
// PARSER
// =======================================================

class NutritionTableParser {
  NutritionTableParser._();

  // =====================================================
  // MAIN ENTRY
  // =====================================================

  static NutritionLabelData parse(
    List<OcrTextLine> input, {
    String rawText = '',
    double skewRadians = 0,
    StringBuffer? debug,
    List<OcrBounds>? boundsOut,
    List<NutritionTableDiagnostics>? diagnosticsOut,
  }) {
    // Corrections made while reading, shown to the user and
    // used to decide whether an AI check is needed.
    final List<String> notes = <String>[];

    List<OcrTextLine> lines = _deskew(
      input.where((OcrTextLine l) => l.words.isNotEmpty).toList(),
      skewRadians,
    )..sort(
        (OcrTextLine a, OcrTextLine b) => a.centerY.compareTo(b.centerY),
      );

    if (lines.isEmpty) {
      return NutritionLabelData(rawText: rawText);
    }

    final double h0 = _medianHeight(lines);

    // Vertical text ("CARA HIDANGAN" printed sideways,
    // barcode digits) produces very tall word boxes that
    // would swallow several table rows. Drop it.
    lines = _withoutVerticalText(lines, h0);

    if (lines.isEmpty) {
      return NutritionLabelData(rawText: rawText);
    }

    final double h = _medianHeight(lines);

    debug?.writeln(
      '[parser] lines=${lines.length} textHeight=${h.toStringAsFixed(1)} '
      'skew=${(skewRadians * 180 / math.pi).toStringAsFixed(2)}deg',
    );

    // ---------------------------------------------------
    // SERVING INFORMATION
    // ---------------------------------------------------

    final List<_Row> rows = _visualRows(lines, h);

    final _Serving serving = _readServing(rows);

    // ---------------------------------------------------
    // VALUES ON EVERY LINE
    // ---------------------------------------------------

    final Map<OcrTextLine, List<_Value>> valuesByLine =
        <OcrTextLine, List<_Value>>{
      for (final OcrTextLine line in lines) line: _valuesInLine(line),
    };

    // ---------------------------------------------------
    // WHERE DO NUTRIENT ROWS START / END?
    // ---------------------------------------------------

    OcrTextLine? title;

    for (final OcrTextLine line in lines) {
      if (_isTitle(_norm(line.text))) {
        title = line;
        break;
      }
    }

    double? firstNutrientY;

    for (final OcrTextLine line in lines) {
      if (title != null && line.centerY <= title.centerY) continue;

      final String t = _norm(line.text);

      if (_isTitle(t) || _isServingInfo(t) || _isNetWeight(t)) continue;

      if (_canonical(t) == null) continue;

      final double nameRight = line.words.first.right;

      final bool hasValueOnRow = valuesByLine.values.any(
        (List<_Value> values) => values.any(
          (_Value v) =>
              (v.cy - line.centerY).abs() < 0.8 * h && v.left > nameRight,
        ),
      );

      if (hasValueOnRow) {
        firstNutrientY = line.centerY;
        break;
      }
    }

    double dataTop;

    if (firstNutrientY != null) {
      dataTop = firstNutrientY - 0.6 * h;
    } else {
      dataTop = double.negativeInfinity;

      for (final OcrTextLine line in lines) {
        final String t = _norm(line.text);

        if (_isTitle(t) ||
            _isServingInfo(t) ||
            _headersInLine(line).isNotEmpty) {
          dataTop = math.max(dataTop, line.bottom);
        }
      }
    }

    double dataBottom = double.infinity;

    for (final OcrTextLine line in lines) {
      // Text beside the table (another panel) is not its
      // footer.
      if (title != null &&
          (line.left > title.right + 3 * h || line.right < title.left - 3 * h)) {
        continue;
      }

      if (line.centerY > (firstNutrientY ?? dataTop) &&
          _isFooter(_norm(line.text))) {
        dataBottom = line.top;
        break;
      }
    }

    debug?.writeln(
      '[parser] dataTop=${dataTop.toStringAsFixed(0)} '
      'dataBottom=${dataBottom.toStringAsFixed(0)} '
      'title=${title?.text}',
    );

    bool inRegion(OcrTextLine l) =>
        l.centerY > dataTop && l.centerY < dataBottom;

    bool isMeta(OcrTextLine l) {
      final String t = _norm(l.text);
      return _isTitle(t) || _isServingInfo(t) || _isNetWeight(t);
    }

    // ---------------------------------------------------
    // COLUMN HEADERS (only above the first nutrient row)
    // ---------------------------------------------------

    final List<_Header> headers = <_Header>[];

    for (final OcrTextLine line in lines) {
      if (firstNutrientY != null && line.centerY > firstNutrientY - 0.3 * h) {
        continue;
      }

      if (title != null && line.centerY < title.top - 2 * h) continue;

      for (final _Header header in _headersInLine(line)) {
        if (!headers.any((_Header e) => e.basis == header.basis)) {
          headers.add(header);
        }
      }
    }

    for (final _Header header in headers) {
      if (serving.amount == null && header.servingAmount != null) {
        serving.amount = header.servingAmount;
        serving.unit = header.servingUnit;
      }
    }

    debug?.writeln(
      '[parser] headers=${headers.map((_Header e) => '${e.label}@${e.x.toStringAsFixed(0)}').toList()}',
    );

    // ---------------------------------------------------
    // VALUES INSIDE THE TABLE
    // ---------------------------------------------------

    final List<_Value> values = <_Value>[];

    for (final OcrTextLine line in lines) {
      if (!inRegion(line) || isMeta(line)) continue;

      if (firstNutrientY == null && _headersInLine(line).isNotEmpty) {
        continue;
      }

      values.addAll(valuesByLine[line]!);
    }

    // ---------------------------------------------------
    // COLUMNS
    // ---------------------------------------------------

    final List<_Column> columns = _buildColumns(
      values: values,
      headers: headers,
      serving: serving,
      h: h,
    );

    debug?.writeln(
      '[parser] values=${values.length} columns=${columns.map((_Column c) => '${c.label.isEmpty ? '?' : c.label}[${c.left.toStringAsFixed(0)}-${c.right.toStringAsFixed(0)}] n=${c.count}').toList()}',
    );

    if (columns.isEmpty) {
      return NutritionLabelData(
        servingSizeAmount: serving.amount,
        servingSizeUnit: serving.unit,
        servingsPerPackage: serving.perPackage,
        servingUnitAmount: serving.unitAmount,
        servingUnitName: serving.unitName,
        rawText: rawText,
      );
    }

    // ---------------------------------------------------
    // VALUE ROWS WITHOUT A NAME
    //
    // Values between the column headings and the first
    // named row (names cut off by the photo edge) or far
    // from every name (orphans, counted further down).
    // ---------------------------------------------------

    final List<double> unnamedYs = <double>[];

    bool insideColumns(_Value v) {
      for (final _Column c in columns) {
        if (c.distanceTo(v.cx) <= 1.0 * h) return true;
      }

      return false;
    }

    if (firstNutrientY != null) {
      double headerBottom = double.negativeInfinity;

      for (final OcrTextLine line in lines) {
        if (line.centerY >= firstNutrientY) continue;

        if (line == title || isMeta(line) || _headersInLine(line).isNotEmpty) {
          headerBottom = math.max(headerBottom, line.bottom);
        }
      }

      for (final OcrTextLine line in lines) {
        if (line.centerY <= headerBottom || line.centerY > dataTop) continue;

        if (isMeta(line)) continue;

        for (final _Value v in valuesByLine[line]!) {
          if (insideColumns(v)) unnamedYs.add(v.cy);
        }
      }
    }

    // ---------------------------------------------------
    // NUTRIENT NAMES
    // ---------------------------------------------------

    final double nameLimit =
        columns.map((_Column c) => c.left).reduce(math.min) - 0.25 * h;

    final List<_Anchor> rawAnchors = <_Anchor>[];

    for (final OcrTextLine line in lines) {
      if (!inRegion(line) || isMeta(line)) continue;

      final _Anchor? anchor = _anchorFromLine(line, nameLimit, h);

      if (anchor != null) rawAnchors.add(anchor);
    }

    // Text islands left of the table (logo captions such
    // as "HALAL", "MS1500") are not nutrient names.
    final List<double> knownLefts = <double>[
      for (final _Anchor a in rawAnchors)
        if (a.key != null) a.left,
    ];

    if (knownLefts.length >= 3) {
      final double tableLeft = _median(knownLefts) - 3 * h;

      rawAnchors.removeWhere((_Anchor a) => a.right < tableLeft);
    }

    // Anything taller than two lines of text is not a
    // single name.
    rawAnchors.removeWhere((_Anchor a) => a.bottom - a.top > 2.5 * h);

    final List<_Anchor> anchors = _mergeAnchors(rawAnchors, values, h);

    debug?.writeln(
      '[parser] names=${anchors.map((_Anchor a) => a.name).toList()}',
    );

    if (anchors.isEmpty) {
      return NutritionLabelData(
        servingSizeAmount: serving.amount,
        servingSizeUnit: serving.unit,
        servingsPerPackage: serving.perPackage,
        servingUnitAmount: serving.unitAmount,
        servingUnitName: serving.unitName,
        columns: _toModelColumns(columns),
        rawText: rawText,
      );
    }

    // ---------------------------------------------------
    // ASSIGN VALUES TO CELLS
    // ---------------------------------------------------

    final List<List<List<_Value>>> cells = List<List<List<_Value>>>.generate(
      anchors.length,
      (_) => List<List<_Value>>.generate(columns.length, (_) => <_Value>[]),
    );

    final double maxColumnDistance = columns.length >= 2 ? 1.5 * h : 3.0 * h;

    for (final _Value v in values) {
      int row = -1;
      double rowDistance = double.infinity;

      for (int i = 0; i < anchors.length; i++) {
        final double d = anchors[i].distanceTo(v.cy);

        final bool better = d < rowDistance - 0.01 ||
            ((d - rowDistance).abs() <= 0.01 &&
                row >= 0 &&
                (v.cy - anchors[i].cy).abs() < (v.cy - anchors[row].cy).abs());

        if (better) {
          row = i;
          rowDistance = d;
        }
      }

      // kJ / kcal printed on a second line under "Energy"
      // belongs to the energy row even if it sits halfway
      // to the next nutrient.
      bool energyOverride = false;

      if (v.unit == 'kJ' || v.unit == 'kcal') {
        for (int i = 0; i < anchors.length; i++) {
          if (anchors[i].key != 'energy') continue;

          final double d = anchors[i].distanceTo(v.cy);

          if (d <= 2.2 * h && (!energyOverride || d < rowDistance)) {
            row = i;
            rowDistance = d;
            energyOverride = true;
          }
        }
      }

      if (row < 0 || (rowDistance > 1.2 * h && !energyOverride)) {
        debug?.writeln('[parser] orphan value ${v.raw} y=${v.cy.round()}');

        if (insideColumns(v)) unnamedYs.add(v.cy);

        continue;
      }

      int column = -1;
      double columnDistance = double.infinity;

      for (int j = 0; j < columns.length; j++) {
        final double d = columns[j].distanceTo(v.cx);

        final bool better = d < columnDistance - 0.01 ||
            ((d - columnDistance).abs() <= 0.01 &&
                column >= 0 &&
                (v.cx - columns[j].center).abs() <
                    (v.cx - columns[column].center).abs());

        if (better) {
          column = j;
          columnDistance = d;
        }
      }

      // Side-by-side kJ / kcal values sit between columns;
      // they are re-paired per row afterwards.
      final double allowed = (v.unit == 'kJ' || v.unit == 'kcal')
          ? 6.0 * h
          : maxColumnDistance;

      if (column < 0 || columnDistance > allowed) continue;

      final List<_Value> cell = cells[row][column];

      final bool duplicate = cell.any(
        (_Value e) => (e.amount - v.amount).abs() < 0.0001 && e.unit == v.unit,
      );

      if (!duplicate) cell.add(v);
    }

    // ---------------------------------------------------
    // MERGE NAME LINES THAT GOT NO VALUES
    // (wrapped names, second language line)
    // ---------------------------------------------------

    final List<bool> removed = List<bool>.filled(anchors.length, false);

    bool rowHasValues(int i) =>
        cells[i].any((List<_Value> cell) => cell.isNotEmpty);

    for (int i = 0; i < anchors.length; i++) {
      if (rowHasValues(i)) continue;

      final _Anchor a = anchors[i];

      if (a.name.trim().endsWith(':')) continue;

      int target = -1;
      double targetGap = 0.6 * h;

      for (final int n in <int>[i - 1, i + 1]) {
        if (n < 0 || n >= anchors.length || removed[n]) continue;

        if (!rowHasValues(n)) continue;

        final _Anchor b = anchors[n];

        if (a.key != null && b.key != null && a.key != b.key) continue;

        // Must sit in the same name column.
        if (a.right < b.left - 2 * h || a.left > b.right + 2 * h) continue;

        final double gap = n < i ? a.top - b.bottom : b.top - a.bottom;

        if (gap < targetGap) {
          target = n;
          targetGap = gap;
        }
      }

      if (target < 0) continue;

      final _Anchor b = anchors[target];

      final String joiner = (a.key != null && a.key == b.key) ? ' / ' : ' ';

      b.name = target < i ? '${b.name}$joiner${a.name}' : '${a.name}$joiner${b.name}';
      b.key ??= a.key;
      b.unit ??= a.unit;
      b.left = math.min(a.left, b.left);
      b.right = math.max(a.right, b.right);
      removed[i] = true;
    }

    // ---------------------------------------------------
    // ROW CLEAN-UP
    // ---------------------------------------------------

    for (int i = 0; i < anchors.length; i++) {
      if (removed[i] || !rowHasValues(i)) continue;

      _repairRowColumns(cells[i], columns, anchors[i]);
    }

    _fixGramsReadAsNine(cells, removed, columns.length, debug, notes);

    for (int i = 0; i < anchors.length; i++) {
      if (removed[i] || !rowHasValues(i)) continue;

      _reconcileUnits(cells[i], anchors[i]);
    }

    _crossCheck(
      columns: columns,
      anchors: anchors,
      cells: cells,
      removed: removed,
      serving: serving,
      debug: debug,
      notes: notes,
    );

    // ---------------------------------------------------
    // DROP EMPTY COLUMNS
    // ---------------------------------------------------

    final List<int> keptColumns = <int>[];

    for (int j = 0; j < columns.length; j++) {
      bool used = false;

      for (int i = 0; i < anchors.length; i++) {
        if (!removed[i] && cells[i][j].isNotEmpty) {
          used = true;
          break;
        }
      }

      if (used) keptColumns.add(j);
    }

    // Reading order inside a cell: top to bottom, then
    // left to right ("1800 kJ" before "430 kcal").
    int readingOrder(_Value a, _Value b) {
      if ((a.cy - b.cy).abs() < 0.5 * h) return a.cx.compareTo(b.cx);

      return a.cy.compareTo(b.cy);
    }

    for (final List<List<_Value>> row in cells) {
      for (final List<_Value> cell in row) {
        cell.sort(readingOrder);
      }
    }

    final List<NutrientRow> nutrients = <NutrientRow>[];

    int order = 0;

    for (int i = 0; i < anchors.length; i++) {
      if (removed[i] || !rowHasValues(i)) continue;

      nutrients.add(
        NutrientRow(
          name: anchors[i].name,
          order: order++,
          valuesByColumn: <List<NutritionValue>>[
            for (final int j in keptColumns)
              <NutritionValue>[
                for (final _Value v in cells[i][j])
                  NutritionValue(
                    amount: _round(v.amount),
                    unit: v.unit,
                    rawText: v.raw,
                  ),
              ],
          ],
        ),
      );
    }

    // ---------------------------------------------------
    // TABLE BOUNDS (title, headers, names, value columns)
    // ---------------------------------------------------

    if ((boundsOut != null || diagnosticsOut != null) && nutrients.isNotEmpty) {
      final List<_Anchor> used = <_Anchor>[
        for (int i = 0; i < anchors.length; i++)
          if (!removed[i] && rowHasValues(i)) anchors[i],
      ];

      double left = used.map((_Anchor a) => a.left).reduce(math.min);
      double right = <double>[
        for (final int j in keptColumns) columns[j].right,
      ].reduce(math.max);
      double top = used.map((_Anchor a) => a.top).reduce(math.min);
      double bottom = used.map((_Anchor a) => a.bottom).reduce(math.max);

      for (final List<List<_Value>> row in cells) {
        for (final List<_Value> cell in row) {
          for (final _Value v in cell) {
            bottom = math.max(bottom, v.cy + h / 2);
          }
        }
      }

      // Title, serving lines and headers above the rows,
      // when they sit over the table.
      for (final OcrTextLine line in lines) {
        if (line.centerY >= top) continue;

        final String t = _norm(line.text);

        final bool partOfTable = line == title ||
            _isServingInfo(t) ||
            _headersInLine(line).isNotEmpty;

        if (!partOfTable) continue;

        if (line.right < left - 2 * h || line.left > right + 2 * h) continue;

        if (title != null && line.centerY < title.top - h) continue;

        top = math.min(top, line.top);
        left = math.min(left, line.left);
        right = math.max(right, line.right);
      }

      boundsOut?.add(
        _rotateBoundsBack(
          OcrBounds(
            left: left - 0.8 * h,
            top: top - 0.8 * h,
            right: right + 0.8 * h,
            bottom: bottom + 0.8 * h,
          ),
          skewRadians,
        ),
      );

      if (diagnosticsOut != null) {
        // Count separate rows, not values.
        final List<double> ys = List<double>.of(unnamedYs)..sort();

        int unnamedRows = 0;
        double lastY = double.negativeInfinity;

        for (final double y in ys) {
          if (y - lastY > 0.6 * h) unnamedRows++;
          lastY = y;
        }

        diagnosticsOut.add(
          NutritionTableDiagnostics(
            contentBounds: _rotateBoundsBack(
              OcrBounds(left: left, top: top, right: right, bottom: bottom),
              skewRadians,
            ),
            unnamedValueRows: unnamedRows,
            titleFound: title != null,
            textHeight: h,
          ),
        );
      }
    }

    return NutritionLabelData(
      servingSizeAmount: serving.amount,
      servingSizeUnit: serving.unit,
      servingsPerPackage: serving.perPackage,
      servingUnitAmount: serving.unitAmount,
      servingUnitName: serving.unitName,
      columns: _toModelColumns(<_Column>[
        for (final int j in keptColumns) columns[j],
      ]),
      nutrients: nutrients,
      rawText: rawText,
      notes: notes,
    );
  }

  // Deskewed box -> box in original image coordinates.
  static OcrBounds _rotateBoundsBack(OcrBounds b, double angle) {
    if (angle.abs() < 0.004) return b;

    final double c = math.cos(angle);
    final double s = math.sin(angle);

    final List<List<double>> corners = <List<double>>[
      <double>[b.left, b.top],
      <double>[b.right, b.top],
      <double>[b.right, b.bottom],
      <double>[b.left, b.bottom],
    ];

    final List<double> xs = <double>[];
    final List<double> ys = <double>[];

    for (final List<double> p in corners) {
      xs.add(p[0] * c - p[1] * s);
      ys.add(p[0] * s + p[1] * c);
    }

    return OcrBounds(
      left: xs.reduce(math.min),
      top: ys.reduce(math.min),
      right: xs.reduce(math.max),
      bottom: ys.reduce(math.max),
    );
  }

  // =====================================================
  // QUALITY SCORE
  //
  // Used to pick the better of two OCR passes.
  // =====================================================

  static double qualityScore(NutritionLabelData data) {
    double score = 0;

    for (final NutrientRow row in data.nutrients) {
      score += 1;

      for (final List<NutritionValue> cell in row.valuesByColumn) {
        if (cell.isEmpty) continue;

        score += 1;

        if (cell.every((NutritionValue v) => v.unit != '?')) score += 0.25;
      }

      if (_canonical(_norm(row.name)) != null) score += 0.5;
    }

    for (final NutritionColumn column in data.columns) {
      if (column.basis != NutritionColumnBasis.unknown) score += 2;
    }

    if (data.hasServingSize) score += 1;

    return score;
  }

  // =====================================================
  // TABLE BOUNDS (for cropping before a second OCR pass)
  //
  // Uses raw (not deskewed) coordinates because the crop
  // is taken from the original image.
  // =====================================================

  static OcrBounds? tableBounds(
    List<OcrTextLine> input, {
    double skewRadians = 0,
  }) {
    // Best: bounds of the table the parser actually found.
    final List<OcrBounds> found = <OcrBounds>[];

    parse(input, skewRadians: skewRadians, boundsOut: found);

    if (found.isNotEmpty) return found.first;

    return _roughTableBounds(input);
  }

  // Fallback when no complete table was found: from the
  // title down to the last nutrient-looking line.
  static OcrBounds? _roughTableBounds(List<OcrTextLine> input) {
    List<OcrTextLine> lines = input
        .where((OcrTextLine l) => l.words.isNotEmpty)
        .toList()
      ..sort((OcrTextLine a, OcrTextLine b) => a.centerY.compareTo(b.centerY));

    if (lines.isEmpty) return null;

    final double h0 = _medianHeight(lines);

    lines = _withoutVerticalText(lines, h0);

    if (lines.isEmpty) return null;

    final double h = _medianHeight(lines);

    OcrTextLine? start;

    for (final OcrTextLine line in lines) {
      if (_isTitle(_norm(line.text))) {
        start = line;
        break;
      }
    }

    if (start == null) {
      for (final OcrTextLine line in lines) {
        final String t = _norm(line.text);

        if (_isServingInfo(t) ||
            (_canonical(t) != null && _valuesInLine(line).isNotEmpty)) {
          start = line;
          break;
        }
      }
    }

    if (start == null) return null;

    double left = start.left;
    double right = start.right;
    double top = start.top;
    double bottom = start.bottom;
    double lastBottom = start.bottom;

    bool seenNutrient = _canonical(_norm(start.text)) != null;

    for (final OcrTextLine line in lines) {
      if (line.centerY <= start.centerY) continue;

      final String t = _norm(line.text);

      if (seenNutrient && _isFooter(t)) break;

      if (seenNutrient && line.top - lastBottom > 5 * h) break;

      if (_isNetWeight(t)) continue;

      final bool meta =
          _isTitle(t) || _isServingInfo(t) || _headersInLine(line).isNotEmpty;

      final bool nutrient = _canonical(t) != null;

      final bool hasValues = _valuesInLine(line).isNotEmpty;

      if (!meta && !nutrient && !hasValues) continue;

      if (nutrient) seenNutrient = true;

      left = math.min(left, line.left);
      right = math.max(right, line.right);
      bottom = math.max(bottom, line.bottom);
      lastBottom = line.bottom;
    }

    if (!seenNutrient) return null;

    return OcrBounds(
      left: left - 1.5 * h,
      top: top - 1.0 * h,
      right: right + 1.5 * h,
      bottom: bottom + 1.5 * h,
    );
  }

  // =====================================================
  // DESKEW
  // =====================================================
  //
  // Rotates every word centre by -angle so table rows
  // become horizontal again. ML Kit boxes of tilted words
  // are axis-aligned (and therefore too tall), so the true
  // word height is estimated as well.
  // =====================================================

  static List<OcrTextLine> _deskew(List<OcrTextLine> lines, double angle) {
    if (angle.abs() < 0.004) return lines;

    final double c = math.cos(angle);
    final double s = math.sin(angle);
    final double absS = s.abs();

    return lines.map((OcrTextLine line) {
      return OcrTextLine(
        line.words.map((OcrWord w) {
          final double x = w.centerX * c + w.centerY * s;
          final double y = -w.centerX * s + w.centerY * c;

          final double trueH = math.max(
            w.height * 0.5,
            (w.height - w.width * absS) / c,
          );

          final double trueW = math.max(
            w.width * 0.5,
            (w.width - trueH * absS) / c,
          );

          return OcrWord(
            text: w.text,
            left: x - trueW / 2,
            right: x + trueW / 2,
            top: y - trueH / 2,
            bottom: y + trueH / 2,
          );
        }).toList(),
      );
    }).toList();
  }

  // =====================================================
  // VERTICAL TEXT FILTER
  // =====================================================

  static List<OcrTextLine> _withoutVerticalText(
    List<OcrTextLine> lines,
    double h,
  ) {
    final List<OcrTextLine> result = <OcrTextLine>[];

    for (final OcrTextLine line in lines) {
      final List<OcrWord> words = line.words.where((OcrWord w) {
        if (w.height > 2.5 * h) return false;

        // A word of 3+ characters taller than it is wide
        // is written sideways.
        if (w.text.length >= 3 && w.height > 1.3 * w.width) return false;

        return true;
      }).toList();

      if (words.isEmpty) continue;

      result.add(
        words.length == line.words.length ? line : OcrTextLine(words),
      );
    }

    return result;
  }

  // =====================================================
  // MEDIAN TEXT HEIGHT
  // =====================================================

  static double _medianHeight(List<OcrTextLine> lines) {
    final List<double> heights = <double>[
      for (final OcrTextLine line in lines)
        for (final OcrWord w in line.words)
          if (w.height > 0 && RegExp(r'[A-Za-z0-9]').hasMatch(w.text))
            w.height,
    ];

    if (heights.isEmpty) return 16;

    return math.max(4, _median(heights));
  }

  // =====================================================
  // VISUAL ROWS (text of everything on the same height)
  // =====================================================

  static List<_Row> _visualRows(List<OcrTextLine> lines, double h) {
    final List<List<OcrTextLine>> groups = <List<OcrTextLine>>[];
    final List<double> centers = <double>[];

    for (final OcrTextLine line in lines) {
      if (groups.isNotEmpty && (line.centerY - centers.last).abs() < 0.5 * h) {
        groups.last.add(line);

        centers[centers.length - 1] = groups.last
                .map((OcrTextLine l) => l.centerY)
                .reduce((double a, double b) => a + b) /
            groups.last.length;
      } else {
        groups.add(<OcrTextLine>[line]);
        centers.add(line.centerY);
      }
    }

    return <_Row>[
      for (int i = 0; i < groups.length; i++)
        _Row(
          _norm(
            (groups[i].expand((OcrTextLine l) => l.words).toList()
                  ..sort((OcrWord a, OcrWord b) => a.left.compareTo(b.left)))
                .map((OcrWord w) => w.text)
                .join(' '),
          ),
          centers[i],
        ),
    ];
  }

  // =====================================================
  // SERVING INFORMATION
  // =====================================================

  static final RegExp _servingKeywordRe = RegExp(
    r'serving\s*size|saiz\s*hidangan|saiz\s*sajian|takaran\s*saji',
  );

  static final RegExp _massRe = RegExp(
    r'(?<![a-z0-9.,])(\d+(?:[.,]\d+)?)\s*(g|gm|grams?|ml|mg|l)(?![a-z0-9])',
  );

  static final RegExp _servingHeaderRe = RegExp(
    r'(?:per|setiap)\s*'
    r'(?:serving|serve|hidangan|sajian|portion|sachet|pack|packet|bar|'
    r'bottle|piece|biscuit|tablet|cup|can|uncang|paket|biji|keping|'
    r'botol|tin|cawan|bungkus)s?'
    r'\s*[\(\[]?\s*(\d+(?:[.,]\d+)?)\s*(g|ml)(?![a-z])',
  );

  static final RegExp _servingsPerPackageRe = RegExp(
    r'(?:servings?\s*per\s*'
    r'(?:package|pack|packet|container|bottle|box|can|tin|bag)'
    r'|number\s*of\s*servings'
    r'|(?:bilangan\s*)?hidangan\s*(?:setiap|per|dalam|bagi)\s*'
    r'(?:bungkusan|pek|paket|pakej|botol|kotak|tin|bekas|beg))'
    r'[^0-9]{0,45}?(\d+(?:[.,]\d+)?)',
  );

  static const String _countUnits =
      r'sudu\s*besar|sudu\s*teh|sudu|chips?|biscuits?|crackers?|tablets?|'
      r'capsules?|pieces?|pcs?|sachets?|bottles?|cups?|bars?|slices?|'
      r'scoops?|tbsp|tsp|sticks?|cans?|packets?|packs?|keping|biji|paket|'
      r'uncang|cawan|botol|tin|bungkus|batang';

  static final RegExp _fractionServingRe = RegExp(
    <String>[
      r'(\d+(?:[.,]\d+)?)\s*/\s*(\d+(?:[.,]\d+)?)\s*(',
      _countUnits,
      r')\b',
    ].join(),
  );

  static final RegExp _countServingRe = RegExp(
    <String>[
      r'(?:about\s*|approx\.?\s*|lebih\s*kurang\s*|kira-kira\s*|±\s*)?'
          r'(?<![0-9.,])(\d+(?:[.,]\d+)?)\s*(',
      _countUnits,
      r')\b',
    ].join(),
  );

  static final RegExp _packageRelationRe = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(mg|g|ml)\s*[x×]\s*\d+(?:[.,]\d+)?\s*'
    r'(tablets?|capsules?|pieces?|sachets?|bars?|biji|keping|uncang)',
  );

  static _Serving _readServing(List<_Row> rows) {
    final _Serving result = _Serving();

    // 1. "Serving size: 2 keping (30 g)"
    for (final _Row row in rows) {
      final RegExpMatch? keyword = _servingKeywordRe.firstMatch(row.text);

      if (keyword == null) continue;

      final String tail = row.text.substring(
        keyword.end,
        math.min(row.text.length, keyword.end + 70),
      );

      if (result.amount == null) {
        for (final RegExpMatch m in _massRe.allMatches(tail)) {
          final String before = tail.substring(math.max(0, m.start - 8), m.start);

          if (before.contains('per') || before.contains('setiap')) continue;

          final _Parsed? parsed = _servingMass(m.group(1), m.group(2));

          if (parsed != null) {
            result.amount = parsed.amount;
            result.unit = parsed.unit;
            break;
          }
        }
      }

      if (result.unitName == null) {
        final RegExpMatch? fraction = _fractionServingRe.firstMatch(tail);

        if (fraction != null) {
          final double? a = _simpleNumber(fraction.group(1));
          final double? b = _simpleNumber(fraction.group(2));

          if (a != null && b != null && b != 0) {
            result.unitAmount = a / b;
            result.unitName = _singularize(fraction.group(3)!);
          }
        } else {
          final RegExpMatch? count = _countServingRe.firstMatch(tail);

          if (count != null) {
            result.unitAmount = _simpleNumber(count.group(1));
            result.unitName = _singularize(count.group(2)!);
          }
        }
      }

      if (result.amount != null) break;
    }

    // 2. "Per serving (30 g)" / "Setiap hidangan (30g)"
    if (result.amount == null) {
      for (final _Row row in rows) {
        final RegExpMatch? m = _servingHeaderRe.firstMatch(row.text);

        if (m == null) continue;

        final _Parsed? parsed = _servingMass(m.group(1), m.group(2));

        if (parsed != null && parsed.amount != 100) {
          result.amount = parsed.amount;
          result.unit = parsed.unit;
          break;
        }
      }
    }

    // 3. "30g (1g x 30 tablet)"
    final String all = rows.map((_Row r) => r.text).join(' ');

    final RegExpMatch? relation = _packageRelationRe.firstMatch(all);

    if (relation != null) {
      final _Parsed? perUnit = _servingMass(relation.group(1), relation.group(2));

      if (perUnit != null) {
        if (result.amount == null) {
          result.amount = perUnit.amount;
          result.unit = perUnit.unit;
        }

        if (result.unitName == null &&
            result.unit == perUnit.unit &&
            (result.amount! - perUnit.amount).abs() < 0.001) {
          result.unitAmount = 1;
          result.unitName = _singularize(relation.group(3)!);
        }
      }
    }

    // 4. Servings per package
    for (final _Row row in rows) {
      final RegExpMatch? m = _servingsPerPackageRe.firstMatch(row.text);

      if (m != null) {
        result.perPackage = _simpleNumber(m.group(1));
        break;
      }
    }

    if (result.perPackage == null) {
      final RegExpMatch? m = _servingsPerPackageRe.firstMatch(all);

      if (m != null) result.perPackage = _simpleNumber(m.group(1));
    }

    return result;
  }

  static _Parsed? _servingMass(String? number, String? unit) {
    final double? amount = _simpleNumber(number);

    if (amount == null || unit == null || amount <= 0) return null;

    switch (unit.toLowerCase()) {
      case 'g':
      case 'gm':
      case 'gram':
      case 'grams':
        return _Parsed(amount, 'g');
      case 'mg':
        return _Parsed(amount / 1000, 'g');
      case 'ml':
        return _Parsed(amount, 'ml');
      case 'l':
        return _Parsed(amount * 1000, 'ml');
    }

    return null;
  }

  // =====================================================
  // COLUMN HEADERS IN ONE LINE
  // =====================================================

  static const Set<String> _perWords = <String>{'per', 'setiap', 'bagi'};

  static const Set<String> _servingWords = <String>{
    'serving',
    'serve',
    'portion',
    'hidangan',
    'sajian',
  };

  static const Set<String> _perUnitWords = <String>{
    'sachet',
    'pack',
    'packet',
    'bar',
    'bottle',
    'piece',
    'biscuit',
    'tablet',
    'cup',
    'can',
    'stick',
    'scoop',
    'uncang',
    'paket',
    'biji',
    'keping',
    'botol',
    'tin',
    'cawan',
    'bungkus',
  };

  static final RegExp _amountUnitWordRe = RegExp(r'^(\d+(?:[.,]\d+)?)(g|ml)$');

  static List<_Header> _headersInLine(OcrTextLine line) {
    final String lineText = _headerNorm(line.text);

    if (_isServingInfo(lineText) || _isNetWeight(lineText)) {
      return const <_Header>[];
    }

    final List<OcrWord> w = line.words;

    final List<String> t = <String>[
      for (final OcrWord word in w) _trimPunct(_headerNorm(word.text)),
    ];

    final List<_Header> result = <_Header>[];

    for (int i = 0; i < w.length; i++) {
      final String word = t[i];

      final bool prevIsPer = i > 0 && _perWords.contains(t[i - 1]);

      final double spanLeft = prevIsPer ? w[i - 1].left : w[i].left;

      // ------------------------------------------------
      // 100 g / 100 ml
      // ------------------------------------------------

      String? unit100;
      double spanRight = w[i].right;

      final RegExpMatch? compact =
          RegExp(r'^(?:per|setiap)?100(g|ml)$').firstMatch(word);

      if (compact != null) {
        unit100 = compact.group(1);
      } else if (word == '100' && i + 1 < w.length) {
        final String next = t[i + 1];

        if (next == 'g' || next == 'ml') {
          unit100 = next;
          spanRight = w[i + 1].right;
        }
      }

      if (unit100 != null) {
        result.add(
          _Header(
            basis: unit100 == 'g'
                ? NutritionColumnBasis.per100g
                : NutritionColumnBasis.per100ml,
            label: unit100 == 'g' ? 'Per 100 g' : 'Per 100 ml',
            x: (spanLeft + spanRight) / 2,
          ),
        );

        continue;
      }

      // ------------------------------------------------
      // Per serving / Setiap hidangan (30 g)
      // ------------------------------------------------

      if (_servingWords.contains(word)) {
        double right = w[i].right;
        double? amount;
        String? unit;

        if (i + 1 < w.length) {
          final RegExpMatch? m = _amountUnitWordRe.firstMatch(t[i + 1]);

          if (m != null) {
            amount = _simpleNumber(m.group(1));
            unit = m.group(2);
            right = w[i + 1].right;
          }
        }

        result.add(
          _Header(
            basis: NutritionColumnBasis.perServing,
            label: 'Per serving',
            x: (spanLeft + right) / 2,
            servingAmount: amount,
            servingUnit: unit,
          ),
        );

        continue;
      }

      // ------------------------------------------------
      // Per sachet / Setiap uncang
      // ------------------------------------------------

      final String singular =
          word.endsWith('s') ? word.substring(0, word.length - 1) : word;

      if (prevIsPer && _perUnitWords.contains(singular)) {
        result.add(
          _Header(
            basis: NutritionColumnBasis.perServing,
            label: 'Per $singular',
            x: (spanLeft + w[i].right) / 2,
          ),
        );

        continue;
      }

      // ------------------------------------------------
      // Per 30 g (serving expressed in grams)
      // ------------------------------------------------

      if (_perWords.contains(word) && i + 1 < w.length) {
        double? amount;
        String? unit;
        double right = w[i + 1].right;

        final RegExpMatch? m = _amountUnitWordRe.firstMatch(t[i + 1]);

        if (m != null) {
          amount = _simpleNumber(m.group(1));
          unit = m.group(2);
        } else if (i + 2 < w.length &&
            RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(t[i + 1]) &&
            (t[i + 2] == 'g' || t[i + 2] == 'ml')) {
          amount = _simpleNumber(t[i + 1]);
          unit = t[i + 2];
          right = w[i + 2].right;
        }

        if (amount != null && unit != null && amount != 100) {
          result.add(
            _Header(
              basis: NutritionColumnBasis.perServing,
              label: 'Per ${_formatNumber(amount)} $unit',
              x: (w[i].left + right) / 2,
              servingAmount: amount,
              servingUnit: unit,
            ),
          );
        }
      }
    }

    return result;
  }

  // =====================================================
  // VALUES IN ONE LINE
  // =====================================================

  static List<_Value> _valuesInLine(OcrTextLine line) {
    final List<_Tok> toks = <_Tok>[
      for (final OcrWord w in line.words) ..._splitWord(w),
    ];

    // Numbers left of a name word belong to the name
    // ("Omega 3 fatty acids", "Vitamin B 6").
    int lastAlpha = -1;

    for (int i = 0; i < toks.length; i++) {
      final String s = toks[i].text;

      if (RegExp(r'[A-Za-z]{2}').hasMatch(s) &&
          _parseUnitText(s) == null &&
          _parseValueText(s) == null) {
        lastAlpha = i;
      }
    }

    final List<_Value> result = <_Value>[];

    int i = 0;

    while (i < toks.length) {
      final _Tok tok = toks[i];
      final String compact = tok.text.replaceAll(' ', '');

      final _Parsed? full = _parseValueText(compact);

      if (full != null) {
        result.add(
          _Value(
            amount: full.amount,
            unit: full.unit,
            raw: tok.text,
            left: tok.left,
            right: tok.right,
            cy: tok.cy,
            explicitUnit: true,
          ),
        );

        i++;
        continue;
      }

      final double? number = _parseNumberText(compact);

      if (number != null) {
        if (i + 1 < toks.length) {
          final String? unit = _parseUnitText(toks[i + 1].text);

          if (unit != null) {
            result.add(
              _Value(
                amount: number,
                unit: unit,
                raw: '${tok.text} ${toks[i + 1].text}',
                left: tok.left,
                right: toks[i + 1].right,
                cy: (tok.cy + toks[i + 1].cy) / 2,
                explicitUnit: true,
              ),
            );

            i += 2;
            continue;
          }
        }

        if (i > lastAlpha) {
          result.add(
            _Value(
              amount: number,
              unit: '?',
              raw: tok.text,
              left: tok.left,
              right: tok.right,
              cy: tok.cy,
              explicitUnit: false,
            ),
          );
        }
      }

      i++;
    }

    return result;
  }

  // Splits "230kJ/55kcal" or "(55kcal)" into parts and
  // estimates each part's horizontal position.
  static List<_Tok> _splitWord(OcrWord w) {
    final String text = w.text;
    final int length = math.max(1, text.length);

    final List<_Tok> result = <_Tok>[];

    for (final RegExpMatch m in RegExp(r'[^/()\[\]|]+').allMatches(text)) {
      String part = m.group(0)!;
      int start = m.start;

      final RegExpMatch? lead =
          RegExp(r'''^[\s*•·:;,"'~=]+''').firstMatch(part);

      if (lead != null) {
        start += lead.end;
        part = part.substring(lead.end);
      }

      final RegExpMatch? trail =
          RegExp(r'''[\s*•·:;,"'.=]+$''').firstMatch(part);

      if (trail != null) {
        part = part.substring(0, trail.start);
      }

      if (part.isEmpty) continue;

      final int end = start + part.length;

      result.add(
        _Tok(
          text: part,
          left: w.left + w.width * start / length,
          right: w.left + w.width * end / length,
          cy: w.centerY,
        ),
      );
    }

    return result;
  }

  // =====================================================
  // VALUE / NUMBER / UNIT RECOGNITION
  // =====================================================

  static const String _unitAlternatives =
      r'kcal|kcai|kca1|kj|mcg|µg|μg|ug|pg|qg|mg|rng|mq|gm|g|ml|iu';

  static final RegExp _valueTextRe = RegExp(
    <String>[
      r'^(?:<|≤|<=)?([0-9oOlIi]+(?:[.,][0-9oOlIi]+)?)(',
      _unitAlternatives,
      r')$',
    ].join(),
    caseSensitive: false,
  );

  static final RegExp _numberTextRe = RegExp(
    r'^(?:<|≤|<=)?([0-9oOlIi]+(?:[.,][0-9oOlIi]+)?)$',
  );

  static final RegExp _unitTextRe = RegExp(
    <String>[r'^(', _unitAlternatives, r')$'].join(),
    caseSensitive: false,
  );

  // "0.7µg" is often read as "0.7jg", "0.7yg", "0.7Hg".
  static final RegExp _microgramLookalikeRe = RegExp(
    r'^(?:<|≤|<=)?([0-9oOlIi]+(?:[.,][0-9oOlIi]+)?)[jyhHJY]g$',
  );

  static _Parsed? _parseValueText(String text) {
    final RegExpMatch? lookalike = _microgramLookalikeRe.firstMatch(text);

    if (lookalike != null) {
      final String? digits =
          _fixDigits(lookalike.group(1)!, allowSingleLetter: false);

      final double? amount = digits == null ? null : _toAmount(digits);

      if (amount != null) return _Parsed(amount, 'µg');
    }

    final RegExpMatch? m = _valueTextRe.firstMatch(text);

    if (m == null) return null;

    // "Og" (0 g) and "lg" (1 g) are accepted as whole
    // words; otherwise at least one real digit is needed
    // so words like "log" never become "10 g".
    final String? digits = _fixDigits(m.group(1)!, allowSingleLetter: true);

    if (digits == null) return null;

    final double? amount = _toAmount(digits);

    if (amount == null) return null;

    return _Parsed(amount, _normalizeUnit(m.group(2)!));
  }

  static double? _parseNumberText(String text) {
    final RegExpMatch? m = _numberTextRe.firstMatch(text);

    if (m == null) return null;

    // Stray "|", "I", "l" (table lines) are not numbers.
    final String? digits = _fixDigits(m.group(1)!, allowSingleLetter: false);

    if (digits == null) return null;

    return _toAmount(digits);
  }

  static String? _parseUnitText(String text) {
    final RegExpMatch? m = _unitTextRe.firstMatch(_trimPunct(text));

    if (m == null) return null;

    return _normalizeUnit(m.group(1)!);
  }

  static String? _fixDigits(String value, {required bool allowSingleLetter}) {
    final bool hasDigit = RegExp(r'\d').hasMatch(value);

    if (!hasDigit && !(allowSingleLetter && value.length == 1)) return null;

    return value
        .replaceAll(RegExp(r'[oO]'), '0')
        .replaceAll(RegExp(r'[lIi]'), '1');
  }

  static double? _toAmount(String digits) {
    String value = digits;

    // "1,520" kJ is one thousand five hundred twenty;
    // "0,5" g is a decimal comma.
    if (RegExp(r'^[1-9]\d{0,2},\d{3}$').hasMatch(value)) {
      value = value.replaceAll(',', '');
    } else {
      value = value.replaceAll(',', '.');
    }

    return double.tryParse(value);
  }

  static String _normalizeUnit(String unit) {
    final String u = unit.toLowerCase();

    switch (u) {
      case 'kcal':
      case 'kcai':
      case 'kca1':
        return 'kcal';
      case 'kj':
        return 'kJ';
      case 'mcg':
      case 'µg':
      case 'μg':
      case 'ug':
      case 'pg':
      case 'qg':
        return 'µg';
      case 'mg':
      case 'rng':
      case 'mq':
        return 'mg';
      case 'gm':
      case 'g':
        return 'g';
      case 'ml':
        return 'ml';
      case 'iu':
        return 'IU';
    }

    return u;
  }

  // =====================================================
  // COLUMNS
  // =====================================================

  static List<_Column> _buildColumns({
    required List<_Value> values,
    required List<_Header> headers,
    required _Serving serving,
    required double h,
  }) {
    if (values.isEmpty) return <_Column>[];

    // ---------------------------------------------------
    // Use only "normal" rows to discover columns.
    //
    // A row like "Energy 920 kJ 220 kcal | 1840 kJ 440
    // kcal" has twice as many values as the other rows,
    // and its kcal values sit between the columns. They
    // would glue two columns together, so rows with more
    // values than usual are left out here (they are still
    // assigned to cells later).
    // ---------------------------------------------------

    final List<_Value> byY = List<_Value>.of(values)
      ..sort((_Value a, _Value b) => a.cy.compareTo(b.cy));

    final List<List<_Value>> valueRows = <List<_Value>>[];

    for (final _Value v in byY) {
      if (valueRows.isNotEmpty) {
        final List<_Value> last = valueRows.last;

        final double meanY =
            last.map((_Value e) => e.cy).reduce((double a, double b) => a + b) /
                last.length;

        if ((v.cy - meanY).abs() < 0.5 * h) {
          last.add(v);
          continue;
        }
      }

      valueRows.add(<_Value>[v]);
    }

    final Map<int, int> rowCountFrequency = <int, int>{};

    for (final List<_Value> row in valueRows) {
      rowCountFrequency[row.length] = (rowCountFrequency[row.length] ?? 0) + 1;
    }

    // The largest values-per-row count that is common
    // (some rows may legitimately have fewer values when a
    // column is blank, so "most frequent" is not enough).
    final int typicalCount = rowCountFrequency.entries
        .where(
          (MapEntry<int, int> e) =>
              e.value >= 2 && e.value >= 0.3 * valueRows.length,
        )
        .fold<int>(
          0,
          (int best, MapEntry<int, int> e) => math.max(best, e.key),
        );

    final List<List<_Value>> normalRows = valueRows
        .where((List<_Value> row) => row.length <= typicalCount)
        .toList();

    final List<_Value> discovery = normalRows.length >= 2
        ? <_Value>[for (final List<_Value> row in normalRows) ...row]
        : values;

    // ---------------------------------------------------
    // Group values whose horizontal extents overlap.
    // Works for left-, centre- and right-aligned columns.
    // ---------------------------------------------------

    final List<_Value> sorted = List<_Value>.of(discovery)
      ..sort((_Value a, _Value b) => a.left.compareTo(b.left));

    final double pad = 0.35 * h;

    final List<List<_Value>> groups = <List<_Value>>[];
    double groupRight = double.negativeInfinity;

    for (final _Value v in sorted) {
      if (groups.isEmpty || v.left - groupRight > 2 * pad) {
        groups.add(<_Value>[v]);
        groupRight = v.right;
      } else {
        groups.last.add(v);
        groupRight = math.max(groupRight, v.right);
      }
    }

    final int maxCount =
        groups.map((List<_Value> g) => g.length).reduce(math.max);

    final List<List<_Value>> kept = groups
        .where(
          (List<_Value> g) =>
              maxCount < 2 || (g.length >= 2 && g.length >= 0.3 * maxCount),
        )
        .toList();

    final List<_Column> columns = kept
        .map(
          (List<_Value> g) => _Column(
            left: g.map((_Value v) => v.left).reduce(math.min),
            right: g.map((_Value v) => v.right).reduce(math.max),
            center: _median(g.map((_Value v) => v.cx).toList()),
            count: g.length,
            explicitCount: g.where((_Value v) => v.explicitUnit).length,
          ),
        )
        .toList()
      ..sort((_Column a, _Column b) => a.center.compareTo(b.center));

    // ---------------------------------------------------
    // Match headers to columns (closest pairs first).
    // ---------------------------------------------------

    final List<List<num>> pairs = <List<num>>[];

    for (int i = 0; i < headers.length; i++) {
      for (int j = 0; j < columns.length; j++) {
        final double d = columns[j].distanceTo(headers[i].x);

        if (d <= 4 * h) {
          pairs.add(<num>[
            i,
            j,
            d + 0.1 * (columns[j].center - headers[i].x).abs(),
          ]);
        }
      }
    }

    pairs.sort((List<num> a, List<num> b) => a[2].compareTo(b[2]));

    final Set<int> usedHeaders = <int>{};
    final Set<int> usedColumns = <int>{};

    for (final List<num> pair in pairs) {
      final int i = pair[0].toInt();
      final int j = pair[1].toInt();

      if (usedHeaders.contains(i) || usedColumns.contains(j)) continue;

      usedHeaders.add(i);
      usedColumns.add(j);

      columns[j]
        ..basis = headers[i].basis
        ..label = headers[i].label
        ..headed = true;
    }

    // One header left over and one unnamed column left
    // over: they belong together.
    final List<_Column> unnamed =
        columns.where((_Column c) => !c.headed).toList();

    final List<_Header> spareHeaders = <_Header>[
      for (int i = 0; i < headers.length; i++)
        if (!usedHeaders.contains(i)) headers[i],
    ];

    if (unnamed.length == 1 && spareHeaders.length == 1) {
      unnamed.first
        ..basis = spareHeaders.first.basis
        ..label = spareHeaders.first.label
        ..headed = true;
    }

    // ---------------------------------------------------
    // Unit-less number columns next to real unit columns
    // are usually "% NRV" columns: drop them.
    // ---------------------------------------------------

    if (columns.any((_Column c) => c.explicitCount >= 2)) {
      columns.removeWhere((_Column c) => !c.headed && c.explicitCount == 0);
    }

    // ---------------------------------------------------
    // Two columns, one header found: the other one is the
    // usual partner column.
    // ---------------------------------------------------

    if (columns.length == 2) {
      final _Column a = columns[0];
      final _Column b = columns[1];

      if (a.basis == NutritionColumnBasis.unknown &&
          b.basis != NutritionColumnBasis.unknown) {
        _setPartnerBasis(a, b.basis, serving);
      } else if (b.basis == NutritionColumnBasis.unknown &&
          a.basis != NutritionColumnBasis.unknown) {
        _setPartnerBasis(b, a.basis, serving);
      }
    }

    for (int j = 0; j < columns.length; j++) {
      if (columns[j].label.isEmpty) {
        columns[j].label = 'Detected column ${j + 1}';
      }
    }

    return columns;
  }

  static void _setPartnerBasis(
    _Column column,
    NutritionColumnBasis known,
    _Serving serving,
  ) {
    if (known == NutritionColumnBasis.perServing) {
      final bool ml = serving.unit == 'ml';

      column
        ..basis =
            ml ? NutritionColumnBasis.per100ml : NutritionColumnBasis.per100g
        ..label = ml ? 'Per 100 ml' : 'Per 100 g';
    } else {
      column
        ..basis = NutritionColumnBasis.perServing
        ..label = 'Per serving';
    }
  }

  static List<NutritionColumn> _toModelColumns(List<_Column> columns) {
    return <NutritionColumn>[
      for (int j = 0; j < columns.length; j++)
        NutritionColumn(
          id: _basisId(columns[j].basis, j),
          label: columns[j].label,
          basis: columns[j].basis,
          xCenter: columns[j].center,
        ),
    ];
  }

  static String _basisId(NutritionColumnBasis basis, int index) {
    switch (basis) {
      case NutritionColumnBasis.perServing:
        return 'per_serving';
      case NutritionColumnBasis.per100g:
        return 'per_100g';
      case NutritionColumnBasis.per100ml:
        return 'per_100ml';
      case NutritionColumnBasis.unknown:
        return 'unknown_$index';
    }
  }

  // =====================================================
  // NUTRIENT NAME FROM ONE LINE
  // =====================================================

  static final RegExp _parenUnitRe = RegExp(
    r'\(\s*(kcal|kj|g|mg|mcg|µg|μg|ug|ml)\s*\)',
    caseSensitive: false,
  );

  static final RegExp _descriptorRe = RegExp(
    r'\b(?:of\s+which|yang\s+terdiri\s+daripada|daripada\s+jumlah|'
    r'including|termasuk|di\s+mana)\b[:\s]*',
    caseSensitive: false,
  );

  static _Anchor? _anchorFromLine(
    OcrTextLine line,
    double nameLimit,
    double h,
  ) {
    final List<OcrWord> nameWords =
        line.words.where((OcrWord w) => w.centerX < nameLimit).toList();

    if (nameWords.isEmpty) return null;

    // A line whose words run on into the value columns
    // without any values is a sentence printed across the
    // table (a claim or footnote such as "a Cholesterol
    // Free Food / Makanan Bebas Kolesterol"), not a row.
    final bool textInValueColumns = line.words.any(
      (OcrWord w) =>
          w.centerX > nameLimit + h &&
          RegExp(r'[A-Za-z]{3}').hasMatch(w.text) &&
          _parseUnitText(w.text) == null &&
          _parseValueText(_trimPunct(w.text)) == null,
    );

    if (textInValueColumns && _valuesInLine(line).isEmpty) return null;

    // Split at big horizontal gaps: a logo caption on the
    // same row as a name ("HALAL ... Lemak") is a
    // separate piece of text. Keep the piece that names a
    // nutrient, otherwise the one nearest the values.
    final List<List<OcrWord>> segments = <List<OcrWord>>[
      <OcrWord>[nameWords.first],
    ];

    for (int i = 1; i < nameWords.length; i++) {
      if (nameWords[i].left - nameWords[i - 1].right > 2.5 * h) {
        segments.add(<OcrWord>[]);
      }

      segments.last.add(nameWords[i]);
    }

    List<OcrWord> words = segments.last;

    for (final List<OcrWord> segment in segments) {
      final String text = _norm(segment.map((OcrWord w) => w.text).join(' '));

      if (_canonical(text) != null) {
        words = segment;
        break;
      }
    }

    String? unit;
    final List<String> parts = <String>[];

    for (int i = 0; i < words.length; i++) {
      final String raw = words[i].text.trim();
      final String bare = _trimPunct(raw);

      if (bare.isEmpty) {
        // Keep the separator in "Tenaga / Energy".
        if (raw.contains('/')) parts.add('/');
        continue;
      }

      final String? wordUnit = _parseUnitText(bare);

      if (wordUnit != null) {
        unit ??= wordUnit;
        continue;
      }

      if (_parseValueText(bare.replaceAll(' ', '')) != null) continue;

      if (_parseNumberText(bare) != null) {
        final bool partOfName = (i > 0 &&
                RegExp(r'(omega|vitamin|vit\.?|\bb)$', caseSensitive: false)
                    .hasMatch(words[i - 1].text)) ||
            (i + 1 < words.length &&
                RegExp(r'[A-Za-z]{2}').hasMatch(words[i + 1].text));

        if (!partOfName) continue;
      }

      parts.add(raw);
    }

    String name = parts.join(' ');

    final RegExpMatch? parenUnit = _parenUnitRe.firstMatch(name);

    if (parenUnit != null) {
      unit ??= _parseUnitText(parenUnit.group(1)!);
      name = name.replaceRange(parenUnit.start, parenUnit.end, ' ');
    }

    name = name.replaceAll(_descriptorRe, ' ');

    name = _cleanName(name);

    if (_isInvalidName(name)) return null;

    return _Anchor(
      name: name,
      left: words.map((OcrWord w) => w.left).reduce(math.min),
      right: words.map((OcrWord w) => w.right).reduce(math.max),
      top: words.map((OcrWord w) => w.top).reduce(math.min),
      bottom: words.map((OcrWord w) => w.bottom).reduce(math.max),
      key: _canonical(_norm(name)),
      unit: unit,
    );
  }

  static String _cleanName(String text) {
    return text
        .replaceAll(RegExp(r'\s*/\s*'), ' / ')
        .replaceAll(RegExp(r'^[\s•·\-–—*:.,/]+'), '')
        .replaceAll(RegExp(r'[\s•·\-–—*:,/]+$'), '')
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isInvalidName(String name) {
    final String n = _norm(name);

    if (n.length < 2 || !RegExp(r'[a-z]{2}').hasMatch(n)) return true;

    if (_isTitle(n) ||
        _isServingInfo(n) ||
        _isFooter(n) ||
        _isNetWeight(n)) {
      return true;
    }

    final String header = _headerNorm(n);

    if (RegExp(r'\b(?:per|setiap)\s*(?:100|serving|hidangan|sajian)')
        .hasMatch(header)) {
      return true;
    }

    if (RegExp(r'^%|\bnrv\b|\brni\b|daily value|nilai rujukan|^dv\b')
        .hasMatch(n)) {
      return true;
    }

    return false;
  }

  // =====================================================
  // MERGE NAME LINES
  // =====================================================
  //
  // "Tenaga" + "/ Energy" on the same row   -> one row
  // "Lemak tepu" above "Saturated fat"      -> one row
  // "Tenaga 230 kJ" above "Energy 55 kcal"  -> one row
  // "Sugars 5g" above "Added sugars 2g"     -> two rows
  // =====================================================

  static List<_Anchor> _mergeAnchors(
    List<_Anchor> input,
    List<_Value> values,
    double h,
  ) {
    final List<_Anchor> anchors = List<_Anchor>.of(input)
      ..sort((_Anchor a, _Anchor b) => a.top.compareTo(b.top));

    // Units of values sitting clearly on this name line
    // (a value centred between two lines counts for
    // neither of them).
    Set<String> alignedUnits(_Anchor a) {
      final double core = 0.25 * (a.bottom - a.top);

      return <String>{
        for (final _Value v in values)
          if (v.cy > a.top + core && v.cy < a.bottom - core && v.left > a.left)
            v.unit,
      };
    }

    final List<_Anchor> merged = <_Anchor>[];

    for (final _Anchor a in anchors) {
      if (merged.isNotEmpty) {
        final _Anchor last = merged.last;

        final double overlap =
            math.min(last.bottom, a.bottom) - math.max(last.top, a.top);

        final double minHeight =
            math.min(last.bottom - last.top, a.bottom - a.top);

        final double horizontalGap =
            math.max(last.left, a.left) - math.min(last.right, a.right);

        final bool sameRow = overlap > 0.5 * minHeight && horizontalGap < 3 * h;

        bool stackedSameNutrient = false;

        if (!sameRow &&
            last.key != null &&
            last.key == a.key &&
            a.top - last.bottom < 0.8 * h) {
          final Set<String> u1 = alignedUnits(last);
          final Set<String> u2 = alignedUnits(a);

          final bool bothHaveValues = u1.isNotEmpty && u2.isNotEmpty;

          final bool energyPair = a.key == 'energy' &&
              ((u1.contains('kJ') && u2.contains('kcal')) ||
                  (u1.contains('kcal') && u2.contains('kJ')));

          stackedSameNutrient = !bothHaveValues || energyPair;
        }

        if (sameRow || stackedSameNutrient) {
          if (_norm(last.name) != _norm(a.name)) {
            if (sameRow) {
              last.name = a.left < last.left
                  ? _cleanName('${a.name} ${last.name}')
                  : _cleanName('${last.name} ${a.name}');
            } else {
              last.name = '${last.name} / ${a.name}';
            }
          }

          last
            ..left = math.min(last.left, a.left)
            ..right = math.max(last.right, a.right)
            ..top = math.min(last.top, a.top)
            ..bottom = math.max(last.bottom, a.bottom)
            ..key ??= a.key
            ..unit ??= a.unit;

          if (sameRow && last.key == null) {
            last.key = _canonical(_norm(last.name));
          }

          continue;
        }
      }

      merged.add(a);
    }

    return merged;
  }

  // =====================================================
  // FIX VALUES THAT LANDED IN THE WRONG COLUMN
  // =====================================================

  static void _repairRowColumns(
    List<List<_Value>> row,
    List<_Column> columns,
    _Anchor anchor,
  ) {
    final int n = columns.length;

    if (n < 2) return;

    final List<_Value> all = <_Value>[
      for (final List<_Value> cell in row) ...cell,
    ]..sort((_Value a, _Value b) => a.cx.compareTo(b.cx));

    // Energy written side by side: "230 kJ 55 kcal" in
    // every column. Pair them up in reading order.
    final bool energyRow = anchor.key == 'energy' ||
        all.any((_Value v) => v.unit == 'kJ' || v.unit == 'kcal');

    if (energyRow &&
        all.length == 2 * n &&
        row.any((List<_Value> cell) => cell.length != 2)) {
      for (final List<_Value> cell in row) {
        cell.clear();
      }

      for (int k = 0; k < all.length; k++) {
        row[k ~/ 2].add(all[k]);
      }

      return;
    }

    // Two values in one cell and the neighbouring cell
    // empty: move the closer one across.
    for (int j = 0; j < n; j++) {
      if (row[j].length < 2) continue;

      for (final int k in <int>[j - 1, j + 1]) {
        if (k < 0 || k >= n || row[k].isNotEmpty || row[j].length < 2) {
          continue;
        }

        // "5 µg (200 IU)" or "230 kJ / 55 kcal" in one
        // cell is legitimate: only move same-unit values.
        final Set<String> units = row[j]
            .map((_Value v) => v.unit)
            .where((String u) => u != '?')
            .toSet();

        if (units.length > 1) continue;

        _Value closest = row[j].first;

        for (final _Value v in row[j]) {
          if ((v.cx - columns[k].center).abs() <
              (closest.cx - columns[k].center).abs()) {
            closest = v;
          }
        }

        row[j].remove(closest);
        row[k].add(closest);
      }
    }
  }

  // =====================================================
  // "g" READ AS "9"
  // =====================================================
  //
  // In condensed label fonts ML Kit often reads "0.5g" as
  // "0.59". Such a value has lost its unit and has one
  // more decimal place than the rest of its column, which
  // is written with a fixed number of decimals.
  //
  //   column: 8.2g 0.1g 0.2g 0.59 0.0g   -> 0.59 is 0.5 g
  // =====================================================

  static final RegExp _trailingNineRe = RegExp(r'^(\d+)[.,](\d*)9$');

  static int _decimals(String raw) {
    final RegExpMatch? m =
        RegExp(r'[.,](\d+)').firstMatch(raw.replaceAll(' ', ''));

    return m == null ? 0 : m.group(1)!.length;
  }

  static void _fixGramsReadAsNine(
    List<List<List<_Value>>> cells,
    List<bool> removed,
    int columnCount,
    StringBuffer? debug,
    List<String> notes,
  ) {
    // Decimal places used for gram values anywhere in the
    // table ("31kcal" / "2mg" in the same column use other
    // conventions and must not count).
    final Map<int, int> tableGramDecimals = <int, int>{};

    for (int i = 0; i < cells.length; i++) {
      if (removed[i]) continue;

      for (final List<_Value> cell in cells[i]) {
        for (final _Value v in cell) {
          if (!v.explicitUnit || v.unit != 'g') continue;

          final int d = _decimals(v.raw);

          tableGramDecimals[d] = (tableGramDecimals[d] ?? 0) + 1;
        }
      }
    }

    for (int j = 0; j < columnCount; j++) {
      final Map<int, int> columnGramDecimals = <int, int>{};
      final Map<String, int> unitCounts = <String, int>{};

      for (int i = 0; i < cells.length; i++) {
        if (removed[i]) continue;

        for (final _Value v in cells[i][j]) {
          if (!v.explicitUnit) continue;

          unitCounts[v.unit] = (unitCounts[v.unit] ?? 0) + 1;

          if (v.unit == 'g') {
            final int d = _decimals(v.raw);

            columnGramDecimals[d] = (columnGramDecimals[d] ?? 0) + 1;
          }
        }
      }

      final Map<int, int> decimalCounts =
          columnGramDecimals.isNotEmpty ? columnGramDecimals : tableGramDecimals;

      if (decimalCounts.isEmpty || unitCounts.isEmpty) continue;

      final int typicalDecimals = decimalCounts.entries
          .reduce(
            (MapEntry<int, int> a, MapEntry<int, int> b) =>
                b.value > a.value ? b : a,
          )
          .key;

      final bool columnIsGrams = unitCounts.entries
              .reduce(
                (MapEntry<String, int> a, MapEntry<String, int> b) =>
                    b.value > a.value ? b : a,
              )
              .key ==
          'g';

      for (int i = 0; i < cells.length; i++) {
        if (removed[i]) continue;

        final bool rowIsGrams = cells[i].any(
          (List<_Value> cell) =>
              cell.any((_Value v) => v.explicitUnit && v.unit == 'g'),
        );

        final bool rowHasOtherUnit = cells[i].any(
          (List<_Value> cell) => cell.any(
            (_Value v) => v.explicitUnit && v.unit != 'g',
          ),
        );

        if (rowHasOtherUnit || !(rowIsGrams || columnIsGrams)) continue;

        for (final _Value v in cells[i][j]) {
          if (v.explicitUnit) continue;

          final String raw = v.raw.replaceAll(' ', '');

          final RegExpMatch? m = _trailingNineRe.firstMatch(raw);

          if (m == null) continue;

          if (_decimals(raw) != typicalDecimals + 1) continue;

          final double? fixed = _toAmount(
            m.group(2)!.isEmpty ? m.group(1)! : '${m.group(1)}.${m.group(2)}',
          );

          if (fixed == null) continue;

          debug?.writeln('[parser] "${v.raw}" read as ${_formatNumber(fixed)} g');
          notes.add('"${v.raw}" was read as ${_formatNumber(fixed)} g');

          v
            ..amount = fixed
            ..unit = 'g';
        }
      }
    }
  }

  // =====================================================
  // UNITS
  // =====================================================

  static const Map<String, String> _defaultUnits = <String, String>{
    'totalFat': 'g',
    'saturatedFat': 'g',
    'transFat': 'g',
    'monounsaturatedFat': 'g',
    'polyunsaturatedFat': 'g',
    'unsaturatedFat': 'g',
    'carbohydrate': 'g',
    'sugars': 'g',
    'addedSugars': 'g',
    'polyols': 'g',
    'fibre': 'g',
    'protein': 'g',
    'salt': 'g',
    'sodium': 'mg',
    'cholesterol': 'mg',
    'potassium': 'mg',
    'calcium': 'mg',
    'iron': 'mg',
  };

  static void _reconcileUnits(List<List<_Value>> row, _Anchor anchor) {
    final List<_Value> all = <_Value>[
      for (final List<_Value> cell in row) ...cell,
    ];

    final Map<String, int> counts = <String, int>{};

    for (final _Value v in all) {
      if (v.unit != '?') counts[v.unit] = (counts[v.unit] ?? 0) + 1;
    }

    String? majority;

    if (counts.isNotEmpty) {
      majority = counts.entries
          .reduce(
            (MapEntry<String, int> a, MapEntry<String, int> b) =>
                a.value >= b.value ? a : b,
          )
          .key;
    }

    final String? rowUnit =
        anchor.unit ?? majority ?? _defaultUnits[anchor.key];

    final bool microgram = _normallyMicrogram(anchor.name) ||
        all.any((_Value v) => v.unit == 'µg');

    final bool milligram =
        anchor.key == 'sodium' || anchor.key == 'cholesterol';

    for (final _Value v in all) {
      if (v.unit == '?' && rowUnit != null) v.unit = rowUnit;

      if (microgram && (v.unit == 'g' || v.unit == '?') && v.amount <= 1000) {
        v.unit = 'µg';
      }

      // "120 g sodium" is impossible: OCR lost the "m".
      if (milligram && v.unit == 'g' && v.amount >= 10) v.unit = 'mg';
    }
  }

  static bool _normallyMicrogram(String name) {
    return RegExp(
      r'vitamin\s*b\s*-?\s*12|vitamin\s*[dk]\b|folate|folic|biotin|iodin|'
      r'selenium|chromium|molybdenum',
    ).hasMatch(_norm(name));
  }

  // =====================================================
  // CROSS-CHECK PER SERVING vs PER 100 g
  // =====================================================
  //
  // per_serving ≈ per_100 × serving_size / 100
  //
  // Used to:
  //   - work out which of two unlabelled columns is which
  //   - infer a missing serving size
  //   - swap column labels that were assigned backwards
  //   - repair single OCR mistakes ("5.59" for "5.5g",
  //     a lost decimal point)
  // =====================================================

  static void _crossCheck({
    required List<_Column> columns,
    required List<_Anchor> anchors,
    required List<List<List<_Value>>> cells,
    required List<bool> removed,
    required _Serving serving,
    StringBuffer? debug,
    required List<String> notes,
  }) {
    int servingIndex = columns.indexWhere(
      (_Column c) => c.basis == NutritionColumnBasis.perServing,
    );

    int per100Index = columns.indexWhere(
      (_Column c) =>
          c.basis == NutritionColumnBasis.per100g ||
          c.basis == NutritionColumnBasis.per100ml,
    );

    List<List<_Value>> pairsFor(int a, int b) {
      final List<List<_Value>> result = <List<_Value>>[];

      for (int i = 0; i < anchors.length; i++) {
        if (removed[i]) continue;

        for (final _Value x in cells[i][a]) {
          final Iterable<_Value> match =
              cells[i][b].where((_Value y) => y.unit == x.unit);

          if (match.isNotEmpty) {
            result.add(<_Value>[x, match.first]);
            break;
          }
        }
      }

      return result;
    }

    // ---------------------------------------------------
    // Two unlabelled columns + known serving size.
    // ---------------------------------------------------

    if (servingIndex < 0 &&
        per100Index < 0 &&
        columns.length == 2 &&
        serving.amount != null &&
        (serving.amount! - 100).abs() > 2) {
      final double r = serving.amount! / 100;

      final List<double> ratios = pairsFor(0, 1)
          .where((List<_Value> p) => p[0].amount >= 1 && p[1].amount >= 1)
          .map((List<_Value> p) => p[1].amount / p[0].amount)
          .toList();

      if (ratios.length >= 2) {
        final double m = _median(ratios);
        final bool ml = serving.unit == 'ml';

        int? per100;

        if ((m / r - 1).abs() < 0.2) per100 = 0;
        if ((m * r - 1).abs() < 0.2) per100 = 1;

        if (per100 != null) {
          final int other = 1 - per100;

          columns[per100]
            ..basis =
                ml ? NutritionColumnBasis.per100ml : NutritionColumnBasis.per100g
            ..label = ml ? 'Per 100 ml' : 'Per 100 g';

          columns[other]
            ..basis = NutritionColumnBasis.perServing
            ..label = 'Per serving';

          servingIndex = other;
          per100Index = per100;

          debug?.writeln('[parser] column bases inferred from ratio');
          notes.add('Column headings were worked out from the values');
        }
      }
    }

    if (servingIndex < 0 || per100Index < 0) return;

    List<List<_Value>> pairs = pairsFor(servingIndex, per100Index);

    // ---------------------------------------------------
    // Missing serving size: derive it from the label.
    // ---------------------------------------------------

    if (serving.amount == null) {
      final List<double> ratios = pairs
          .where((List<_Value> p) => p[0].amount > 0 && p[1].amount >= 1)
          .map((List<_Value> p) => p[0].amount / p[1].amount)
          .toList();

      if (ratios.length >= 3) {
        final double m = _median(ratios);

        final int close =
            ratios.where((double x) => (x / m - 1).abs() < 0.1).length;

        if (m > 0 && close >= 0.6 * ratios.length) {
          serving.amount = _round(m * 100, places: 1);
          serving.unit =
              columns[per100Index].basis == NutritionColumnBasis.per100ml
                  ? 'ml'
                  : 'g';

          debug?.writeln(
            '[parser] serving size inferred: ${serving.amount} ${serving.unit}',
          );
          notes.add(
            'Serving size worked out from the values: '
            '${_formatNumber(serving.amount!)} ${serving.unit}',
          );
        }
      }
    }

    if (serving.amount == null) return;

    final double r = serving.amount! / 100;

    if ((r - 1).abs() < 0.02) return;

    // ---------------------------------------------------
    // Labels assigned the wrong way round?
    // ---------------------------------------------------

    int comparable = 0;
    int flipped = 0;

    for (final List<_Value> p in pairs) {
      if (p[0].amount < 1 || p[1].amount < 1) continue;

      comparable++;

      final double actual = p[0].amount / p[1].amount;

      if ((actual / r - 1).abs() > 0.35 && (actual * r - 1).abs() < 0.2) {
        flipped++;
      }
    }

    if (comparable >= 3 && flipped >= 0.7 * comparable) {
      final _Column a = columns[servingIndex];
      final _Column b = columns[per100Index];

      final NutritionColumnBasis basis = a.basis;
      final String label = a.label;

      a
        ..basis = b.basis
        ..label = b.label;

      b
        ..basis = basis
        ..label = label;

      final int swap = servingIndex;
      servingIndex = per100Index;
      per100Index = swap;

      pairs = pairsFor(servingIndex, per100Index);

      debug?.writeln('[parser] swapped per-serving / per-100 labels');
      notes.add('Per-serving and per-100 columns were swapped to match the values');
    }

    // ---------------------------------------------------
    // Repair single OCR mistakes.
    // ---------------------------------------------------

    for (final List<_Value> p in pairs) {
      final _Value s = p[0];
      final _Value c = p[1];

      if (s.amount < 1 && c.amount < 1) continue;
      if (c.amount <= 0) continue;

      if ((s.amount / c.amount / r - 1).abs() <= 0.3) continue;

      bool fixed = false;

      for (final double candidate in _alternatives(s)) {
        if ((candidate / c.amount / r - 1).abs() <= 0.12) {
          debug?.writeln('[parser] corrected ${s.raw} -> $candidate');
          notes.add('"${s.raw}" was corrected to ${_formatNumber(candidate)}');
          s.amount = candidate;
          fixed = true;
          break;
        }
      }

      if (fixed) continue;

      for (final double candidate in _alternatives(c)) {
        if (candidate > 0 && (s.amount / candidate / r - 1).abs() <= 0.12) {
          debug?.writeln('[parser] corrected ${c.raw} -> $candidate');
          notes.add('"${c.raw}" was corrected to ${_formatNumber(candidate)}');
          c.amount = candidate;
          break;
        }
      }
    }
  }

  static List<double> _alternatives(_Value v) {
    final List<double> result = <double>[];

    final String digits = v.raw.replaceAll(RegExp(r'[^0-9.,]'), '');

    // "5.59" where the "9" was really the unit "g".
    if (!v.explicitUnit && digits.length >= 2 && digits.endsWith('9')) {
      final double? cut = _toAmount(digits.substring(0, digits.length - 1));

      if (cut != null) result.add(cut);
    }

    // "125" where the decimal point was lost (12.5).
    if (!digits.contains('.') && !digits.contains(',') && v.amount >= 10) {
      result
        ..add(v.amount / 10)
        ..add(v.amount / 100);
    }

    return result;
  }

  // =====================================================
  // CANONICAL NUTRIENT KEYS (English + Bahasa Melayu)
  // =====================================================
  //
  // Order matters: specific names before generic ones.
  // =====================================================

  static final List<MapEntry<String, RegExp>> _nutrientKeys =
      <MapEntry<String, RegExp>>[
    MapEntry<String, RegExp>(
      'energy',
      RegExp(r'\b(?:energy|tenaga|calories?|kalori)\b'),
    ),
    MapEntry<String, RegExp>('transFat', RegExp(r'\btrans\b')),
    MapEntry<String, RegExp>(
      'monounsaturatedFat',
      RegExp(r'mono\s*-?\s*unsaturat|tak\s*tepu\s*(?:tunggal|mono)|lemak\s*mono'),
    ),
    MapEntry<String, RegExp>(
      'polyunsaturatedFat',
      RegExp(r'poly\s*-?\s*unsaturat|tak\s*tepu\s*(?:poli|majmuk)|lemak\s*poli'),
    ),
    MapEntry<String, RegExp>('unsaturatedFat', RegExp(r'unsaturat|tak\s*tepu')),
    MapEntry<String, RegExp>(
      'saturatedFat',
      RegExp(r'saturat|lemak\s*tepu|\btepu\b'),
    ),
    MapEntry<String, RegExp>('cholesterol', RegExp(r'cholesterol|kolesterol')),
    MapEntry<String, RegExp>('totalFat', RegExp(r'\bfats?\b|\blemak\b')),
    MapEntry<String, RegExp>(
      'addedSugars',
      RegExp(r'added\s*sugar|gula\s*tambahan'),
    ),
    MapEntry<String, RegExp>(
      'polyols',
      RegExp(r'polyol|sugar\s*alcohol|gula\s*alkohol'),
    ),
    MapEntry<String, RegExp>('sugars', RegExp(r'\bsugars?\b|\bgula\b')),
    MapEntry<String, RegExp>(
      'fibre',
      RegExp(r'fib(?:re|er)|\bserat\b|serabut|gentian'),
    ),
    MapEntry<String, RegExp>(
      'carbohydrate',
      RegExp(r'carbohydrate|karbohidrat|\bcarbs?\b'),
    ),
    MapEntry<String, RegExp>('protein', RegExp(r'protein')),
    MapEntry<String, RegExp>('sodium', RegExp(r'sodium|natrium')),
    MapEntry<String, RegExp>('salt', RegExp(r'\bsalt\b|\bgaram\b')),
    MapEntry<String, RegExp>('potassium', RegExp(r'potassium|kalium')),
    MapEntry<String, RegExp>('calcium', RegExp(r'calcium|kalsium')),
    MapEntry<String, RegExp>('iron', RegExp(r'\biron\b|\bbesi\b')),
  ];

  static String? _canonical(String normalizedText) {
    for (final MapEntry<String, RegExp> entry in _nutrientKeys) {
      if (entry.value.hasMatch(normalizedText)) return entry.key;
    }

    final RegExpMatch? vitamin =
        RegExp(r'vitamin\s*([a-z])\s*-?\s*(\d{0,2})\b').firstMatch(normalizedText);

    if (vitamin != null) {
      return 'vitamin_${vitamin.group(1)}${vitamin.group(2)}';
    }

    return null;
  }

  // =====================================================
  // TEXT CLASSIFIERS
  // =====================================================

  static const List<String> _titles = <String>[
    'nutrition information',
    'nutritional information',
    'nutrition facts',
    'nutrition fact',
    'nutrition panel',
    'keterangan pemakanan',
    'maklumat pemakanan',
    'maklumat nutrisi',
    'fakta pemakanan',
    'nilai pemakanan',
  ];

  static bool _isTitle(String t) => _titles.any(t.contains);

  static final RegExp _servingInfoRe = RegExp(
    r'serving\s*size|saiz\s*hidangan|saiz\s*sajian|servings?\s*per\s|'
    r'hidangan\s*(?:setiap|per|dalam|bagi)\s*'
    r'(?:bungkusan|pek|paket|pakej|botol|kotak|tin|bekas|beg)|'
    r'bilangan\s*hidangan|number\s*of\s*servings',
  );

  static bool _isServingInfo(String t) => _servingInfoRe.hasMatch(t);

  static final RegExp _netWeightRe = RegExp(
    r'\bnett?\b|berat\s*bersih|isi\s*padu|kandungan\s*bersih|\bnet\s*(?:wt|weight|vol)',
  );

  static bool _isNetWeight(String t) => _netWeightRe.hasMatch(t);

  static const List<String> _footerPhrases = <String>[
    'cholesterol free',
    'bebas kolesterol',
    'ingredient',
    'ramuan',
    'kandungan:',
    'cara penggunaan',
    'cara penyimpanan',
    'cara penjagaan',
    'langkah penjagaan',
    'storage',
    'store in',
    'simpan di',
    'manufactured',
    'dikilangkan',
    'dikeluarkan oleh',
    'distributed',
    'diedarkan',
    'allergen',
    'alergen',
    'contains',
    'mengandungi',
    'daily value',
    'nilai harian',
    'based on a',
    'based on 2',
    'berdasarkan',
    'best before',
    'tarikh luput',
    'expiry',
    'made in',
    'produk malaysia',
    'product of',
  ];

  // Multi-word footer phrases are also matched with a few
  // OCR mistakes allowed ("a Chalesteral Free Fond").
  static const List<String> _fuzzyFooterPhrases = <String>[
    'cholesterol free food',
    'makanan bebas kolesterol',
    'cholesterol free',
    'bebas kolesterol',
    'free from cholesterol',
    'daily values',
    'nilai harian',
    'best before',
    'tarikh luput',
    'cara penyimpanan',
    'cara penggunaan',
  ];

  static bool _isFooter(String t) {
    if (_footerPhrases.any(t.contains)) return true;

    final List<String> words = t
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(' ')
        .where((String w) => w.isNotEmpty)
        .toList();

    for (final String phrase in _fuzzyFooterPhrases) {
      final int size = phrase.split(' ').length;
      final int allowed = math.max(1, (phrase.length * 0.15).floor());

      for (int i = 0; i + size <= words.length; i++) {
        final String window = words.sublist(i, i + size).join(' ');

        if ((window.length - phrase.length).abs() > allowed) continue;

        if (_editDistance(window, phrase) <= allowed) return true;
      }
    }

    return false;
  }

  static int _editDistance(String a, String b) {
    List<int> previous = List<int>.generate(b.length + 1, (int i) => i);

    for (int i = 1; i <= a.length; i++) {
      final List<int> current = List<int>.filled(b.length + 1, 0);

      current[0] = i;

      for (int j = 1; j <= b.length; j++) {
        final int cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;

        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }

      previous = current;
    }

    return previous[b.length];
  }

  // =====================================================
  // HELPERS
  // =====================================================

  static String _norm(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[–—]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _headerNorm(String text) {
    String t = _norm(text);

    t = t.replaceAll(RegExp(r'\b1[o0][o0]'), '100');
    t = t.replaceAll(RegExp(r'100\s*m[il1|]\b'), '100ml');
    t = t.replaceAll(RegExp(r'100\s*[gq]\b'), '100g');

    return t;
  }

  static String _trimPunct(String text) {
    return text
        .trim()
        .replaceAll(RegExp(r'''^[()\[\]{}:;,*"'|/.•·]+'''), '')
        .replaceAll(RegExp(r'''[()\[\]{}:;,*"'|/.•·]+$'''), '');
  }

  static double? _simpleNumber(String? value) {
    if (value == null) return null;

    return _toAmount(value.trim());
  }

  static String _singularize(String value) {
    final String text = value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    const Map<String, String> replacements = <String, String>{
      'pcs': 'piece',
      'pc': 'piece',
      'pieces': 'piece',
      'tablets': 'tablet',
      'capsules': 'capsule',
      'sachets': 'sachet',
      'bottles': 'bottle',
      'cups': 'cup',
      'bars': 'bar',
      'slices': 'slice',
      'scoops': 'scoop',
      'sticks': 'stick',
      'cans': 'can',
      'packets': 'packet',
      'packs': 'pack',
      'chips': 'chip',
      'biscuits': 'biscuit',
      'crackers': 'cracker',
    };

    return replacements[text] ?? text;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;

    final List<double> sorted = List<double>.of(values)..sort();
    final int middle = sorted.length ~/ 2;

    if (sorted.length.isOdd) return sorted[middle];

    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static double _round(double value, {int places = 3}) {
    final num factor = math.pow(10, places);

    return (value * factor).round() / factor;
  }

  static String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
