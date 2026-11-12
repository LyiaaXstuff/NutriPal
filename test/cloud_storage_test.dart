import 'package:flutter_test/flutter_test.dart';
import 'package:nutripal/models/profile_setup_data.dart';
import 'package:nutripal/models/scan_record.dart';
import 'package:nutripal/services/firestore_scan_history_repository.dart';

import 'nutrition_analysis_service_test.dart' show homesoy;

// Saving to Firestore: what is written and read back. The
// Firestore calls themselves need a real project, so these
// tests cover the conversion and change-tracking logic.

void main() {
  group('Profile (users/{uid}.profile)', () {
    test('every setting survives a save and load', () {
      final ProfileSetupData original = ProfileSetupData(
        nickname: 'Audry',
        fullName: 'Audrylyia Test',
        email: 'should-not-be-saved@example.com',
        dateOfBirth: DateTime(2002, 3, 9),
        diabetes: true,
        hypertension: true,
        diabetesType: 'Type 2 diabetes',
        highCholesterol: true,
        highLdl: true,
        weightManagement: true,
        weightGoal: 'Lose weight',
        genderForEnergyEstimate: 'Female',
        currentWeight: 65.5,
        height: 158,
        activityLevel: 'Low active',
        energyChangeKcal: 750,
        providerSodiumLimitMg: 1500,
        providerEnergyKcal: 1500,
        avatarPath: '/data/user/0/avatar.jpg',
      );

      final Map<String, dynamic> json = original.toJson();
      final ProfileSetupData loaded =
          ProfileSetupData.fromJson(json, email: 'audry@example.com');

      expect(loaded.nickname, 'Audry');
      expect(loaded.fullName, 'Audrylyia Test');
      expect(loaded.dateOfBirth, DateTime(2002, 3, 9));
      expect(loaded.diabetes, isTrue);
      expect(loaded.hypertension, isTrue);
      expect(loaded.diabetesType, 'Type 2 diabetes');
      expect(loaded.highCholesterol, isTrue);
      expect(loaded.highLdl, isTrue);
      expect(loaded.highTriglycerides, isFalse);
      expect(loaded.weightManagement, isTrue);
      expect(loaded.weightGoal, 'Lose weight');
      expect(loaded.genderForEnergyEstimate, 'Female');
      expect(loaded.currentWeight, 65.5);
      expect(loaded.height, 158);
      expect(loaded.weightUnit, 'kg');
      expect(loaded.activityLevel, 'Low active');
      expect(loaded.energyChangeKcal, 750);
      expect(loaded.providerSodiumLimitMg, 1500);
      expect(loaded.providerEnergyKcal, 1500);

      // Email comes from Firebase Auth; the avatar file is
      // on the phone only.
      expect(json.containsKey('email'), isFalse);
      expect(loaded.email, 'audry@example.com');
      expect(loaded.avatarPath, isNull);
    });

    test('an older activity value loads as the NASEM level', () {
      final ProfileSetupData p = ProfileSetupData.fromJson(<String, dynamic>{
        'weight': <String, dynamic>{'activityLevel': 'Lightly active'},
      });

      expect(p.activityLevel, 'Low active');
    });

    test('date of birth is saved as a plain date', () {
      final ProfileSetupData p = ProfileSetupData(dateOfBirth: DateTime(1999, 12, 31, 23, 30));

      expect(p.toJson()['dateOfBirth'], '1999-12-31');
    });

    test('missing or broken fields fall back to defaults', () {
      final ProfileSetupData p = ProfileSetupData.fromJson(<String, dynamic>{
        'nickname': 42,
        'conditions': 'not a map',
        'weight': <String, dynamic>{'currentWeight': 'heavy'},
        'dateOfBirth': 'yesterday',
      });

      expect(p.nickname, '');
      expect(p.diabetes, isFalse);
      expect(p.currentWeight, isNull);
      expect(p.weightUnit, 'kg');
      expect(p.dateOfBirth, isNull);
    });
  });

  group('Scans (users/{uid}/scans)', () {
    ScanRecord scan(String id, {String name = 'Homesoy', bool favourite = false}) => ScanRecord(
          id: id,
          productKey: 'key-$id',
          productName: name,
          scannedAt: DateTime(2026, 11, 8, 10),
          isFavourite: favourite,
          label: homesoy(),
        );

    test('a stored record reads back exactly', () {
      final ScanRecord r = scan('a', favourite: true);

      final ScanRecord? back = FirestoreScanHistoryRepository.recordFromDoc(
        <String, dynamic>{'record': FirestoreScanHistoryRepository.encode(r)},
      );

      expect(back, isNotNull);
      expect(FirestoreScanHistoryRepository.encode(back!), FirestoreScanHistoryRepository.encode(r));
      expect(back.label.nutrients.length, r.label.nutrients.length);
    });

    test('an unreadable document is skipped', () {
      expect(FirestoreScanHistoryRepository.recordFromDoc(<String, dynamic>{}), isNull);
      expect(
        FirestoreScanHistoryRepository.recordFromDoc(<String, dynamic>{'record': '{broken'}),
        isNull,
      );
    });

    test('only changed scans are written and removed ones deleted', () {
      final ScanRecord a = scan('a');
      final ScanRecord b = scan('b');
      final ScanRecord c = scan('c');

      final Map<String, String> stored = <String, String>{
        'a': FirestoreScanHistoryRepository.encode(a),
        'b': FirestoreScanHistoryRepository.encode(b),
        'c': FirestoreScanHistoryRepository.encode(c),
      };

      // a unchanged, b renamed, c deleted, d new.
      final SyncPlan plan = FirestoreScanHistoryRepository.planChanges(
        stored,
        <ScanRecord>[a, b.copyWith(productName: 'My soy milk'), scan('d')],
      );

      expect(plan.toWrite.map((ScanRecord r) => r.id), <String>['b', 'd']);
      expect(plan.toDelete, <String>['c']);
    });

    test('nothing to do when nothing changed', () {
      final ScanRecord a = scan('a');

      final SyncPlan plan = FirestoreScanHistoryRepository.planChanges(
        <String, String>{'a': FirestoreScanHistoryRepository.encode(a)},
        <ScanRecord>[a],
      );

      expect(plan.isEmpty, isTrue);
    });

    test('scans that were never loaded are never deleted', () {
      // After a failed load nothing is "stored", so saving
      // a new scan cannot delete the user's other scans.
      final SyncPlan plan = FirestoreScanHistoryRepository.planChanges(
        <String, String>{},
        <ScanRecord>[scan('new')],
      );

      expect(plan.toDelete, isEmpty);
      expect(plan.toWrite.single.id, 'new');
    });
  });
}
