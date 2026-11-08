import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/nutrition_label_data.dart';
import 'package:nutripal/models/nutrition_label_json.dart';
import 'package:nutripal/models/scan_record.dart';
import 'package:nutripal/services/history_retention_policy.dart';
import 'package:nutripal/services/scan_history_repository.dart';
import 'package:nutripal/services/scan_history_service.dart';

import 'nutrition_analysis_service_test.dart' show homesoy;

void main() {
  late DateTime now;
  late InMemoryScanHistoryRepository repo;
  late ScanHistoryService service;

  ScanRecord record(String id, {required int daysAgo, bool favourite = false}) => ScanRecord(
        id: id,
        productKey: 'key-$id',
        productName: 'Product $id',
        scannedAt: now.subtract(Duration(days: daysAgo)),
        isFavourite: favourite,
        label: homesoy(),
      );

  setUp(() {
    now = DateTime(2026, 11, 8, 12);
    repo = InMemoryScanHistoryRepository();
    service = ScanHistoryService(
      repository: repo,
      clock: () => now,
      storeThumbnails: false,
    );
  });

  group('90-day retention', () {
    const HistoryRetentionPolicy policy = HistoryRetentionPolicy();

    test('a normal scan expires after 90 days, a favourite never does', () {
      expect(policy.isExpired(record('a', daysAgo: 89), now), isFalse);
      expect(policy.isExpired(record('b', daysAgo: 91), now), isTrue);
      expect(policy.isExpired(record('c', daysAgo: 400, favourite: true), now), isFalse);
    });

    test('days left before removal', () {
      expect(policy.daysLeft(record('a', daysAgo: 80), now), 10);
      expect(policy.daysLeft(record('b', daysAgo: 10, favourite: true), now), isNull);
    });

    test('loading removes expired scans but keeps favourites', () async {
      repo = InMemoryScanHistoryRepository(<ScanRecord>[
        record('old', daysAgo: 120),
        record('kept', daysAgo: 30),
        record('fav', daysAgo: 365, favourite: true),
      ]);
      service = ScanHistoryService(repository: repo, clock: () => now, storeThumbnails: false);

      await service.load();

      expect(service.history.map((ScanRecord r) => r.id), <String>['kept', 'fav']);
      expect(service.favourites.single.id, 'fav');
      expect((await repo.loadAll()).length, 2);
    });

    test('un-favouriting an old scan lets it expire', () async {
      repo = InMemoryScanHistoryRepository(<ScanRecord>[
        record('fav', daysAgo: 200, favourite: true),
      ]);
      service = ScanHistoryService(repository: repo, clock: () => now, storeThumbnails: false);

      await service.load();
      await service.setFavourite('fav', false);

      expect(service.history, isEmpty);
    });

    test('the clean-up runs again later', () async {
      await service.recordScan(label: homesoy(), productName: 'Homesoy');

      now = now.add(const Duration(days: 91));
      await service.cleanUpExpired();

      expect(service.history, isEmpty);
    });
  });

  group('recording scans', () {
    test('a scan is saved with its key nutrients', () async {
      final ScanRecord r = await service.recordScan(label: homesoy(), productName: 'Homesoy');

      expect(service.recent().single.id, r.id);
      expect(r.energyKcal, 92);
      expect(r.sodiumMg, 40);
      expect(r.summaryBasis, 'per serving');
      expect(r.servingText, '236 ml per serving');
      expect(r.isFavourite, isFalse);
    });

    test('rescanning the same label updates it instead of duplicating', () async {
      final ScanRecord first = await service.recordScan(label: homesoy(), productName: 'Homesoy');
      await service.setFavourite(first.id, true);

      now = now.add(const Duration(days: 3));
      final ScanRecord again = await service.recordScan(label: homesoy(), productName: 'Scanned product');

      expect(service.history.length, 1);
      expect(again.id, first.id);
      expect(again.isFavourite, isTrue);
      expect(again.productName, 'Homesoy');
      expect(again.scannedAt, now);
    });

    test('a name found automatically never replaces a saved name', () async {
      final ScanRecord first = await service.recordScan(label: homesoy(), productName: 'Scanned product');
      await service.updateScan(first.id, productName: 'My soy milk');

      final ScanRecord again = await service.recordScan(
        label: homesoy(),
        productName: 'Homesoy Soya Bean Drink',
        keepExistingName: true,
      );

      expect(again.productName, 'My soy milk');
    });

    test('a name found automatically replaces "Scanned product"', () async {
      await service.recordScan(label: homesoy(), productName: 'Scanned product');

      final ScanRecord again = await service.recordScan(
        label: homesoy(),
        productName: 'Homesoy Soya Bean Drink',
        keepExistingName: true,
      );

      expect(again.productName, 'Homesoy Soya Bean Drink');
    });

    test('same barcode = same product', () {
      final NutritionLabelData a = homesoy().copyWith(barcode: '9556041600013');
      final NutritionLabelData b = homesoy().copyWith(barcode: '9556041600013', servingSizeAmount: 250);

      expect(ScanRecord.productKeyFor(a), ScanRecord.productKeyFor(b));
      expect(ScanRecord.productKeyFor(a), isNot(ScanRecord.productKeyFor(homesoy())));
    });

    test('recent shows only the latest few', () async {
      for (int i = 0; i < 7; i++) {
        await service.recordScan(
          label: homesoy().copyWith(barcode: 'code$i'),
          productName: 'Product $i',
        );
        now = now.add(const Duration(minutes: 1));
      }

      expect(service.recent(5).length, 5);
      expect(service.recent(5).first.productName, 'Product 6');
      expect(service.history.length, 7);
    });

    test('favourites cannot be deleted from history', () async {
      final ScanRecord r = await service.recordScan(label: homesoy(), productName: 'Homesoy');
      await service.setFavourite(r.id, true);

      expect(await service.deleteScan(r.id), isFalse);

      await service.setFavourite(r.id, false);

      expect(await service.deleteScan(r.id), isTrue);
      expect(service.history, isEmpty);
    });
  });

  group('account deletion', () {
    test('deleting the account removes history and favourites', () async {
      final ScanRecord r = await service.recordScan(label: homesoy(), productName: 'Homesoy');
      await service.setFavourite(r.id, true);

      await service.deleteAllForUser('user-1');

      expect(service.history, isEmpty);
      expect(service.favourites, isEmpty);
      expect(await repo.loadAll(), isEmpty);
    });
  });

  group('storage format', () {
    test('a record survives a JSON round trip', () {
      final ScanRecord r = record('x', daysAgo: 2, favourite: true).copyWith(
        favouritedAt: now,
        energyKcal: 92,
      );

      final ScanRecord back = ScanRecord.fromJson(r.toJson())!;

      expect(back.id, 'x');
      expect(back.isFavourite, isTrue);
      expect(back.scannedAt, r.scannedAt);
      expect(back.energyKcal, 92);
      expect(back.label.nutrients.length, homesoy().nutrients.length);
      expect(back.label.columnIndexFor(NutritionColumnBasis.per100ml), 1);
      expect(back.label.nutrients[7].valuesByColumn[0].single.amount, 40);
    });

    test('label JSON keeps columns, values and the source', () {
      final NutritionLabelData back = NutritionLabelJson.fromJson(
        NutritionLabelJson.toJson(
          homesoy().copyWith(extractionMethod: NutritionExtractionMethod.barcode),
        ),
      );

      expect(back.servingSizeAmount, 236);
      expect(back.extractionMethod, NutritionExtractionMethod.barcode);
      expect(back.nutrients.first.name, 'Energy');
    });

    test('a broken entry is skipped, not fatal', () {
      expect(ScanRecord.fromJson(<String, dynamic>{'id': 'x'}), isNull);
      expect(ScanRecord.fromJson('nonsense'), isNull);
    });
  });
}
