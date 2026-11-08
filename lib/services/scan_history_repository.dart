// =======================================================
// SCAN HISTORY REPOSITORY (where records are stored)
// =======================================================
//
// ScanHistoryService only talks to this interface, so the
// storage can be swapped without touching any screen:
//
//   LocalScanHistoryRepository   on this phone
//                                (shared_preferences), one
//                                list per signed-in user.
//   InMemoryScanHistoryRepository tests.
//   (later) FirestoreScanHistoryRepository
//                                users/{uid}/scans/{id} with
//                                the same fields as
//                                ScanRecord.toJson().
// =======================================================

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_record.dart';

abstract class ScanHistoryRepository {
  Future<List<ScanRecord>> loadAll();

  Future<void> saveAll(List<ScanRecord> records);

  /// Removes everything stored for this user (account
  /// deletion).
  Future<void> clear();
}

class LocalScanHistoryRepository implements ScanHistoryRepository {
  LocalScanHistoryRepository({required this.userId});

  // Firebase Auth uid, or 'guest'. Each account on the
  // phone has its own history.
  final String userId;

  String get _key => 'nutripal.scan_history.v1.$userId';

  @override
  Future<List<ScanRecord>> loadAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? text = prefs.getString(_key);

    if (text == null || text.isEmpty) return <ScanRecord>[];

    try {
      final Object? decoded = jsonDecode(text);

      if (decoded is! List) return <ScanRecord>[];

      return <ScanRecord>[
        for (final Object? item in decoded)
          if (ScanRecord.fromJson(item) case final ScanRecord r) r,
      ];
    } catch (_) {
      // Corrupt data: start again rather than crash.
      return <ScanRecord>[];
    }
  }

  @override
  Future<void> saveAll(List<ScanRecord> records) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _key,
      jsonEncode(<Map<String, dynamic>>[
        for (final ScanRecord r in records) r.toJson(),
      ]),
    );
  }

  @override
  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
}

class InMemoryScanHistoryRepository implements ScanHistoryRepository {
  InMemoryScanHistoryRepository([List<ScanRecord>? initial])
      : _records = <ScanRecord>[...?initial];

  List<ScanRecord> _records;

  int saves = 0;

  @override
  Future<List<ScanRecord>> loadAll() async => <ScanRecord>[..._records];

  @override
  Future<void> saveAll(List<ScanRecord> records) async {
    saves++;
    _records = <ScanRecord>[...records];
  }

  @override
  Future<void> clear() async {
    _records = <ScanRecord>[];
  }
}
