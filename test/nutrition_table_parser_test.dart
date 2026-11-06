import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/nutrition_label_ocr_service.dart';
import 'package:nutripal/services/nutrition_table_parser.dart';

// =======================================================
// Synthetic OCR layouts
//
// Each _text() call is one ML Kit "line": words are laid
// out left to right from x, centred on y, 20 px tall,
// 11 px per character.
// =======================================================

const double _h = 20;
const double _charWidth = 11;

OcrTextLine _text(
  String text,
  double x,
  double y, {
  double height = _h,
  double charWidth = _charWidth,
}) {
  final List<OcrWord> words = <OcrWord>[];
  double cursor = x;

  for (final String part in text.split(' ')) {
    if (part.isEmpty) continue;

    final double width = part.length * charWidth;

    words.add(
      OcrWord(
        text: part,
        left: cursor,
        top: y - height / 2,
        right: cursor + width,
        bottom: y + height / 2,
      ),
    );

    cursor += width + charWidth;
  }

  return OcrTextLine(words);
}

// Simulates a tilted photo: rotates every word and
// returns the axis-aligned box ML Kit would report.
List<OcrTextLine> _rotate(List<OcrTextLine> lines, double angle) {
  final double c = math.cos(angle);
  final double s = math.sin(angle);

  return lines.map((OcrTextLine line) {
    return OcrTextLine(
      line.words.map((OcrWord w) {
        final double x = w.centerX * c - w.centerY * s;
        final double y = w.centerX * s + w.centerY * c;
        final double bw = w.width * c + w.height * s;
        final double bh = w.width * s + w.height * c;

        return OcrWord(
          text: w.text,
          left: x - bw / 2,
          right: x + bw / 2,
          top: y - bh / 2,
          bottom: y + bh / 2,
        );
      }).toList(),
    );
  }).toList();
}

NutrientRow _row(NutritionLabelData data, String namePart) {
  return data.nutrients.firstWhere(
    (NutrientRow r) => r.name.toLowerCase().contains(namePart.toLowerCase()),
    orElse: () => throw StateError(
      'No row containing "$namePart". Rows: '
      '${data.nutrients.map((NutrientRow r) => r.name).toList()}',
    ),
  );
}

List<String> _cell(NutritionLabelData data, String name, int column) {
  return _row(data, name)
      .valuesByColumn[column]
      .map((NutritionValue v) => '${_fmt(v.amount)} ${v.unit}')
      .toList();
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

List<NutritionColumnBasis> _bases(NutritionLabelData data) =>
    data.columns.map((NutritionColumn c) => c.basis).toList();

// Typical Malaysian bilingual label.
List<OcrTextLine> _malaysianLabel() => <OcrTextLine>[
      _text('MAKLUMAT PEMAKANAN / NUTRITION INFORMATION', 20, 40),
      _text('Saiz hidangan / Serving size: 2 keping (30 g)', 20, 80),
      _text('Hidangan setiap bungkusan / Servings per package: 10', 20, 110),
      _text('Setiap 100 g', 300, 150),
      _text('Setiap hidangan', 480, 150),
      _text('Per 100 g', 300, 175),
      _text('Per serving', 480, 175),
      _text('Tenaga / Energy', 20, 215),
      _text('1800 kJ', 300, 215),
      _text('540 kJ', 480, 215),
      _text('430 kcal', 300, 240),
      _text('129 kcal', 480, 240),
      _text('Karbohidrat / Carbohydrate', 20, 270),
      _text('60.0 g', 300, 270),
      _text('18.0 g', 480, 270),
      _text('Jumlah gula / Total sugars', 20, 300),
      _text('20.0 g', 300, 300),
      _text('6.0 g', 480, 300),
      _text('Protein', 20, 330),
      _text('8.0 g', 300, 330),
      _text('2.4 g', 480, 330),
      _text('Jumlah lemak / Total fat', 20, 360),
      _text('18.0 g', 300, 360),
      _text('5.4 g', 480, 360),
      _text('Lemak tepu / Saturated fat', 20, 390),
      _text('9.0 g', 300, 390),
      _text('2.7 g', 480, 390),
      _text('Natrium / Sodium', 20, 420),
      _text('400 mg', 300, 420),
      _text('120 mg', 480, 420),
      _text('Ingredients: wheat flour, sugar, palm oil', 20, 470),
    ];

void _expectMalaysianLabel(NutritionLabelData data) {
  expect(
    _bases(data),
    <NutritionColumnBasis>[
      NutritionColumnBasis.per100g,
      NutritionColumnBasis.perServing,
    ],
  );

  expect(data.nutrients.length, 7);

  expect(_row(data, 'energy').name, 'Tenaga / Energy');
  expect(_cell(data, 'energy', 0), <String>['1800 kJ', '430 kcal']);
  expect(_cell(data, 'energy', 1), <String>['540 kJ', '129 kcal']);

  expect(_cell(data, 'carbohydrate', 0), <String>['60 g']);
  expect(_cell(data, 'sugars', 1), <String>['6 g']);
  expect(_cell(data, 'protein', 1), <String>['2.4 g']);
  expect(_cell(data, 'saturated', 0), <String>['9 g']);
  expect(_cell(data, 'sodium', 0), <String>['400 mg']);
  expect(_cell(data, 'sodium', 1), <String>['120 mg']);
}

// Real label (canned tuna, 1920x2560 photo) with the OCR
// problems seen on the phone:
//   - "CARA HIDANGAN" printed sideways beside the rows
//   - barcode digits printed sideways
//   - "HALAL" logo caption left of the table
//   - "g" read as "9": 0.5g -> 0.59, 0.2g -> 0.29 ...
//   - footer code on the same row as Vitamin B12
List<OcrTextLine> _tunaLabel() {
  OcrTextLine t(String s, double x, double y) =>
      _text(s, x, y, height: 50, charWidth: 20);

  return <OcrTextLine>[
    t('KETERANGAN PEMAKANAN', 445, 905),
    t('Hidangan setiap pek: 3', 445, 990),
    t('Saiz hidangan: 36g (Berat tanpa air)', 445, 1055),
    t('Setiap hidangan', 745, 1130),
    t('Setiap 100g', 1100, 1130),
    t('Tenaga', 450, 1205),
    t('39kcal', 950, 1205),
    t('108kcal', 1190, 1205),
    t('Protein', 450, 1268),
    t('8.2g', 990, 1268),
    t('22.9g', 1230, 1268),
    t('Lemak', 450, 1330),
    t('0.59', 990, 1330),
    t('1.5g*', 1230, 1330),
    _text('HALAL', 75, 1365, height: 15, charWidth: 6),
    t('yang terdiri daripada', 450, 1400),
    t('- Asid Lemak monotidaktepu', 490, 1462),
    t('0.1g', 990, 1462),
    t('0.3g', 1250, 1462),
    t('- Asid Lemak politidaktepu', 490, 1525),
    t('0.29', 990, 1525),
    t('0.6g', 1250, 1525),
    t('- Omega 3', 490, 1588),
    t('0.2g', 990, 1588),
    t('0.5g', 1250, 1588),
    t('- Asid Lemak tepu', 490, 1650),
    t('0.2g', 990, 1650),
    t('0.6g', 1250, 1650),
    t('- Asid lemak trans', 490, 1712),
    t('0.09', 990, 1712),
    t('0.1g', 1250, 1712),
    t('Karbohidrat', 455, 1772),
    t('0.19', 990, 1772),
    t('0.4g', 1250, 1772),
    t('Jumlah Gula', 495, 1835),
    t('0.0g', 990, 1835),
    t('0.1g', 1250, 1835),
    t('Natrium', 455, 1895),
    t('107mg', 950, 1895),
    t('296mg', 1190, 1895),
    t('Vitamin B12', 455, 1955),
    t('0.7µg', 970, 1955),
    t('2.0µg', 1210, 1955),
    t('GC (WM) A, (EM) B, (BR) C / 012', 1350, 1945),
    OcrTextLine(const <OcrWord>[
      OcrWord(text: 'HIDANGAN', left: 355, top: 1530, right: 410, bottom: 1820),
      OcrWord(text: 'CARA', left: 355, top: 1830, right: 410, bottom: 1970),
    ]),
    OcrTextLine(const <OcrWord>[
      OcrWord(
        text: '9556041604192',
        left: 1780,
        top: 950,
        right: 1840,
        bottom: 1700,
      ),
    ]),
  ];
}

// Real label (UHT carton, per serving + per 100 ml) with the
// OCR mistakes seen on the phone: "3.1g" -> "3.19",
// "0.3g" -> "0.39", and the claim printed inside the table
// border misread as "a Chalesteral Free Fond ...".
List<OcrTextLine> _cartonLabel({bool withClaim = true, String? extraLine}) {
  OcrTextLine t(String s, double x, double y) =>
      _text(s, x, y, height: 50, charWidth: 22);

  return <OcrTextLine>[
    t('KETERANGAN PEMAKANAN/NUTRITION INFORMATION', 255, 720),
    t('Hidangan setiap pek / Serving per package: 13', 260, 805),
    t('Saiz hidangan / Serving size: 15ml', 260, 870),
    t('Setiap hidangan /', 650, 965),
    t('Setiap /', 1160, 965),
    t('Per serving', 790, 1035),
    t('Per 100ml', 1105, 1035),
    t('Tenaga / Energy', 260, 1125),
    t('31kcal', 900, 1125),
    t('207kcal', 1155, 1125),
    t('Lemak / Fat', 260, 1190),
    t('3.19', 955, 1190),
    t('20.6g', 1210, 1190),
    t('Kolesterol / Cholesterol', 260, 1255),
    t('0mg', 950, 1255),
    t('0mg', 1230, 1255),
    t('Karbohidrat / Carbohydrate', 260, 1320),
    t('0.4g', 955, 1320),
    t('2.8g', 1240, 1320),
    t('Jumlah Gula / Total Sugars', 290, 1385),
    t('0.4g', 955, 1385),
    t('2.7g', 1240, 1385),
    t('Protein / Protein', 260, 1450),
    t('0.39', 955, 1450),
    t('2.2g', 1240, 1450),
    t('Natrium / Sodium', 260, 1515),
    t('2mg', 950, 1515),
    t('16mg', 1210, 1515),
    if (withClaim)
      t('a Chalesteral Free Fond / Makanan Bebas Kalesteral', 275, 1605),
    if (extraLine != null) t(extraLine, 275, 1580),
    t('TM: perkilangan dan cap dagang dibawah lesen AYAM SARL /', 215, 1700),
  ];
}

const List<String> _cartonRows = <String>[
  'Tenaga / Energy',
  'Lemak / Fat',
  'Kolesterol / Cholesterol',
  'Karbohidrat / Carbohydrate',
  'Jumlah Gula / Total Sugars',
  'Protein / Protein',
  'Natrium / Sodium',
];

void main() {
  group('NutritionTableParser', () {
    test('reads the carton label and ignores the claim under the rows', () {
      final NutritionLabelData data =
          NutritionTableParser.parse(_cartonLabel());

      expect(
        _bases(data),
        <NutritionColumnBasis>[
          NutritionColumnBasis.perServing,
          NutritionColumnBasis.per100ml,
        ],
      );

      expect(data.nutrients.map((NutrientRow r) => r.name).toList(), _cartonRows);

      expect(data.servingSizeAmount, 15);
      expect(data.servingSizeUnit, 'ml');
      expect(data.servingsPerPackage, 13);

      expect(_cell(data, 'lemak', 0), <String>['3.1 g']);
      expect(_cell(data, 'lemak', 1), <String>['20.6 g']);
      expect(_cell(data, 'protein', 0), <String>['0.3 g']);
      expect(_cell(data, 'kolesterol', 0), <String>['0 mg']);
      expect(_cell(data, 'natrium', 0), <String>['2 mg']);
      expect(_cell(data, 'natrium', 1), <String>['16 mg']);
    });

    test('a sentence printed across the table is never a nutrient row', () {
      final NutritionLabelData data = NutritionTableParser.parse(
        _cartonLabel(
          withClaim: false,
          extraLine: 'Suitable for vegetarians and the whole family',
        ),
      );

      expect(data.nutrients.map((NutrientRow r) => r.name).toList(), _cartonRows);
    });

    test('reads every row of the tuna label', () {
      final NutritionLabelData data =
          NutritionTableParser.parse(_tunaLabel());

      expect(
        _bases(data),
        <NutritionColumnBasis>[
          NutritionColumnBasis.perServing,
          NutritionColumnBasis.per100g,
        ],
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.name).toList(),
        <String>[
          'Tenaga',
          'Protein',
          'Lemak',
          'Asid Lemak monotidaktepu',
          'Asid Lemak politidaktepu',
          'Omega 3',
          'Asid Lemak tepu',
          'Asid lemak trans',
          'Karbohidrat',
          'Jumlah Gula',
          'Natrium',
          'Vitamin B12',
        ],
      );

      expect(data.servingSizeAmount, 36);
      expect(data.servingsPerPackage, 3);

      expect(_cell(data, 'tenaga', 0), <String>['39 kcal']);
      expect(_cell(data, 'tenaga', 1), <String>['108 kcal']);
      expect(_cell(data, 'lemak', 0), <String>['0.5 g']);
      expect(_cell(data, 'lemak', 1), <String>['1.5 g']);
      expect(_cell(data, 'politidaktepu', 0), <String>['0.2 g']);
      expect(_cell(data, 'omega', 1), <String>['0.5 g']);
      expect(_cell(data, 'asid lemak tepu', 0), <String>['0.2 g']);
      expect(_cell(data, 'trans', 0), <String>['0 g']);
      expect(_cell(data, 'trans', 1), <String>['0.1 g']);
      expect(_cell(data, 'karbohidrat', 0), <String>['0.1 g']);
      expect(_cell(data, 'gula', 1), <String>['0.1 g']);
      expect(_cell(data, 'natrium', 0), <String>['107 mg']);
      expect(_cell(data, 'natrium', 1), <String>['296 mg']);
      expect(_cell(data, 'vitamin', 0), <String>['0.7 µg']);
      expect(_cell(data, 'vitamin', 1), <String>['2 µg']);
    });

    test('reads a bilingual Malaysian label', () {
      final NutritionLabelData data =
          NutritionTableParser.parse(_malaysianLabel());

      _expectMalaysianLabel(data);

      expect(data.servingSizeAmount, 30);
      expect(data.servingSizeUnit, 'g');
      expect(data.servingsPerPackage, 10);
      expect(data.servingUnitAmount, 2);
      expect(data.servingUnitName, 'keping');
      expect(data.canCalculatePortion, isTrue);
    });

    test('keeps rows correct on a tilted photo', () {
      const double angle = 4 * math.pi / 180;

      final NutritionLabelData data = NutritionTableParser.parse(
        _rotate(_malaysianLabel(), angle),
        skewRadians: angle,
      );

      _expectMalaysianLabel(data);
    });

    test('reads units printed in the nutrient name', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Serving size: 25g', 20, 70),
        _text('Per 100g', 300, 100),
        _text('Per serving', 450, 100),
        _text('Energy (kcal)', 20, 140),
        _text('400', 300, 140),
        _text('100', 450, 140),
        _text('Protein (g)', 20, 170),
        _text('8.0', 300, 170),
        _text('2.0', 450, 170),
        _text('Fat (g)', 20, 200),
        _text('12.0', 300, 200),
        _text('3.0', 450, 200),
        _text('Carbohydrate (g)', 20, 230),
        _text('64.0', 300, 230),
        _text('16.0', 450, 230),
        _text('Sodium (mg)', 20, 260),
        _text('320', 300, 260),
        _text('80', 450, 260),
      ]);

      expect(
        _bases(data),
        <NutritionColumnBasis>[
          NutritionColumnBasis.per100g,
          NutritionColumnBasis.perServing,
        ],
      );

      expect(data.nutrients.length, 5);
      expect(_cell(data, 'energy', 0), <String>['400 kcal']);
      expect(_cell(data, 'energy', 1), <String>['100 kcal']);
      expect(_cell(data, 'protein', 0), <String>['8 g']);
      expect(_cell(data, 'sodium', 1), <String>['80 mg']);
      expect(data.servingSizeAmount, 25);
    });

    test('pairs kJ and kcal written side by side', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Facts', 20, 40),
        _text('Serving size 30 g', 20, 70),
        _text('Per serving', 300, 110),
        _text('Per 100 g', 520, 110),
        _text('Energy', 20, 150),
        _text('540 kJ', 300, 150),
        _text('129 kcal', 380, 150),
        _text('1800 kJ', 520, 150),
        _text('430 kcal', 610, 150),
        _text('Protein', 20, 180),
        _text('2.4 g', 300, 180),
        _text('8.0 g', 520, 180),
        _text('Fat', 20, 210),
        _text('5.4 g', 300, 210),
        _text('18.0 g', 520, 210),
        _text('Carbohydrate', 20, 240),
        _text('18.0 g', 300, 240),
        _text('60.0 g', 520, 240),
      ]);

      expect(data.columns.length, 2);
      expect(_cell(data, 'energy', 0), <String>['540 kJ', '129 kcal']);
      expect(_cell(data, 'energy', 1), <String>['1800 kJ', '430 kcal']);
      expect(_cell(data, 'protein', 0), <String>['2.4 g']);
    });

    test('merges names split over two lines', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per 100 g', 300, 80),
        _text('Tenaga', 20, 120),
        _text('1500 kJ', 300, 120),
        _text('Energy', 20, 145),
        _text('360 kcal', 300, 145),
        _text('Lemak tepu', 20, 180),
        _text('Saturated fat', 20, 205),
        _text('2.0 g', 300, 192.5),
        _text('Protein', 20, 240),
        _text('6.0 g', 300, 240),
      ]);

      expect(data.nutrients.length, 3);
      expect(_row(data, 'energy').name, 'Tenaga / Energy');
      expect(_cell(data, 'energy', 0), <String>['1500 kJ', '360 kcal']);
      expect(_row(data, 'saturated').name, 'Lemak tepu / Saturated fat');
      expect(_cell(data, 'saturated', 0), <String>['2 g']);
    });

    test('ignores footnotes under the table', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Facts', 20, 40),
        _text('Per serving', 300, 80),
        _text('Energy', 20, 120),
        _text('150 kcal', 300, 120),
        _text('Protein', 20, 150),
        _text('3 g', 300, 150),
        _text('Sodium', 20, 180),
        _text('150 mg', 300, 180),
        _text('*Percent Daily Values are based on a 2000 kcal diet', 20, 240),
      ]);

      expect(_cell(data, 'sodium', 0), <String>['150 mg']);
      expect(_cell(data, 'energy', 0), <String>['150 kcal']);
    });

    test('keeps "of which sugars" rows', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per 100g', 300, 80),
        _text('Carbohydrate', 20, 120),
        _text('60g', 300, 120),
        _text('of which sugars', 40, 145),
        _text('20g', 300, 145),
        _text('Fat', 20, 170),
        _text('10g', 300, 170),
      ]);

      expect(_row(data, 'sugars').name.toLowerCase(), 'sugars');
      expect(_cell(data, 'sugars', 0), <String>['20 g']);
    });

    test('fixes common OCR character mistakes', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per serving', 300, 80),
        _text('Dietary fibre', 20, 120),
        _text('O.5g', 300, 120),
        _text('Sodium', 20, 145),
        _text('120rng', 300, 145),
        _text('Protein', 20, 170),
        _text('lg', 300, 170),
      ]);

      expect(_cell(data, 'fibre', 0), <String>['0.5 g']);
      expect(_cell(data, 'sodium', 0), <String>['120 mg']);
      expect(_cell(data, 'protein', 0), <String>['1 g']);
    });

    test('works out a missing serving size from the two columns', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per serving', 300, 80),
        _text('Per 100 g', 480, 80),
        _text('Energy', 20, 120),
        _text('129 kcal', 300, 120),
        _text('430 kcal', 480, 120),
        _text('Protein', 20, 150),
        _text('2.4 g', 300, 150),
        _text('8.0 g', 480, 150),
        _text('Fat', 20, 180),
        _text('5.4 g', 300, 180),
        _text('18.0 g', 480, 180),
        _text('Carbohydrate', 20, 210),
        _text('18.0 g', 300, 210),
        _text('60.0 g', 480, 210),
      ]);

      expect(data.servingSizeAmount, 30);
      expect(data.servingSizeUnit, 'g');
    });

    test('does not treat "Net weight 100 g" as a per 100 g column', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Net weight: 100 g', 400, 62),
        _text('Per serving (30 g)', 300, 90),
        _text('Energy', 20, 130),
        _text('120 kcal', 300, 130),
        _text('Protein', 20, 160),
        _text('3.0 g', 300, 160),
        _text('Fat', 20, 190),
        _text('4.0 g', 300, 190),
      ]);

      expect(_bases(data), <NutritionColumnBasis>[
        NutritionColumnBasis.perServing,
      ]);
      expect(data.servingSizeAmount, 30);
    });

    test('table bounds cover every column and stop at the footer', () {
      final OcrBounds? bounds =
          NutritionTableParser.tableBounds(_malaysianLabel());

      expect(bounds, isNotNull);
      expect(bounds!.right, greaterThanOrEqualTo(568));
      expect(bounds.bottom, lessThan(470));
    });
  });

  group('Scan completeness check', () {
    List<String> issuesFor(
      List<OcrTextLine> lines, {
      required double width,
      required double height,
    }) {
      final List<NutritionTableDiagnostics> diagnostics =
          <NutritionTableDiagnostics>[];

      final NutritionLabelData table = NutritionTableParser.parse(
        lines,
        diagnosticsOut: diagnostics,
      );

      return NutritionLabelOcrService.completenessIssues(
        table: table,
        diagnostics: diagnostics.isEmpty ? null : diagnostics.first,
        imageWidth: width,
        imageHeight: height,
      );
    }

    test('whole table inside the photo is complete', () {
      expect(issuesFor(_tunaLabel(), width: 1920, height: 2560), isEmpty);
    });

    test('table running off the photo edges is incomplete', () {
      final List<String> issues =
          issuesFor(_tunaLabel(), width: 1340, height: 1990);

      expect(
        issues.first,
        startsWith(
          'The nutrition table is cut off at the right and bottom edges',
        ),
      );
    });

    test('values whose names are cut off are reported', () {
      // Tenaga, Protein and Lemak names outside the photo.
      final List<OcrTextLine> lines = _tunaLabel()
          .where(
            (OcrTextLine l) =>
                !<String>['Tenaga', 'Protein', 'Lemak'].contains(l.text),
          )
          .toList();

      final List<String> issues = issuesFor(lines, width: 1920, height: 2560);

      expect(issues, contains('3 nutrient names are cut off or unreadable.'));
    });
  });
}
