import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/models/scan_record.dart';
import 'package:nutripal/services/scan_filter.dart';

import 'nutrition_analysis_service_test.dart' show homesoy;

void main() {
  ScanRecord record(String id, String name, {bool barcode = false, String? brand}) => ScanRecord(
        id: id,
        productKey: 'key-$id',
        productName: name,
        scannedAt: DateTime(2026, 11, 9),
        label: homesoy().copyWith(
          extractionMethod:
              barcode ? NutritionExtractionMethod.barcode : NutritionExtractionMethod.onDevice,
          productBrand: brand,
        ),
      );

  final List<ScanRecord> scans = <ScanRecord>[
    record('1', 'Homesoy Soya Milk', barcode: true),
    record('2', 'Coca-Cola Coke Kurang Gula'),
    record('3', 'Oat Cracker', brand: 'Julie\'s'),
  ];

  List<String> ids(List<ScanRecord> list) => list.map((ScanRecord r) => r.id).toList();

  test('no search and All shows everything, newest order kept', () {
    expect(ids(ScanFilter.apply(scans)), <String>['1', '2', '3']);
  });

  test('search ignores case and matches every word', () {
    expect(ids(ScanFilter.apply(scans, query: 'soya')), <String>['1']);
    expect(ids(ScanFilter.apply(scans, query: 'COKE gula')), <String>['2']);
    expect(ids(ScanFilter.apply(scans, query: 'coke milk')), isEmpty);
  });

  test('search also matches the brand', () {
    expect(ids(ScanFilter.apply(scans, query: 'julie')), <String>['3']);
  });

  test('label and barcode filters', () {
    expect(ids(ScanFilter.apply(scans, kind: ScanKind.barcode)), <String>['1']);
    expect(ids(ScanFilter.apply(scans, kind: ScanKind.label)), <String>['2', '3']);
    expect(ids(ScanFilter.apply(scans, query: 'soya', kind: ScanKind.label)), isEmpty);
  });

  test('Scan History periods and favourites', () {
    final DateTime now = DateTime(2026, 11, 9, 13);

    ScanRecord at(String id, DateTime when, {bool favourite = false}) => ScanRecord(
          id: id,
          productKey: 'key-$id',
          productName: 'Product $id',
          scannedAt: when,
          isFavourite: favourite,
          label: homesoy(),
        );

    final List<ScanRecord> list = <ScanRecord>[
      at('today', DateTime(2026, 11, 9, 8)),
      at('6days', DateTime(2026, 11, 3, 23)),
      at('7days', DateTime(2026, 11, 2, 10)),
      at('29days', DateTime(2026, 10, 11, 9), favourite: true),
      at('40days', DateTime(2026, 9, 30)),
    ];

    List<String> by(ScanPeriod p) => ids(ScanFilter.apply(list, period: p, now: now));

    expect(by(ScanPeriod.all).length, 5);
    expect(by(ScanPeriod.today), <String>['today']);
    expect(by(ScanPeriod.week), <String>['today', '6days']);
    expect(by(ScanPeriod.month), <String>['today', '6days', '7days', '29days']);
    expect(by(ScanPeriod.favourites), <String>['29days']);
  });
}
