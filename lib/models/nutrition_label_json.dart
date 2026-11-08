// =======================================================
// NUTRITION LABEL <-> JSON
// =======================================================
//
// Saves a label (as read and confirmed by the user) inside
// a scan record, so History and Favourites can reopen the
// full result later. The OCR raw text is not stored: it is
// large and only useful while scanning.
//
// Kept beside the model rather than inside it, so the
// parser's model file stays unchanged. Unit tested.
// =======================================================

import 'nutrition_label_data.dart';

class NutritionLabelJson {
  NutritionLabelJson._();

  static Map<String, dynamic> toJson(NutritionLabelData d) => <String, dynamic>{
        'servingSizeAmount': d.servingSizeAmount,
        'servingSizeUnit': d.servingSizeUnit,
        'servingsPerPackage': d.servingsPerPackage,
        'servingUnitAmount': d.servingUnitAmount,
        'servingUnitName': d.servingUnitName,
        'columns': <Map<String, dynamic>>[
          for (final NutritionColumn c in d.columns)
            <String, dynamic>{
              'id': c.id,
              'label': c.label,
              'basis': c.basis.name,
            },
        ],
        'nutrients': <Map<String, dynamic>>[
          for (final NutrientRow r in d.nutrients)
            <String, dynamic>{
              'name': r.name,
              if (r.rawName != null) 'rawName': r.rawName,
              'order': r.order,
              'values': <List<Map<String, dynamic>>>[
                for (final List<NutritionValue> cell in r.valuesByColumn)
                  <Map<String, dynamic>>[
                    for (final NutritionValue v in cell)
                      <String, dynamic>{
                        'amount': v.amount,
                        'unit': v.unit,
                        'raw': v.rawText,
                      },
                  ],
              ],
            },
        ],
        'extractionMethod': d.extractionMethod.name,
        'notes': d.notes,
        'productName': d.productName,
        'productBrand': d.productBrand,
        'barcode': d.barcode,
      };

  static NutritionLabelData fromJson(Map<String, dynamic> j) {
    double? number(Object? v) => v is num ? v.toDouble() : null;

    T byName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final T v in values) {
        if (v.name == name) return v;
      }

      return fallback;
    }

    final List<dynamic> columns = j['columns'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> rows = j['nutrients'] as List<dynamic>? ?? const <dynamic>[];

    return NutritionLabelData(
      rawText: '',
      servingSizeAmount: number(j['servingSizeAmount']),
      servingSizeUnit: j['servingSizeUnit'] as String?,
      servingsPerPackage: number(j['servingsPerPackage']),
      servingUnitAmount: number(j['servingUnitAmount']),
      servingUnitName: j['servingUnitName'] as String?,
      columns: <NutritionColumn>[
        for (int i = 0; i < columns.length; i++)
          NutritionColumn(
            id: (columns[i] as Map<String, dynamic>)['id'] as String? ?? 'col_$i',
            label: (columns[i] as Map<String, dynamic>)['label'] as String? ?? '',
            basis: byName(
              NutritionColumnBasis.values,
              (columns[i] as Map<String, dynamic>)['basis'],
              NutritionColumnBasis.unknown,
            ),
            xCenter: i.toDouble(),
          ),
      ],
      nutrients: <NutrientRow>[
        for (final dynamic raw in rows)
          if (raw is Map<String, dynamic>)
            NutrientRow(
              name: raw['name'] as String? ?? '',
              rawName: raw['rawName'] as String?,
              order: (raw['order'] as num?)?.toInt() ?? 0,
              valuesByColumn: <List<NutritionValue>>[
                for (final dynamic cell in raw['values'] as List<dynamic>? ?? const <dynamic>[])
                  <NutritionValue>[
                    for (final dynamic v in cell as List<dynamic>)
                      if (v is Map<String, dynamic> && v['amount'] is num)
                        NutritionValue(
                          amount: (v['amount'] as num).toDouble(),
                          unit: v['unit'] as String? ?? '?',
                          rawText: v['raw'] as String? ?? '',
                        ),
                  ],
              ],
            ),
      ],
      extractionMethod: byName(
        NutritionExtractionMethod.values,
        j['extractionMethod'],
        NutritionExtractionMethod.onDevice,
      ),
      notes: <String>[
        for (final dynamic n in j['notes'] as List<dynamic>? ?? const <dynamic>[])
          if (n is String) n,
      ],
      productName: j['productName'] as String?,
      productBrand: j['productBrand'] as String?,
      barcode: j['barcode'] as String?,
    );
  }
}
