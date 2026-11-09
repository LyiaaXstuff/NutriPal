import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/nutrition_label_data.dart';
import 'nutrient_name_normalizer.dart';

// =======================================================
// FOOD DATABASE (Open Food Facts)
// =======================================================
//
// Looks up a product barcode in Open Food Facts, the free,
// open food database (no API key needed), and turns its
// nutrition facts into the same NutritionLabelData the
// label scanner produces, so the review screen and the
// health analysis work the same way.
//
// Open Food Facts stores every nutrient it has for the
// product, so nutrients are read dynamically: anything in
// the product's "nutriments" is shown, not a fixed list.
//
// The data is added by the community and can be
// incomplete or out of date, so the result carries a note
// asking the user to compare it with the pack.
// =======================================================

class FoodDatabaseException implements Exception {
  final String message;

  const FoodDatabaseException(this.message);

  @override
  String toString() => message;
}

class FoodDatabaseService {
  FoodDatabaseService._();

  static const String _host = 'world.openfoodfacts.org';

  // Open Food Facts asks every app to identify itself.
  static const String _userAgent = 'NutriPal/1.0 (Android; university project)';

  static const List<String> _fields = <String>[
    'code',
    'product_name',
    'product_name_en',
    'product_name_ms',
    'generic_name',
    'brands',
    'quantity',
    'serving_size',
    'serving_quantity',
    'serving_quantity_unit',
    'nutrition_data_per',
    'nutriments',
    'image_front_url',
  ];

  // =====================================================
  // LOOKUP
  // =====================================================

  /// The product's nutrition facts, or null when Open Food
  /// Facts does not know this barcode.
  static Future<NutritionLabelData?> lookup(
    String barcode, {
    http.Client? client,
  }) async {
    final String code = barcode.replaceAll(RegExp(r'\D'), '');

    if (code.length < 8) {
      throw const FoodDatabaseException('This barcode is not valid.');
    }

    final Uri uri = Uri.https(
      _host,
      '/api/v2/product/$code.json',
      <String, String>{'fields': _fields.join(',')},
    );

    final http.Client httpClient = client ?? http.Client();

    final http.Response response;

    try {
      response = await httpClient
          .get(uri, headers: <String, String>{'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const FoodDatabaseException(
        'Could not reach the food database. Please check your internet connection.',
      );
    } finally {
      if (client == null) httpClient.close();
    }

    if (response.statusCode == 404) return null;

    if (response.statusCode != 200) {
      throw FoodDatabaseException(
        'The food database is not available right now (${response.statusCode}). '
        'Please try again later.',
      );
    }

    final Object? body = jsonDecode(utf8.decode(response.bodyBytes));

    if (body is! Map<String, dynamic>) return null;

    if (body['status'] != 1 || body['product'] is! Map) return null;

    return fromOpenFoodFacts(
      Map<String, dynamic>.from(body['product'] as Map),
      barcode: code,
    );
  }

  // =====================================================
  // OPEN FOOD FACTS PRODUCT -> NutritionLabelData
  // =====================================================

  static NutritionLabelData fromOpenFoodFacts(
    Map<String, dynamic> product, {
    required String barcode,
  }) {
    final Map<String, dynamic> nutriments = product['nutriments'] is Map
        ? Map<String, dynamic>.from(product['nutriments'] as Map)
        : <String, dynamic>{};

    final bool liquid = _isLiquid(product);

    final _Serving? serving = _servingOf(product, liquid: liquid);

    // "1 glass (200 ml)", "2 biscuits (25 g)": the everyday
    // measure, when the entry has one.
    final _Household? household = serving == null ? null : _householdOf(product['serving_size']);

    // Nutrient keys present ("proteins", "vitamin-c", ...).
    final Set<String> keys = <String>{};

    for (final String key in nutriments.keys) {
      final RegExpMatch? m = RegExp(r'^(.+)_(100g|serving)$').firstMatch(key);

      if (m != null && !_skipped(m.group(1)!)) keys.add(m.group(1)!);
    }

    // Salt is calculated from sodium by Open Food Facts;
    // Malaysian labels print sodium, so show only that.
    if (keys.contains('sodium')) keys.remove('salt');

    // Energy is shown as one row (kcal and kJ together).
    final bool hasEnergy = keys.remove('energy-kcal') |
        keys.remove('energy-kj') |
        keys.remove('energy');

    final bool hasPerServing = serving != null &&
        nutriments.keys.any(
          (String k) => k.endsWith('_serving') && _number(nutriments[k]) != null,
        );

    final String servingLabel = serving == null
        ? 'Per serving'
        : 'Per serving (${_format(serving.amount)} ${serving.unit})';

    final List<NutritionColumn> columns = <NutritionColumn>[
      NutritionColumn(
        id: 'per100',
        label: liquid ? 'Per 100 ml' : 'Per 100 g',
        basis: liquid
            ? NutritionColumnBasis.per100ml
            : NutritionColumnBasis.per100g,
        xCenter: 0,
      ),
      if (hasPerServing)
        NutritionColumn(
          id: 'perServing',
          label: servingLabel,
          basis: NutritionColumnBasis.perServing,
          xCenter: 1,
        ),
    ];

    final List<String> suffixes = <String>[
      '100g',
      if (hasPerServing) 'serving',
    ];

    final List<NutrientRow> rows = <NutrientRow>[];

    void addRow(String name, List<List<NutritionValue>> cells) {
      if (cells.every((List<NutritionValue> cell) => cell.isEmpty)) return;

      rows.add(
        NutrientRow(
          name: NutrientNameNormalizer.normalize(name),
          order: rows.length,
          valuesByColumn: cells,
        ),
      );
    }

    // ---------------------------------------------------
    // ENERGY
    // ---------------------------------------------------

    if (hasEnergy) {
      addRow('Energy', <List<NutritionValue>>[
        for (final String suffix in suffixes)
          <NutritionValue>[
            ..._energyValue(nutriments, 'energy-kcal', suffix, 'kcal'),
            ..._energyValue(nutriments, 'energy-kj', suffix, 'kJ'),
          ],
      ]);
    }

    // ---------------------------------------------------
    // OTHER NUTRIENTS, in the usual label order
    // ---------------------------------------------------

    final List<String> ordered = keys.toList()
      ..sort((String a, String b) {
        final int ia = _labelOrder.indexOf(a);
        final int ib = _labelOrder.indexOf(b);

        if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
        if (ia >= 0) return -1;
        if (ib >= 0) return 1;

        return a.compareTo(b);
      });

    for (final String key in ordered) {
      final String unit = _displayUnit(key, nutriments['${key}_unit']);

      addRow(_displayName(key), <List<NutritionValue>>[
        for (final String suffix in suffixes)
          <NutritionValue>[
            if (_number(nutriments['${key}_$suffix']) != null)
              NutritionValue(
                amount: _round(
                  _fromGrams(_number(nutriments['${key}_$suffix'])!, unit),
                ),
                unit: unit,
                rawText: '${nutriments['${key}_$suffix']}',
              ),
          ],
      ]);
    }

    return NutritionLabelData(
      servingSizeAmount: serving?.amount,
      servingSizeUnit: serving?.unit,
      servingUnitAmount: household?.amount,
      servingUnitName: household?.name,
      columns: columns,
      nutrients: rows,
      rawText: '',
      extractionMethod: NutritionExtractionMethod.barcode,
      productName: _productName(product),
      productBrand: _firstBrand(product['brands']),
      barcode: barcode,
      productImageUrl: _imageUrl(product['image_front_url']),
      notes: const <String>[
        'Nutrition values come from Open Food Facts, a community food '
            'database. Please compare them with the label on the pack.',
      ],
    );
  }

  // =====================================================
  // HELPERS
  // =====================================================

  // Usual order on Malaysian nutrition labels.
  static const List<String> _labelOrder = <String>[
    'carbohydrates',
    'sugars',
    'added-sugars',
    'proteins',
    'fat',
    'saturated-fat',
    'monounsaturated-fat',
    'polyunsaturated-fat',
    'trans-fat',
    'cholesterol',
    'fiber',
    'sodium',
    'salt',
  ];

  // Open Food Facts keys that are scores or properties,
  // not nutrients.
  static bool _skipped(String key) {
    return key.startsWith('nutrition-score') ||
        key.startsWith('nova') ||
        key.startsWith('fruits-vegetables') ||
        key.startsWith('carbon-footprint') ||
        key.startsWith('energy-from') ||
        key == 'alcohol' ||
        key == 'ph' ||
        key == 'cocoa' ||
        key == 'collagen-meat-protein-ratio';
  }

  // Readable names for Open Food Facts keys; the
  // normaliser then gives the canonical NutriPal name.
  static const Map<String, String> _names = <String, String>{
    'carbohydrates': 'Carbohydrate',
    'sugars': 'Total Sugars',
    'added-sugars': 'Added Sugars',
    'proteins': 'Protein',
    'fat': 'Total Fat',
    'saturated-fat': 'Saturated Fat',
    'monounsaturated-fat': 'Monounsaturated Fat',
    'polyunsaturated-fat': 'Polyunsaturated Fat',
    'trans-fat': 'Trans Fat',
    'fiber': 'Dietary Fibre',
    'vitamin-pp': 'Niacin (Vitamin B3)',
    'pantothenic-acid': 'Pantothenic Acid',
    'folates': 'Folate',
  };

  static String _displayName(String key) {
    final String? known = _names[key];

    if (known != null) return known;

    // "vitamin-b12" -> "Vitamin B12", "omega-3-fat" -> "Omega 3 Fat"
    return key
        .split('-')
        .where((String part) => part.isNotEmpty)
        .map(
          (String part) => RegExp(r'\d').hasMatch(part) && part.length <= 3
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  // Units used on Malaysian labels for each nutrient.
  static const Set<String> _milligrams = <String>{
    'sodium',
    'cholesterol',
    'calcium',
    'iron',
    'potassium',
    'magnesium',
    'zinc',
    'phosphorus',
    'copper',
    'manganese',
    'chloride',
    'vitamin-c',
    'vitamin-e',
    'vitamin-b1',
    'vitamin-b2',
    'vitamin-pp',
    'vitamin-b6',
    'pantothenic-acid',
    'caffeine',
    'taurine',
  };

  static const Set<String> _micrograms = <String>{
    'vitamin-a',
    'vitamin-d',
    'vitamin-k',
    'vitamin-b9',
    'folates',
    'vitamin-b12',
    'biotin',
    'iodine',
    'selenium',
    'chromium',
    'molybdenum',
    'fluoride',
  };

  static String _displayUnit(String key, Object? storedUnit) {
    if (_milligrams.contains(key)) return 'mg';
    if (_micrograms.contains(key)) return 'µg';

    final String unit = '${storedUnit ?? ''}'.toLowerCase();

    if (unit == 'mg') return 'mg';
    if (unit == 'µg' || unit == 'mcg' || unit == 'μg') return 'µg';

    return 'g';
  }

  // Open Food Facts stores masses in grams.
  static double _fromGrams(double grams, String unit) {
    switch (unit) {
      case 'mg':
        return grams * 1000;
      case 'µg':
        return grams * 1000000;
      default:
        return grams;
    }
  }

  static List<NutritionValue> _energyValue(
    Map<String, dynamic> nutriments,
    String key,
    String suffix,
    String unit,
  ) {
    double? value = _number(nutriments['${key}_$suffix']);

    // Older products only have "energy" (kJ).
    if (value == null && unit == 'kJ') {
      value = _number(nutriments['energy_$suffix']);
    }

    if (value == null) return const <NutritionValue>[];

    return <NutritionValue>[
      NutritionValue(
        amount: value.roundToDouble(),
        unit: unit,
        rawText: '$value',
      ),
    ];
  }

  static bool _isLiquid(Map<String, dynamic> product) {
    final String servingUnit =
        '${product['serving_quantity_unit'] ?? ''}'.toLowerCase();

    if (servingUnit == 'ml') return true;

    final String text =
        '${product['quantity'] ?? ''} ${product['serving_size'] ?? ''}';

    return RegExp(r'\d\s*(ml|cl|dl|l)\b', caseSensitive: false).hasMatch(text) &&
        !RegExp(r'\d\s*(g|kg)\b', caseSensitive: false).hasMatch(text);
  }

  static _Serving? _servingOf(
    Map<String, dynamic> product, {
    required bool liquid,
  }) {
    final double? quantity = _number(product['serving_quantity']);

    if (quantity != null && quantity > 0) {
      final String unit =
          '${product['serving_quantity_unit'] ?? ''}'.toLowerCase();

      return _Serving(
        quantity,
        unit == 'ml' || (unit.isEmpty && liquid) ? 'ml' : 'g',
      );
    }

    // "30 g", "250ml", "2 biscuits (25 g)"
    final RegExpMatch? m = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
      caseSensitive: false,
    ).firstMatch('${product['serving_size'] ?? ''}');

    if (m == null) return null;

    final double? amount = double.tryParse(m.group(1)!.replaceAll(',', '.'));

    if (amount == null || amount <= 0) return null;

    return _Serving(amount, m.group(2)!.toLowerCase());
  }

  /// The everyday measure in an Open Food Facts serving
  /// size such as "1 glass (200 ml)"; null for "30 g" or
  /// "1 portion (250 ml)".
  static _Household? _householdOf(Object? servingSize) {
    final RegExpMatch? m = RegExp(
      r'^\s*(\d+(?:[.,]\d+)?|½|¼|1/2|1/4)\s*([a-zA-Z][a-zA-Z ]{1,24}?)\s*\(\s*\d',
    ).firstMatch('${servingSize ?? ''}');

    if (m == null) return null;

    final String n = m.group(1)!;
    final double? amount = switch (n) {
      '½' || '1/2' => 0.5,
      '¼' || '1/4' => 0.25,
      _ => double.tryParse(n.replaceAll(',', '.')),
    };

    final String name = m.group(2)!.trim().toLowerCase();

    const Set<String> generic = <String>{
      'portion', 'portions', 'serving', 'servings', 'serve', 'g', 'ml', 'gram', 'grams',
    };

    if (amount == null || amount <= 0 || generic.contains(name)) return null;

    return _Household(amount, name);
  }

  /// The front-of-pack photo, only as an https link.
  static String? _imageUrl(Object? value) {
    final String url = '${value ?? ''}'.trim();

    return url.startsWith('https://') ? url : null;
  }

  static String? _productName(Map<String, dynamic> product) {
    for (final String key in <String>[
      'product_name',
      'product_name_en',
      'product_name_ms',
      'generic_name',
    ]) {
      final String value = '${product[key] ?? ''}'.trim();

      if (value.isNotEmpty) return value;
    }

    return null;
  }

  static String? _firstBrand(Object? brands) {
    final String first = '${brands ?? ''}'.split(',').first.trim();

    return first.isEmpty ? null : first;
  }

  static double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));

    return null;
  }

  static double _round(double value) {
    final int decimals = value >= 100
        ? 0
        : value >= 10
            ? 1
            : 2;

    final num factor = <int>[1, 10, 100][decimals];

    return (value * factor).roundToDouble() / factor;
  }

  static String _format(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

class _Serving {
  final double amount;
  final String unit;

  const _Serving(this.amount, this.unit);
}

class _Household {
  final double amount;
  final String name;

  const _Household(this.amount, this.name);
}
