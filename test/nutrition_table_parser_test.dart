import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/services/label_reading_assessor.dart';
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
    (NutrientRow r) =>
        r.name.toLowerCase().contains(namePart.toLowerCase()) ||
        r.labelName.toLowerCase().contains(namePart.toLowerCase()),
    orElse: () => throw StateError(
      'No row containing "$namePart". Rows: '
      '${data.nutrients.map((NutrientRow r) => '${r.name} (${r.labelName})').toList()}',
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

  expect(_row(data, 'energy').name, 'Energy');
  expect(_row(data, 'energy').labelName, 'Tenaga / Energy');
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
  'Jumlah gula / Total sugars',
  'Protein / Protein',
  'Natrium / Sodium',
];

// Real label (Coke can, white stencil font on red, curved
// can) with what ML Kit produced on the phone:
//   - "LEMAK(g)" -> "LENAKIg)", "(g)" -> "(O)",
//     "KARBOHIDRAT" -> "KARBOHIORAT", "NATRIUM" -> "MATRIUM"
//   - units only in the names, numbers without units
//   - "19" (energy per 100 ml) not read at all
//   - value columns sit higher than their names because of
//     the can's curve (more so further right)
//   - "CAMPURAN PEMANIS - LIHAT RAMUAN" under the table
// Snack box (23 g serving) with a three-line "Per Serving /
// Setiap Hidangan / (23g)" heading. ML Kit read "4.9 g" as
// "4.9 9" and dropped the "g" of most other values.
List<OcrTextLine> _snackBoxLabel({bool servingColumnLostGrams = false}) {
  OcrTextLine t(String s, double x, double y) =>
      _text(s, x, y, height: 30, charWidth: 14);

  String g(String v) => servingColumnLostGrams ? '${v}9' : '$v g';

  return <OcrTextLine>[
    t('NUTRITION INFORMATION /', 655, 870),
    t('MAKLUMAT PEMAKANAN', 655, 905),
    t('Serving Size / Saiz Hidangan: 23g', 655, 950),
    t('Servings Per Box / Hidangan Sekotak: 2', 625, 985),
    t('Per 100g', 800, 1040),
    t('/ Setiap', 800, 1075),
    t('100g', 800, 1110),
    t('Per Serving', 935, 1035),
    t('/ Setiap', 935, 1070),
    t('Hidangan', 935, 1105),
    t('(23g)', 955, 1145),
    t('Energy / Tenaga', 580, 1170),
    t('456 kcal', 805, 1170),
    t('105 kcal', 950, 1170),
    t('Protein', 580, 1215),
    t('6.4 g', 815, 1215),
    t('1.59', 965, 1215),
    t('Carbohydrate /', 580, 1260),
    t('Karbohidrat', 580, 1290),
    t('65.9 g', 810, 1260),
    t(g('15.2'), 955, 1260),
    t('Total Sugars /', 620, 1340),
    t('Jumlah Gula /', 620, 1370),
    t('4.9 9', 820, 1340),
    t('1.19', 965, 1340),
    t('Dietary Fibre /', 580, 1420),
    t('Serat Diet', 580, 1450),
    t('9.59', 820, 1420),
    t(g('2.2'), 965, 1420),
    t('Fat / Lemak', 580, 1500),
    t('16.3 g', 810, 1500),
    t(g('3.7'), 960, 1500),
    t('Sodium / Natrium', 580, 1545),
    t('1575 mg', 800, 1545),
    t('362 mg', 950, 1545),
  ];
}

List<OcrTextLine> _cokeLabel({
  String? servingLine = 'SAIZ HIDANGAN : 320 mL',
  String sugars100 = '4.6',
  bool readEnergy100 = false,
}) {
  OcrTextLine t(String s, double x, double y) =>
      _text(s, x, y, height: 40, charWidth: 20);

  // Shift caused by the curve: col 1 ~30 px, col 2 ~45 px up.
  const double c1 = -30;
  const double c2 = -45;

  return <OcrTextLine>[
    t('320 mL', 1040, 735),
    t('MINUMAN BERPERISA BERKARBONAT', 320, 850),
    t('MAKLUMAT PEMAKANAN', 350, 950),
    t('HIDANGAN SETIAP TIN : 1', 350, 1000),
    if (servingLine != null) t(servingLine, 845, 1000),
    t('SETIAP', 350, 1055),
    t('HIDANGAN', 845, 1080),
    t('100mL', 1175, 1080),
    t('TENAGA (kcal)', 355, 1150),
    t('61', 990, 1150 + c1),
    if (readEnergy100) t('19', 1220, 1150 + c2),
    t('PROTEIN (O)', 355, 1210),
    t('0.0', 970, 1210 + c1),
    t('0.0', 1200, 1210 + c2),
    t('LENAKIg)', 355, 1270),
    t('0.0', 970, 1270 + c1),
    t('0.0', 1200, 1270 + c2),
    t('KARBOHIORAT (g)', 355, 1330),
    t('14.7', 950, 1330 + c1),
    t('4.6', 1200, 1330 + c2),
    t('-JUMLAH GULA (g)', 365, 1390),
    t('14.7', 950, 1390 + c1),
    t(sugars100, 1200, 1390 + c2),
    t('MATRIUM (mg)', 355, 1450),
    t('6', 1010, 1450 + c1),
    t('2', 1240, 1450 + c2),
    t('CAMPURAN PFMANIS-', 340, 1500),
    t('LIHAT RAMUAN', 700, 1508),
    t('55% KURANG GULA BERBANDING DENGAN COCA-COLA KLASIK', 340, 1560),
  ];
}

void main() {
  group('NutritionTableParser', () {
    test('reads the curved Coke can label', () {
      final NutritionLabelData data = NutritionTableParser.parse(_cokeLabel());

      expect(
        _bases(data),
        <NutritionColumnBasis>[
          NutritionColumnBasis.perServing,
          NutritionColumnBasis.per100ml,
        ],
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.labelName).toList(),
        <String>[
          'Tenaga',
          'Protein',
          'Lemak',
          'Karbohidrat',
          'Jumlah gula',
          'Natrium',
        ],
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.name).toList(),
        <String>[
          'Energy',
          'Protein',
          'Total Fat',
          'Carbohydrate',
          'Total Sugars',
          'Sodium',
        ],
      );

      expect(data.servingSizeAmount, 320);
      expect(data.servingSizeUnit, 'ml');
      expect(data.servingsPerPackage, 1);

      expect(_cell(data, 'tenaga', 0), <String>['61 kcal']);
      // "19" was not read: left empty, never borrowed from
      // the row below.
      expect(_cell(data, 'tenaga', 1), isEmpty);
      expect(_cell(data, 'protein', 0), <String>['0 g']);
      expect(_cell(data, 'protein', 1), <String>['0 g']);
      expect(_cell(data, 'lemak', 0), <String>['0 g']);
      expect(_cell(data, 'lemak', 1), <String>['0 g']);
      expect(_cell(data, 'karbohidrat', 0), <String>['14.7 g']);
      expect(_cell(data, 'karbohidrat', 1), <String>['4.6 g']);
      expect(_cell(data, 'gula', 1), <String>['4.6 g']);
      expect(_cell(data, 'natrium', 0), <String>['6 mg']);
      expect(_cell(data, 'natrium', 1), <String>['2 mg']);
    });

    test('reads a misread serving line ("SAIZ HIDANGAH : 320 mI")', () {
      final NutritionLabelData data = NutritionTableParser.parse(
        _cokeLabel(servingLine: 'SAIZ HIDANGAH : 320 mI'),
      );

      expect(data.servingSizeAmount, 320);
      expect(data.servingSizeUnit, 'ml');
    });

    test('a serving size worked out from the values is marked as such', () {
      // Serving line unreadable, and "4.6" for sugars per
      // 100 ml misread as "6" (what happened on the phone).
      final NutritionLabelData data = NutritionTableParser.parse(
        _cokeLabel(servingLine: null, sugars100: '6', readEnergy100: true),
      );

      // Big, precise values (61 / 19) count most, so the
      // estimate is close to the real 320 ml.
      expect(data.servingSizeAmount, 321);
      expect(
        data.notes,
        contains('Serving size worked out from the values: 321 ml'),
      );

      // ...and the wrong sugars value is caught, which sends
      // the label for an AI check.
      expect(LabelReadingAssessor.inconsistentRows(data), <String>['Total Sugars']);
    });

    test('formats nutrient names with only the first letter capital', () {
      expect(formatNutrientName('JUMLAH GULA'), 'Jumlah gula');
      expect(
        formatNutrientName('Jumlah Gula / Total Sugars'),
        'Jumlah gula / Total sugars',
      );
      expect(formatNutrientName('VITAMIN B12'), 'Vitamin B12');
      expect(formatNutrientName('VITAMIN A'), 'Vitamin A');
      expect(formatNutrientName('omega-3'), 'Omega-3');
    });

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

      expect(
        data.nutrients.map((NutrientRow r) => r.labelName).toList(),
        _cartonRows,
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.name).toList(),
        <String>[
          'Energy',
          'Total Fat',
          'Cholesterol',
          'Carbohydrate',
          'Total Sugars',
          'Protein',
          'Sodium',
        ],
      );

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

      expect(
        data.nutrients.map((NutrientRow r) => r.labelName).toList(),
        _cartonRows,
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.name).toList(),
        <String>[
          'Energy',
          'Total Fat',
          'Cholesterol',
          'Carbohydrate',
          'Total Sugars',
          'Protein',
          'Sodium',
        ],
      );
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
        data.nutrients.map((NutrientRow r) => r.labelName).toList(),
        <String>[
          'Tenaga',
          'Protein',
          'Lemak',
          'Asid lemak monotidaktepu',
          'Asid lemak politidaktepu',
          'Omega 3',
          'Asid lemak tepu',
          'Asid lemak trans',
          'Karbohidrat',
          'Jumlah gula',
          'Natrium',
          'Vitamin B12',
        ],
      );

      expect(
        data.nutrients.map((NutrientRow r) => r.name).toList(),
        <String>[
          'Energy',
          'Protein',
          'Total Fat',
          'Monounsaturated Fat',
          'Polyunsaturated Fat',
          'Omega 3',
          'Saturated Fat',
          'Trans Fat',
          'Carbohydrate',
          'Total Sugars',
          'Sodium',
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
      expect(_row(data, 'energy').labelName, 'Tenaga / Energy');
      expect(_cell(data, 'energy', 0), <String>['1500 kJ', '360 kcal']);
      expect(_row(data, 'saturated').labelName, 'Lemak tepu / Saturated fat');
      expect(_row(data, 'saturated').name, 'Saturated Fat');
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

      expect(_row(data, 'sugars').name, 'Total Sugars');
      expect(_row(data, 'sugars').labelName, 'Sugars');
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
    for (final bool lostGrams in <bool>[false, true]) {
      test(
          'snack box: one value per cell'
          '${lostGrams ? ' (serving column lost its "g")' : ''}', () {
        final NutritionLabelData data = NutritionTableParser.parse(
          _snackBoxLabel(servingColumnLostGrams: lostGrams),
        );

        expect(_bases(data), <NutritionColumnBasis>[
          NutritionColumnBasis.per100g,
          NutritionColumnBasis.perServing,
        ]);

        expect(data.nutrients.map((NutrientRow r) => r.name).toList(), <String>[
          'Energy',
          'Protein',
          'Carbohydrate',
          'Total Sugars',
          'Dietary Fibre',
          'Total Fat',
          'Sodium',
        ]);

        // "4.9 9" is 4.9 g, not 4.9 g and 9 g.
        expect(_cell(data, 'sugars', 0), <String>['4.9 g']);
        expect(_cell(data, 'sugars', 1), <String>['1.1 g']);

        // "(23g)" belongs to the "Per Serving" heading.
        expect(_cell(data, 'energy', 0), <String>['456 kcal']);
        expect(_cell(data, 'energy', 1), <String>['105 kcal']);

        expect(_cell(data, 'protein', 1), <String>['1.5 g']);
        expect(_cell(data, 'carbohydrate', 1), <String>['15.2 g']);
        expect(_cell(data, 'fibre', 0), <String>['9.5 g']);
        expect(_cell(data, 'fibre', 1), <String>['2.2 g']);
        expect(_cell(data, 'fat', 1), <String>['3.7 g']);
        expect(_cell(data, 'sodium', 1), <String>['362 mg']);

        for (final NutrientRow r in data.nutrients) {
          for (final List<NutritionValue> cell in r.valuesByColumn) {
            expect(cell.length, lessThanOrEqualTo(1), reason: r.name);
          }
        }

        expect(data.servingSizeAmount, 23);
        expect(data.servingSizeUnit, 'g');
        expect(data.servingsPerPackage, 2);
        expect(LabelReadingAssessor.inconsistentRows(data), isEmpty);
      });
    }

    test('joins units printed in their own column', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per 100ml', 300, 80),
        _text('Per Serving', 480, 80),
        _text('Carbohydrate / S', 20, 120),
        _text('5.5', 300, 120),
        _text('g', 400, 122),
        _text('13.8', 480, 120),
        _text('g', 580, 122),
        _text('Vitamin A / A I', 20, 150),
        _text('69', 300, 150),
        _text('Hg', 400, 152),
        _text('173', 480, 150),
        _text('µg', 580, 152),
        _text('Vitamin E', 20, 180),
        _text('0.9', 300, 180),
        _text('mg', 400, 182),
        _text('2.3', 480, 180),
        _text('mg', 580, 182),
        _text('Thiamin (Vitamin B1)', 20, 210),
        _text('0.1', 300, 210),
        _text('0.3', 480, 210),
      ]);

      expect(_cell(data, 'carbohydrate', 0), <String>['5.5 g']);
      expect(_cell(data, 'carbohydrate', 1), <String>['13.8 g']);
      expect(_cell(data, 'vitamin a', 0), <String>['69 µg']);
      expect(_cell(data, 'vitamin a', 1), <String>['173 µg']);
      expect(_cell(data, 'vitamin e', 0), <String>['0.9 mg']);
      expect(_cell(data, 'vitamin e', 1), <String>['2.3 mg']);

      // No unit anywhere in the row: usual unit, with a note.
      expect(_cell(data, 'thiamin', 0), <String>['0.1 mg']);
      expect(_row(data, 'thiamin').name, 'Vitamin B1');
      expect(
        data.notes.any((String n) => n.contains('usual unit')),
        isTrue,
      );

      // Stray letters from the unreadable Arabic half.
      expect(_row(data, 'carbohydrate').labelName, 'Carbohydrate');
      expect(_row(data, 'vitamin a').labelName, 'Vitamin A');
      expect(data.hasUnreadableScript, isTrue);
    });

    test('keeps two values in one cell when the units differ', () {
      final NutritionLabelData data = NutritionTableParser.parse(<OcrTextLine>[
        _text('Nutrition Information', 20, 40),
        _text('Per serving', 300, 80),
        _text('Energy', 20, 120),
        _text('230 kJ / 55 kcal', 300, 120),
        _text('Vitamin D', 20, 150),
        _text('5 µg (200 IU)', 300, 150),
        _text('Protein', 20, 180),
        _text('2.0 g', 300, 180),
      ]);

      expect(_cell(data, 'energy', 0), <String>['230 kJ', '55 kcal']);
      expect(_cell(data, 'vitamin d', 0).length, 2);
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
