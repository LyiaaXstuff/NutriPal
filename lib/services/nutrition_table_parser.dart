import 'dart:math' as math;

import '../models/nutrition_label_data.dart';

/// Image coordinates. Fixtures use the same parser as native camera OCR.
class NutritionOcrToken {
  final String text;
  final double left, top, right, bottom;
  final double? confidence;
  const NutritionOcrToken({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.confidence,
  });
  double get x => (left + right) / 2;
  double get y => (top + bottom) / 2;
  double get height => bottom - top;
}

class _Line {
  final List<NutritionOcrToken> tokens;
  final double y;
  late final String text = [
    for (var i = 0; i < tokens.length; i++)
      '${i == 0
          ? ''
          : tokens[i].left - tokens[i - 1].right > tokens[i].height * 2.5
          ? '\t'
          : ' '}${tokens[i].text}',
  ].join();
  _Line(this.tokens, this.y) {
    tokens.sort((a, b) => a.left.compareTo(b.left));
  }
  // Preserve positions when OCR puts several words/values in one element.
  double xAt(int offset) {
    var start = 0;
    for (final token in tokens) {
      final end = start + token.text.length;
      if (offset <= end) {
        return token.left +
            (token.right - token.left) *
                ((offset - start) / math.max(1, token.text.length)).clamp(0, 1);
      }
      start = end + 1;
    }
    return tokens.last.right;
  }

  double center(int start, int end) => (xAt(start) + xAt(end)) / 2;
}

class _Column {
  final NutritionColumnBasis basis;
  final String label;
  double x;
  final double y;
  _Column(this.basis, this.label, this.x, this.y);
}

class _Value {
  final NutritionQuantity quantity;
  final double x;
  final int start, end;
  const _Value(this.quantity, this.x, this.start, this.end);
}

class _Record {
  String name, source;
  final double y;
  final List<_Value> values;
  final bool needsReview;
  _Record(
    this.name,
    this.source,
    this.y,
    this.values, {
    this.needsReview = false,
  });
}

/// Reconstructs geometry before parsing names or values. There is no nutrient
/// allowlist. Missing/ambiguous cells stay visible and are excluded from legacy
/// calculations instead of borrowing a neighbouring value.
class NutritionTableParser {
  static const _unit = r'(?:kcal|kJ|mcg|µg|μg|ug|mg|kg|g|ml|IU|%)';
  static const _number =
      r'(?:\d{1,3}(?:[ ,.]\d{3})+(?:[.,]\d+)?|\d+(?:[.,]\d+)?|[.,]\d+)';
  static final _amount = RegExp(
    '(?<![a-zA-Z0-9])([<>=≤≥] *)?($_number)(?: *($_unit))?(?![a-zA-Z0-9])',
    caseSensitive: false,
  );
  static final _header = RegExp(
    r'(?:amount\s+)?(?:per|setiap)\s*(100\s*(?:ml|g)|serving|serve|portion|hidangan)'
    r'|%\s*(?:daily\s*value|dv|rni|ri|nrv|nilai\s*harian)'
    r'|(?:daily\s*value|nilai\s*harian)\s*%?',
    caseSensitive: false,
  );
  static final _metadata = RegExp(
    r'^(?:nutrition(?:al)?\s+(?:facts?|information|panel)|maklumat\s+pemakanan|'
    r'fakta\s+pemakanan|nilai\s+pemakanan|serving\s*size|saiz\s*hidangan|'
    r'(?:about\s+)?\d+\s+servings?\s+per|servings?\s+per|hidangan\s+setiap\s+(?:pek|bungkusan)|'
    r'net\s+(?:weight|contents)|berat\s+bersih|ingredients?|ramuan|'
    r'contains\b|allergen|storage|directions|distributed|manufactured|'
    r'percent\s+daily|the\s+%|\*|recommended\s+(?:daily|nutrient)|'
    r'reference\s+intake|not\s+a\s+significant)',
    caseSensitive: false,
  );

  static NutritionLabelData parse(
    List<NutritionOcrToken> input, {
    String rawText = '',
    double skew = 0,
  }) {
    final tokens = _uniqueTokens(input);
    if (tokens.isEmpty) return NutritionLabelData(rawText: rawText);
    final height = _median(tokens.map((t) => t.height).toList());
    final lines = _lines(tokens, height, skew);
    final columns = _columns(lines, height);
    final records = <_Record>[];
    final warnings = <String>[];
    String? pendingName;
    double? pendingY;
    var inTable = columns.isNotEmpty;
    for (final line in lines) {
      final text = line.text.trim();
      if (_metadata.hasMatch(text) ||
          _header.hasMatch(text) ||
          _isHeaderFragment(text)) {
        pendingName = null;
        if (RegExp(
          r'^(ingredients?|ramuan|\*|percent daily|the %|reference intake|not a significant)',
          caseSensitive: false,
        ).hasMatch(text)) {
          break;
        }
        continue;
      }
      if (columns.isNotEmpty &&
          line.y < columns.map((c) => c.y).reduce(math.min) - height) {
        continue;
      }
      final values = _values(line, columns, height);
      if (values.isEmpty) {
        // Preserve unreadable rows and wrapped nutrient names inside the table.
        if (inTable &&
            _isName(text) &&
            text.length < 100 &&
            (columns.isEmpty ||
                line.tokens.first.left < columns.first.x - height)) {
          if (pendingName != null) {
            records.add(
              _Record(_cleanName(pendingName), pendingName, pendingY!, []),
            );
          }
          pendingName = text;
          pendingY = line.y;
        }
        continue;
      }
      var questionable = line.tokens.any(
        (t) => t.confidence != null && t.confidence! < 0.5,
      );
      var name = text.substring(0, values.first.start).trim();
      final rowUnit = _nameUnit(name);
      name = _cleanName(name);
      final tail = text
          .substring(
            values.first.end,
            values.length > 1 ? values[1].start : text.length,
          )
          .trim();
      // US labels put the amount inside "Includes 2g Added Sugars".
      if (RegExp(r'^includes?$', caseSensitive: false).hasMatch(name) &&
          _isName(tail)) {
        name = tail;
      } else if (_isName(tail)) {
        questionable = true;
        warnings.add('Check this row against the photo: $text');
      }
      if (pendingName != null) {
        if (line.y - pendingY! <= height * 1.8 &&
            (name.isEmpty || _continuation(pendingName, name))) {
          name = '$pendingName $name'.trim();
        } else {
          records.add(
            _Record(_cleanName(pendingName), pendingName, pendingY, []),
          );
        }
        pendingName = null;
      }
      // Only a second energy unit can safely continue a previous value row.
      if (name.isEmpty) {
        if (records.isNotEmpty &&
            records.last.values.isNotEmpty &&
            line.y - records.last.y < height * 1.6 &&
            values.every(
              (v) => v.quantity.unit == 'kJ' || v.quantity.unit == 'kcal',
            ) &&
            records.last.values.every(
              (v) => v.quantity.unit == 'kJ' || v.quantity.unit == 'kcal',
            )) {
          records.last.values.addAll(values);
          records.last.source += '\n$text';
        } else {
          warnings.add('Unmatched values: $text');
        }
        continue;
      }
      if (!_isName(name)) continue;
      final resolved = values.map((v) {
        var unit = v.quantity.unit;
        if (unit.isEmpty) {
          unit =
              rowUnit ??
              (RegExp(r'^calories?$', caseSensitive: false).hasMatch(name)
                  ? 'kcal'
                  : '');
        }
        return _Value(
          NutritionQuantity(
            amount: v.quantity.amount,
            numberText: v.quantity.numberText,
            unit: unit,
            comparator: v.quantity.comparator,
            rawText: v.quantity.rawText,
          ),
          v.x,
          v.start,
          v.end,
        );
      }).toList();
      records.add(
        _Record(name, text, line.y, resolved, needsReview: questionable),
      );
      inTable = true;
    }
    if (pendingName != null) {
      records.add(_Record(_cleanName(pendingName), pendingName, pendingY!, []));
    }
    records.sort((a, b) => a.y.compareTo(b.y));
    _resolveColumns(columns, records, height, warnings);
    final publicColumns = <NutritionColumn>[
      for (var i = 0; i < columns.length; i++)
        NutritionColumn(
          id: 'column_$i',
          label: columns[i].label,
          basis: columns[i].basis,
        ),
    ];
    final rows = <NutritionRow>[];
    for (final record in records) {
      final buckets = List.generate(
        columns.length,
        (_) => <NutritionQuantity>[],
      );
      var ambiguous = record.needsReview;
      for (final value in record.values) {
        if (columns.isEmpty) continue;
        final distances = [for (final c in columns) (c.x - value.x).abs()];
        final index = distances.indexOf(distances.reduce(math.min));
        final sortedDistances = [...distances]..sort();
        if (sortedDistances.length > 1 &&
            sortedDistances[1] - sortedDistances[0] < height * 0.5) {
          ambiguous = true;
        }
        var quantity = value.quantity;
        if (columns[index].basis == NutritionColumnBasis.dailyValue &&
            !RegExp(_unit, caseSensitive: false).hasMatch(quantity.rawText)) {
          quantity = NutritionQuantity(
            amount: quantity.amount,
            numberText: quantity.numberText,
            comparator: quantity.comparator,
            unit: '%',
            rawText: quantity.rawText,
          );
        }
        buckets[index].add(quantity);
      }
      final cells = <String, NutritionCell>{};
      for (var i = 0; i < columns.length; i++) {
        final q = buckets[i];
        final energyPair =
            q.length == 2 &&
            q.map((q) => q.unit).toSet().containsAll(['kJ', 'kcal']);
        final uncertain =
            ambiguous ||
            q.isEmpty ||
            (q.length > 1 && !energyPair) ||
            q.any((q) => q.unit.isEmpty) ||
            (columns[i].basis == NutritionColumnBasis.dailyValue &&
                q.any((q) => q.unit != '%')) ||
            (columns[i].basis != NutritionColumnBasis.dailyValue &&
                q.any((q) => q.unit == '%'));
        cells[publicColumns[i].id] = NutritionCell(
          quantities: List.unmodifiable(q),
          needsReview: uncertain,
          rawText: q.map((q) => q.rawText).join(' / '),
        );
      }
      rows.add(
        NutritionRow(
          id: 'row_${rows.length}',
          name: record.name,
          cells: Map.unmodifiable(cells),
          sourceText: record.source,
          needsReview: ambiguous || cells.values.any((c) => c.needsReview),
        ),
      );
    }
    if (rows.any((r) => r.needsReview)) {
      warnings.add(
        'Some cells could not be read confidently. Compare marked rows with the photo or retake it.',
      );
    }
    return fromTable(
      columns: publicColumns,
      rows: rows,
      rawText: rawText.isEmpty ? lines.map((l) => l.text).join('\n') : rawText,
      metadataText: lines.map((l) => l.text).join('\n'),
      warnings: warnings,
    );
  }

  /// Shared serving metadata and conservative legacy calculation projections.
  static NutritionLabelData fromTable({
    required List<NutritionColumn> columns,
    required List<NutritionRow> rows,
    required String rawText,
    String? metadataText,
    List<String> warnings = const [],
  }) {
    final serving = _servingMetadata(metadataText ?? rawText);
    NutritionValues? projection(NutritionColumnBasis basis) {
      final matches = columns.where((c) => c.basis == basis).toList();
      return matches.length == 1
          ? _legacyValues(rows, matches.single.id)
          : null;
    }

    final per100Columns = columns
        .where(
          (c) =>
              c.basis == NutritionColumnBasis.per100g ||
              c.basis == NutritionColumnBasis.per100ml,
        )
        .toList();
    final per100 = per100Columns.length == 1 ? per100Columns.single : null;
    return NutritionLabelData(
      rawText: rawText,
      columns: List.unmodifiable(columns),
      rows: List.unmodifiable(rows),
      extractionWarnings: List.unmodifiable(warnings.toSet()),
      servingSizeAmount: serving.amount,
      servingSizeUnit: serving.unit,
      servingUnitAmount: serving.count,
      servingUnitName: serving.item,
      servingsPerPackage: serving.servings,
      perServing: projection(NutritionColumnBasis.perServing),
      per100: per100 == null ? null : _legacyValues(rows, per100.id),
      per100Unit: per100 == null
          ? null
          : per100.basis == NutritionColumnBasis.per100g
          ? 'g'
          : 'ml',
    );
  }

  static NutritionColumnBasis basisForHeader(String label) {
    final m = _header.firstMatch(label.replaceAll(RegExp(r'\s+'), ' '));
    if (m == null) return NutritionColumnBasis.unknown;
    final lower = m.group(0)!.toLowerCase();
    if (lower.contains('100')) {
      return lower.contains('ml')
          ? NutritionColumnBasis.per100ml
          : NutritionColumnBasis.per100g;
    }
    return RegExp(r'daily|nilai|%').hasMatch(lower)
        ? NutritionColumnBasis.dailyValue
        : NutritionColumnBasis.perServing;
  }

  static bool isMetadata(String text) => _metadata.hasMatch(text);
  static String cleanNutrientName(String text) => _cleanName(text);
  static String? unitInName(String text) => _nameUnit(text);

  /// Parse only inside a single Azure cell; numbers never migrate between cells.
  static NutritionCell parsePrintedCell(
    String text, {
    required NutritionColumnBasis basis,
    String? rowUnit,
    bool needsReview = false,
  }) {
    final matches = _amount.allMatches(text).toList();
    final quantities = <NutritionQuantity>[];
    for (final m in matches) {
      final amount = _parseNumber(m.group(2)!);
      if (amount == null || !amount.isFinite || amount < 0) continue;
      final explicitUnit = m.group(3) ?? '';
      final unit = explicitUnit.isNotEmpty
          ? _normaliseUnit(explicitUnit)
          : basis == NutritionColumnBasis.dailyValue
          ? '%'
          : rowUnit ?? '';
      quantities.add(
        NutritionQuantity(
          amount: amount,
          numberText: m.group(2)!,
          unit: unit,
          comparator: (m.group(1) ?? '').trim(),
          rawText: m.group(0)!.trim(),
        ),
      );
    }
    final remainder = text
        .replaceAll(_amount, '')
        .replaceAll(RegExp(r'[\s/();]+'), '');
    final energyPair =
        quantities.length == 2 &&
        quantities.map((q) => q.unit).toSet().containsAll(['kJ', 'kcal']);
    return NutritionCell(
      quantities: List.unmodifiable(quantities),
      rawText: text,
      needsReview:
          needsReview ||
          remainder.isNotEmpty ||
          quantities.isEmpty ||
          (quantities.length > 1 && !energyPair) ||
          quantities.any(
            (q) =>
                q.unit.isEmpty ||
                ((q.unit == '%') != (basis == NutritionColumnBasis.dailyValue)),
          ),
    );
  }

  static List<NutritionOcrToken> _uniqueTokens(List<NutritionOcrToken> input) {
    final result = <NutritionOcrToken>[];
    for (final t in input) {
      if (t.text.trim().isEmpty || t.height <= 0 || t.right <= t.left) continue;
      final duplicate = result.any(
        (r) =>
            r.text == t.text &&
            (r.left - t.left).abs() < t.height * 0.2 &&
            (r.right - t.right).abs() < t.height * 0.2 &&
            (r.y - t.y).abs() < t.height * 0.2,
      );
      if (!duplicate) result.add(t);
    }
    return result;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 12;
    values.sort();
    return values[values.length ~/ 2];
  }

  static List<_Line> _lines(
    List<NutritionOcrToken> tokens,
    double height,
    double skew,
  ) {
    double y(NutritionOcrToken t) => t.y - t.x * skew;
    final sorted = [...tokens]..sort((a, b) => y(a).compareTo(y(b)));
    final groups = <List<NutritionOcrToken>>[];
    for (final t in sorted) {
      if (groups.isEmpty ||
          y(t) - _median(groups.last.map(y).toList()) > height * 0.48 ||
          y(t) - y(groups.last.first) > height * 0.8) {
        groups.add([t]);
      } else {
        groups.last.add(t);
      }
    }
    return [for (final g in groups) _Line(g, _median(g.map(y).toList()))];
  }

  static bool _isHeaderFragment(String text) => RegExp(
    r'^(?:(?:per|setiap|serving|serve|portion|hidangan|100\s*(?:g|ml)|%|daily|value|rni|ri|nrv|amount)\s*)+$',
    caseSensitive: false,
  ).hasMatch(text.trim());

  static List<_Column> _columns(List<_Line> lines, double height) {
    final result = <_Column>[];
    void add(String label, double x, double y) {
      final lower = label.toLowerCase();
      final basis = lower.contains('100')
          ? (lower.contains('ml')
                ? NutritionColumnBasis.per100ml
                : NutritionColumnBasis.per100g)
          : RegExp(r'daily|nilai|%').hasMatch(lower)
          ? NutritionColumnBasis.dailyValue
          : NutritionColumnBasis.perServing;
      if (result.any((c) => c.basis == basis && (c.x - x).abs() < height * 3)) {
        return;
      }
      result.add(_Column(basis, label.trim(), x, y));
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_metadata.hasMatch(line.text)) continue;
      for (final m in _header.allMatches(line.text)) {
        add(m.group(0)!, line.center(m.start, m.end), line.y);
      }
      // "Per" above "100 g" / "Serving", including split OCR words.
      for (final t in line.tokens) {
        if (!RegExp(
          r'^(per|setiap|%|daily)$',
          caseSensitive: false,
        ).hasMatch(t.text.trim())) {
          continue;
        }
        for (var j = i + 1; j < math.min(lines.length, i + 3); j++) {
          if (lines[j].y - line.y > height * 2.5) break;
          final near = lines[j].tokens
              .where((n) => (n.x - t.x).abs() < height * 3)
              .toList();
          final m = _header.firstMatch(
            '${t.text} ${near.map((n) => n.text).join(' ')}',
          );
          if (m != null && near.isNotEmpty) {
            add(
              m.group(0)!,
              (near.first.left + near.last.right) / 2,
              lines[j].y,
            );
            break;
          }
        }
      }
    }
    result.sort((a, b) => a.x.compareTo(b.x));
    return result;
  }

  static List<_Value> _values(
    _Line line,
    List<_Column> columns,
    double height,
  ) {
    final result = <_Value>[];
    final text = line.text;
    // Mask numeric nutrient identifiers without moving character offsets.
    final searchable = text.replaceAllMapped(
      RegExp(
        r'\b(?:omega[\s-]*\d+|vitamin\s+(?:[a-z]\d+|b\s+\d+))\b',
        caseSensitive: false,
      ),
      (m) => m.group(0)!.replaceAll(RegExp(r'\d'), 'x'),
    );
    for (final m in _amount.allMatches(searchable)) {
      var unit = m.group(3) ?? '';
      final number = m.group(2)!;
      final before = text.substring(0, m.start).trim();
      if (unit.isEmpty &&
          (RegExp(
                r'(?:omega\s*-?|vitamin\s*[a-z]?)$',
                caseSensitive: false,
              ).hasMatch(before) ||
              (m.start > 0 &&
                  RegExp(r'[a-zA-Z]-$')
                      .hasMatch(text.substring(0, m.start))))) {
        continue;
      }
      final after = text.substring(m.end).trimLeft();
      if (unit.isEmpty && RegExp(r'^[a-zA-Zµμ]').hasMatch(after)) continue;
      final x = line.center(m.start, m.end);
      if (unit.isEmpty &&
          before.isEmpty &&
          !columns.any((c) => (c.x - x).abs() < height * 6)) {
        continue;
      }
      unit = _normaliseUnit(unit);
      final amount = _parseNumber(number);
      if (amount == null) continue;
      result.add(
        _Value(
          NutritionQuantity(
            amount: amount,
            numberText: number,
            unit: unit,
            comparator: (m.group(1) ?? '').trim(),
            rawText: m.group(0)!.trim(),
          ),
          x,
          m.start,
          m.end,
        ),
      );
    }
    return result;
  }

  static String _normaliseUnit(String unit) {
    switch (unit.toLowerCase()) {
      case 'kj':
        return 'kJ';
      case 'iu':
        return 'IU';
      case 'μg':
      case 'ug':
      case 'µg':
        return 'µg';
      default:
        return unit.toLowerCase();
    }
  }

  static String? _nameUnit(String text) {
    final m = RegExp(
      '(?:\\(\\s*|\\b)($_unit)\\s*\\)?\\s*[:|-]?\\s*\$',
      caseSensitive: false,
    ).firstMatch(text);
    return m == null ? null : _normaliseUnit(m.group(1)!);
  }

  static String _cleanName(String text) => text
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(
        RegExp('(?:\\s+|\\()($_unit)\\s*\\)?\\s*\$', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^\s*[-•:]\s*'), '')
      .replaceFirst(RegExp(r'[\s:–-]+$'), '')
      .trim();

  static bool _isName(String text) =>
      RegExp(r'[a-zA-ZÀ-ž]').hasMatch(text) &&
      !_metadata.hasMatch(text) &&
      !_isHeaderFragment(text) &&
      text.length >= 2;

  static bool _continuation(String previous, String next) =>
      next.isEmpty ||
      RegExp(
        r'^(?:fat|fatty acids?|fibre|fiber|sugars?|carbohydrates?|acid|[A-Z]\d*)$',
        caseSensitive: false,
      ).hasMatch(next) ||
      previous.endsWith('/') ||
      RegExp(
        r'^(?:total|saturated|unsaturated|polyunsaturated|monounsaturated|dietary|vitamin|of which)$',
        caseSensitive: false,
      ).hasMatch(previous);

  static void _resolveColumns(
    List<_Column> columns,
    List<_Record> records,
    double height,
    List<String> warnings,
  ) {
    // Learn number alignment from complete rows. Missing cells never shift later
    // cells left; they still use their physical position in the photograph.
    if (columns.isNotEmpty) {
      final samples = List.generate(columns.length, (_) => <double>[]);
      for (final r in records) {
        if (r.values.length != columns.length) continue;
        if (r.values.map((v) => v.quantity.unit).toSet().containsAll([
          'kJ',
          'kcal',
        ])) {
          continue;
        }
        for (var i = 0; i < columns.length; i++) {
          if ((r.values[i].quantity.unit == '%') !=
              (columns[i].basis == NutritionColumnBasis.dailyValue)) {
            continue;
          }
          samples[i].add(r.values[i].x);
        }
      }
      for (var i = 0; i < columns.length; i++) {
        if (samples[i].length >= 2) columns[i].x = _median(samples[i]);
      }
    }
    final positions = <double>[], percentages = <double>[];
    for (final r in records) {
      for (final v in r.values) {
        (v.quantity.unit == '%' ? percentages : positions).add(v.x);
      }
    }
    List<double> clusters(List<double> positions) {
      positions.sort();
      final groups = <List<double>>[];
      for (final x in positions) {
        if (groups.isEmpty || x - _median(groups.last) > height * 3) {
          groups.add([x]);
        } else {
          groups.last.add(x);
        }
      }
      return groups.map(_median).toList();
    }

    if (!columns.any((c) => c.basis == NutritionColumnBasis.dailyValue) &&
        percentages.isNotEmpty) {
      for (final x in clusters(percentages)) {
        columns.add(
          _Column(NutritionColumnBasis.dailyValue, '% (header not read)', x, 0),
        );
      }
    }
    if (!columns.any((c) => c.basis != NutritionColumnBasis.dailyValue) &&
        positions.isNotEmpty) {
      for (final x in clusters(positions)) {
        columns.add(
          _Column(
            NutritionColumnBasis.unknown,
            'Amount (basis not read)',
            x,
            0,
          ),
        );
      }
      warnings.add(
        'The amount column heading was not read. Its serving basis has not been assumed.',
      );
    }
    columns.sort((a, b) => a.x.compareTo(b.x));
  }

  static double? _parseNumber(String text) {
    var value = text.replaceAll(' ', '');
    if (value.contains(',') && value.contains('.')) {
      final decimal = value.lastIndexOf(',') > value.lastIndexOf('.')
          ? ','
          : '.';
      value = value
          .replaceAll(decimal == ',' ? '.' : ',', '')
          .replaceAll(decimal, '.');
    } else if (value.contains(',')) {
      value = RegExp(r'^[1-9]\d{0,2}(,\d{3})+$').hasMatch(value)
          ? value.replaceAll(',', '')
          : value.replaceAll(',', '.');
    } else if ('.'.allMatches(value).length > 1) {
      value = value.replaceAll('.', '');
    }
    return double.tryParse(value);
  }

  static ({
    double? amount,
    String? unit,
    double? count,
    String? item,
    double? servings,
  })
  _servingMetadata(String text) {
    double? amount, count, servings;
    String? unit, item;
    final servingLine = RegExp(
      r'(?:serving\s*size|saiz\s*hidangan)[^\n]*',
      caseSensitive: false,
    ).firstMatch(text)?.group(0);
    final header = RegExp(
      r'(?:per\s*(?:serving|serve)|setiap\s*hidangan)\s*\(?\s*\d[^\n]*',
      caseSensitive: false,
    ).firstMatch(text)?.group(0);
    final measurement = RegExp(
      '($_number)\\s*(mg|g|ml|l)\\b',
      caseSensitive: false,
    ).firstMatch(servingLine ?? header ?? '');
    if (measurement != null) {
      amount = _parseNumber(measurement.group(1)!);
      unit = measurement.group(2)!.toLowerCase();
      if (unit == 'mg') {
        amount = amount! / 1000;
        unit = 'g';
      }
      if (unit == 'l') {
        amount = amount! * 1000;
        unit = 'ml';
      }
    }
    const items =
        r'(bottles?|packs?|pieces?|tablets?|capsules?|sachets?|cups?|chips?|biscuits?|crackers?)';
    final countMatch = RegExp(
      '($_number)(?:\\s*/\\s*($_number))?\\s*$items',
      caseSensitive: false,
    ).firstMatch(servingLine ?? '');
    if (countMatch != null) {
      final divisor = _parseNumber(countMatch.group(2) ?? '1');
      count = divisor == null || divisor == 0
          ? null
          : _parseNumber(countMatch.group(1)!)! / divisor;
      item = countMatch.group(3)!.toLowerCase().replaceFirst(RegExp(r's$'), '');
    }
    final packages = RegExp(
      '(?:servings?\\s*per\\s*(?:package|pack|container|bottle)|hidangan\\s*setiap\\s*(?:pek|bungkusan))\\s*[:=-]?\\s*($_number)',
      caseSensitive: false,
    ).firstMatch(text);
    final reversed = RegExp(
      '($_number)\\s*servings?\\s*per\\s*(?:container|package|pack)',
      caseSensitive: false,
    ).firstMatch(text);
    if (packages != null || reversed != null) {
      servings = _parseNumber((packages ?? reversed)!.group(1)!);
    }
    return (
      amount: amount,
      unit: unit,
      count: count,
      item: item,
      servings: servings,
    );
  }

  static NutritionValues? _legacyValues(
    List<NutritionRow> rows,
    String column,
  ) {
    final values = <String, double>{};
    final other = <String, NutrientValue>{};
    const aliases = {
      'energy': 'energy',
      'tenaga': 'energy',
      'calories': 'energy',
      'protein': 'protein',
      'total fat': 'totalFat',
      'fat': 'totalFat',
      'jumlah lemak': 'totalFat',
      'lemak': 'totalFat',
      'saturated fat': 'saturatedFat',
      'saturates': 'saturatedFat',
      'lemak tepu': 'saturatedFat',
      'trans fat': 'transFat',
      'lemak trans': 'transFat',
      'total carbohydrate': 'carbohydrate',
      'carbohydrate': 'carbohydrate',
      'carbohydrates': 'carbohydrate',
      'karbohidrat': 'carbohydrate',
      'total sugars': 'sugars',
      'sugars': 'sugars',
      'sugar': 'sugars',
      'gula': 'sugars',
      'jumlah gula': 'sugars',
      'dietary fibre': 'fibre',
      'dietary fiber': 'fibre',
      'fibre': 'fibre',
      'fiber': 'fibre',
      'serat': 'fibre',
      'sodium': 'sodium',
      'natrium': 'sodium',
      'cholesterol': 'cholesterol',
      'kolesterol': 'cholesterol',
    };
    final seen = <String>{}, duplicates = <String>{};
    for (final row in rows) {
      final cell = row.cells[column];
      if (cell == null || cell.needsReview) continue;
      final key = aliases[row.name.toLowerCase()];
      for (final q in cell.quantities) {
        if (q.comparator.isNotEmpty || q.unit == '%' || q.unit.isEmpty) {
          continue;
        }
        final grams = switch (q.unit) {
          'g' => q.amount,
          'mg' => q.amount / 1000,
          'µg' || 'mcg' => q.amount / 1000000,
          _ => null,
        };
        final field = key == 'energy'
            ? (q.unit == 'kcal'
                  ? 'energyKcal'
                  : q.unit == 'kJ'
                  ? 'energyKj'
                  : null)
            : key;
        final number = key == 'energy'
            ? q.amount
            : (key == 'sodium' || key == 'cholesterol')
            ? grams == null
                  ? null
                  : grams * 1000
            : grams;
        if (field != null && number != null) {
          if (!seen.add(field)) duplicates.add(field);
          values[field] = number;
        } else {
          other['${row.id}_${q.unit}'] = NutrientValue(
            name: row.name,
            amount: q.amount,
            unit: q.unit,
          );
        }
      }
    }
    for (final key in duplicates) {
      values.remove(key);
    }
    final result = NutritionValues(
      energyKcal: values['energyKcal'],
      energyKj: values['energyKj'],
      proteinG: values['protein'],
      totalFatG: values['totalFat'],
      saturatedFatG: values['saturatedFat'],
      transFatG: values['transFat'],
      carbohydrateG: values['carbohydrate'],
      sugarsG: values['sugars'],
      fibreG: values['fibre'],
      sodiumMg: values['sodium'],
      cholesterolMg: values['cholesterol'],
      otherNutrients: Map.unmodifiable(other),
    );
    return result.hasAnyValue ? result : null;
  }
}
