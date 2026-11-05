import '../models/nutrition_label_data.dart';
import 'nutrition_table_parser.dart';

/// Uses Azure's table indexes, never nearest-number matching or OCR block order.
class AzureNutritionLayoutParser {
  static NutritionLabelData parse(Map<String, dynamic> result) {
    final rawText = result['content'] as String? ?? '';
    final tables = (result['tables'] as List? ?? [])
        .whereType<Map>()
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
    final parsed = tables.map((t) => _table(t, result, rawText)).toList();
    final candidates = parsed
        .where(
          (t) =>
              t.rows.isNotEmpty &&
              t.columns.any((c) => c.basis != NutritionColumnBasis.unknown),
        )
        .toList();
    NutritionLabelData data;
    if (candidates.length == 1) {
      data = candidates.single;
    } else if (tables.length == 1) {
      data = parsed.single;
    } else {
      data = NutritionLabelData(
        rawText: rawText,
        extractionWarnings: [
          tables.isEmpty
              ? 'No table was detected. Retake a clear photo of the full nutrition table.'
              : 'Multiple tables were detected. Crop the photo to one nutrition table and scan again.',
        ],
      );
    }
    return NutritionLabelData(
      rawText: data.rawText,
      columns: data.columns,
      rows: data.rows,
      extractionWarnings: data.extractionWarnings,
      servingSizeAmount: data.servingSizeAmount,
      servingSizeUnit: data.servingSizeUnit,
      servingsPerPackage: data.servingsPerPackage,
      servingUnitAmount: data.servingUnitAmount,
      servingUnitName: data.servingUnitName,
      perServing: data.perServing,
      per100: data.per100,
      per100Unit: data.per100Unit,
      extractionMethod: 'Azure Document Intelligence Layout',
    );
  }

  static NutritionLabelData _table(
    Map<String, dynamic> table,
    Map<String, dynamic> result,
    String rawText,
  ) {
    final source = (table['cells'] as List? ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    final rowCount = table['rowCount'] as int? ?? 0;
    final columnCount = table['columnCount'] as int? ?? 0;
    if (rowCount < 1 || rowCount > 500 || columnCount < 2 || columnCount > 30) {
      return NutritionLabelData(
        rawText: rawText,
        extractionWarnings: const [
          'The table structure could not be read. Retake the photo.',
        ],
      );
    }
    final cells = <String, List<Map<String, dynamic>>>{};
    final warnings = <String>[];
    var malformed = false;
    for (final cell in source) {
      final r = cell['rowIndex'] as int? ?? -1;
      final c = cell['columnIndex'] as int? ?? -1;
      final rs = cell['rowSpan'] as int? ?? 1;
      final cs = cell['columnSpan'] as int? ?? 1;
      if (r < 0 ||
          c < 0 ||
          rs < 1 ||
          cs < 1 ||
          r + rs > rowCount ||
          c + cs > columnCount) {
        malformed = true;
        continue;
      }
      for (var y = r; y < r + rs; y++) {
        for (var x = c; x < c + cs; x++) {
          cells.putIfAbsent('$y:$x', () => []).add(cell);
        }
      }
    }
    String text(int r, int c) =>
        cells['$r:$c']
            ?.map((v) => (v['content'] as String? ?? '').trim())
            .join(' / ') ??
        '';
    final headers = <int>{};
    // Only leading header rows can define the serving basis. Later repeated
    // headers are skipped rather than being turned into nutrient rows.
    var dataStarted = false;
    final repeatedHeaders = <int>{};
    for (var r = 0; r < rowCount; r++) {
      final row = [for (var c = 0; c < columnCount; c++) text(r, c)];
      final hasBasis = row.any(
        (s) =>
            NutritionTableParser.basisForHeader(s) !=
            NutritionColumnBasis.unknown,
      );
      final markedHeader = source.any(
        (s) => s['rowIndex'] == r && s['kind'] == 'columnHeader',
      );
      if (!dataStarted &&
          (hasBasis ||
              markedHeader ||
              row.every(
                (s) => s.isEmpty || NutritionTableParser.isMetadata(s),
              ))) {
        headers.add(r);
      } else if (hasBasis || markedHeader) {
        repeatedHeaders.add(r);
      } else if (row.any((s) => s.isNotEmpty)) {
        dataStarted = true;
      }
    }
    final labels = <int, String>{};
    final headerSafe = <int, bool>{};
    for (var c = 0; c < columnCount; c++) {
      final unique = <Map<String, dynamic>>{};
      for (final r in headers) {
        unique.addAll(cells['$r:$c'] ?? []);
      }
      labels[c] = unique
          .map((s) => s['content'] as String? ?? '')
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      headerSafe[c] =
          unique.isNotEmpty && unique.every((s) => _trusted(s, result));
    }
    final unitColumns = labels.keys
        .where(
          (c) => RegExp(r'^units?$', caseSensitive: false).hasMatch(labels[c]!),
        )
        .toSet();
    final columns = [
      for (var c = 1; c < columnCount; c++)
        if (!unitColumns.contains(c))
          NutritionColumn(
            id: 'azure_column_$c',
            label: labels[c]!.isEmpty ? 'Amount (basis not read)' : labels[c]!,
            basis: NutritionTableParser.basisForHeader(labels[c]!),
          ),
    ];
    // US-style labels can print the amount inside the nutrient-name cell,
    // with only a separate %DV column. Preserve that printed amount explicitly.
    final inlineAmounts =
        columns.every((c) => c.basis == NutritionColumnBasis.dailyValue) &&
        List.generate(
          rowCount,
          (r) => r,
        ).any((r) => !headers.contains(r) && _inline(text(r, 0)) != null);
    if (inlineAmounts) {
      columns.insert(
        0,
        NutritionColumn(
          id: 'azure_inline_amount',
          label: labels[0]!.isEmpty ? 'Amount (basis not read)' : labels[0]!,
          basis: NutritionTableParser.basisForHeader(labels[0]!),
        ),
      );
    }
    final rows = <NutritionRow>[];
    for (var r = 0; r < rowCount; r++) {
      if (headers.contains(r) || repeatedHeaders.contains(r)) continue;
      final originalName = text(r, 0).replaceAll(RegExp(r'\s+'), ' ').trim();
      if (NutritionTableParser.isMetadata(originalName)) continue;
      final inline = _inline(originalName);
      final nameText = inline?.name ?? originalName;
      final nameSources = cells['$r:0'] ?? [];
      if (nameText.isEmpty) {
        if (columns.any(
          (c) => text(r, int.tryParse(c.id.split('_').last) ?? 0).isNotEmpty,
        )) {
          warnings.add(
            'Values with an unreadable nutrient name were excluded. Check the photo.',
          );
        }
        continue;
      }
      if (!RegExp(r'[a-zA-ZÀ-ž]').hasMatch(nameText)) {
        warnings.add(
          'An unreadable nutrient row was excluded. Check the photo.',
        );
        continue;
      }
      final nameSafe =
          (inline == null || inlineAmounts) &&
          nameSources.length == 1 &&
          (nameSources.single['rowSpan'] ?? 1) == 1 &&
          (nameSources.single['columnSpan'] ?? 1) == 1 &&
          _trusted(nameSources.single, result);
      final unitText = unitColumns.map((c) => text(r, c)).join(' ').trim();
      final rowUnit = unitText.isEmpty
          ? NutritionTableParser.unitInName(nameText)
          : NutritionTableParser.unitInName('Nutrient ($unitText)');
      final unitSafe = unitColumns.every(
        (c) => (cells['$r:$c'] ?? []).every((s) => _trusted(s, result)),
      );
      final rowCells = <String, NutritionCell>{};
      for (final column in columns) {
        if (column.id == 'azure_inline_amount') {
          rowCells[column.id] = NutritionTableParser.parsePrintedCell(
            inline?.amount ?? '',
            basis: column.basis,
            needsReview: !nameSafe || !headerSafe[0]! || malformed,
          );
          continue;
        }
        final c = int.parse(column.id.split('_').last);
        final parts = cells['$r:$c'] ?? [];
        // A value merged across multiple rows/columns has no unique owner.
        // Keep it only at its anchor for display and exclude it from arithmetic.
        final anchored = parts
            .where((s) => s['rowIndex'] == r && s['columnIndex'] == c)
            .toList();
        final valueText = anchored
            .map((s) => s['content'] as String? ?? '')
            .join(' / ');
        final safe =
            !malformed &&
            nameSafe &&
            unitSafe &&
            headerSafe[c]! &&
            parts.length == 1 &&
            anchored.length == 1 &&
            (parts.single['rowSpan'] ?? 1) == 1 &&
            (parts.single['columnSpan'] ?? 1) == 1 &&
            _trusted(parts.single, result);
        rowCells[column.id] = NutritionTableParser.parsePrintedCell(
          valueText,
          basis: column.basis,
          rowUnit: rowUnit,
          needsReview: !safe,
        );
      }
      rows.add(
        NutritionRow(
          id: 'azure_row_$r',
          name: NutritionTableParser.cleanNutrientName(
            inlineAmounts ? nameText : originalName,
          ),
          cells: Map.unmodifiable(rowCells),
          sourceText: [for (var c = 0; c < columnCount; c++) text(r, c)]
              .join('\t'),
          needsReview: !nameSafe || rowCells.values.any((c) => c.needsReview),
        ),
      );
    }
    if (columns.any((c) => c.basis == NutritionColumnBasis.unknown)) {
      warnings.add(
        'Some column headings could not be identified. Those columns cannot be used for calculations.',
      );
    }
    if (malformed || rows.any((r) => r.needsReview)) {
      warnings.add(
        'Highlighted cells have missing, uncertain, or merged readings and are excluded from calculations.',
      );
    }
    return NutritionTableParser.fromTable(
      columns: columns,
      rows: rows,
      rawText: rawText,
      // Serving size is also a calculation input. Ignore low-confidence
      // metadata instead of multiplying all nutrients by a misread size.
      metadataText: [
        for (final page in result['pages'] as List? ?? [])
          for (final line in (page as Map)['lines'] as List? ?? [])
            if (_trusted(Map<String, dynamic>.from(line as Map), result))
              line['content'] as String? ?? '',
        for (final cell in source)
          if (_trusted(cell, result)) cell['content'] as String? ?? '',
      ].join('\n'),
      warnings: warnings,
    );
  }

  static ({String name, String amount})? _inline(String text) {
    const q =
        r'[<>=≤≥]?\s*\d+(?:[.,]\d+)?\s*(?:kcal|kJ|mcg|µg|μg|mg|kg|g|ml|IU)';
    final includes = RegExp(
      '^includes?\\s+($q)\\s+(.+)\$',
      caseSensitive: false,
    ).firstMatch(text);
    if (includes != null) {
      return (name: includes.group(2)!, amount: includes.group(1)!);
    }
    final suffix = RegExp(
      '^(.+?)\\s+($q(?:\\s*/\\s*$q)?)\\s*\$',
      caseSensitive: false,
    ).firstMatch(text);
    if (suffix != null) {
      return (name: suffix.group(1)!, amount: suffix.group(2)!);
    }
    final calories = RegExp(
      r'^(calories)\s+(\d+(?:[.,]\d+)?)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (calories != null) {
      return (name: calories.group(1)!, amount: '${calories.group(2)} kcal');
    }
    return null;
  }

  /// Confidence comes from OCR words covering the cell spans, not an invented
  /// table-level confidence. Missing confidence/evidence requires user review.
  static bool _trusted(Map<String, dynamic> cell, Map<String, dynamic> result) {
    final content = (result['content'] as String? ?? '').runes.toList();
    final spans = (cell['spans'] as List? ?? []).whereType<Map>().toList();
    if (spans.isEmpty) return false;
    final words = [
      for (final page in result['pages'] as List? ?? [])
        ...((page as Map)['words'] as List? ?? []).whereType<Map>(),
    ];
    var observed = false;
    final evidence = StringBuffer();
    for (final span in spans) {
      final start = span['offset'] as int? ?? -1;
      final length = span['length'] as int? ?? 0;
      if (start < 0 || length <= 0 || start + length > content.length) {
        return false;
      }
      evidence.write(
        String.fromCharCodes(content.sublist(start, start + length)),
      );
      for (var p = start; p < start + length; p++) {
        if (String.fromCharCode(content[p]).trim().isEmpty) continue;
        observed = true;
        final covering = words.where((w) {
          final s = w['span'] as Map?;
          return s != null &&
              s['offset'] is int &&
              s['length'] is int &&
              p >= (s['offset'] as int) &&
              p < (s['offset'] as int) + (s['length'] as int);
        });
        if (covering.isEmpty ||
            covering.any(
              (w) => w['confidence'] is! num || (w['confidence'] as num) < 0.90,
            )) {
          return false;
        }
      }
    }
    String compact(String text) => text.replaceAll(RegExp(r'\s+'), '');
    return observed &&
        compact(evidence.toString()) ==
            compact(cell['content'] as String? ?? '');
  }
}
