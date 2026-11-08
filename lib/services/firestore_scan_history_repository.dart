import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/scan_record.dart';
import 'history_retention_policy.dart';
import 'scan_history_repository.dart';

// =======================================================
// FIRESTORE SCAN HISTORY REPOSITORY
// =======================================================
//
//   users/{uid}/scans/{scanId}
//     record        ScanRecord.toJson() as JSON text (the
//                   label has lists inside lists, which
//                   Firestore fields cannot hold)
//     productName, scannedAt, isFavourite   for the console
//     expiresAt     scannedAt + 90 days; null for
//                   favourites (Firestore TTL clean-up)
//     updatedAt     server time
//
// ScanHistoryService still calls saveAll() with the whole
// list; this class only writes the scans that changed and
// deletes the ones that were removed, so one change costs
// one write, not 200.
//
// Writes are not awaited: Firestore applies them on the
// phone at once (works offline) and uploads them later.
//
// Scans saved on the phone before Firestore was added are
// moved up once, the first time the user's history loads.
// =======================================================

class FirestoreScanHistoryRepository implements ScanHistoryRepository {
  FirestoreScanHistoryRepository({
    required this.userId,
    FirebaseFirestore? firestore,
    this.moveFrom,
    this.policy = const HistoryRetentionPolicy(),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final String userId;

  final FirebaseFirestore _db;

  /// Old on-phone history to move into Firestore once.
  final ScanHistoryRepository? moveFrom;

  final HistoryRetentionPolicy policy;

  // What Firestore holds now: scan id -> encoded record.
  final Map<String, String> _stored = <String, String>{};

  CollectionReference<Map<String, dynamic>> get _scans =>
      _db.collection('users').doc(userId).collection('scans');

  // =====================================================
  // LOAD
  // =====================================================

  @override
  Future<List<ScanRecord>> loadAll() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _scans.get().timeout(const Duration(seconds: 15));

    final List<ScanRecord> records = <ScanRecord>[];

    _stored.clear();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
      final ScanRecord? record = recordFromDoc(doc.data());

      if (record == null) continue;

      records.add(record);
      _stored[record.id] = encode(record);
    }

    await _moveOldPhoneHistory(records);

    records.sort((ScanRecord a, ScanRecord b) => b.scannedAt.compareTo(a.scannedAt));

    return records;
  }

  Future<void> _moveOldPhoneHistory(List<ScanRecord> records) async {
    final ScanHistoryRepository? old = moveFrom;

    if (old == null) return;

    final List<ScanRecord> local;

    try {
      local = await old.loadAll();
    } catch (_) {
      return;
    }

    if (local.isEmpty) return;

    final Set<String> ids = records.map((ScanRecord r) => r.id).toSet();
    final List<ScanRecord> missing =
        local.where((ScanRecord r) => !ids.contains(r.id)).toList();

    if (missing.isNotEmpty) {
      records.addAll(missing);
      _write(SyncPlan(toWrite: missing, toDelete: const <String>[]));
    }

    _log('moved ${missing.length} scans from this phone to Firestore');

    await old.clear();
  }

  // =====================================================
  // SAVE (only what changed)
  // =====================================================

  @override
  Future<void> saveAll(List<ScanRecord> records) async {
    _write(planChanges(_stored, records));
  }

  void _write(SyncPlan plan) {
    if (plan.isEmpty) return;

    // Firestore batches hold up to 500 operations.
    const int batchSize = 400;

    final List<void Function(WriteBatch)> operations = <void Function(WriteBatch)>[
      for (final ScanRecord r in plan.toWrite)
        (WriteBatch b) => b.set(_scans.doc(r.id), docFor(r, policy: policy)),
      for (final String id in plan.toDelete) (WriteBatch b) => b.delete(_scans.doc(id)),
    ];

    for (int start = 0; start < operations.length; start += batchSize) {
      final WriteBatch batch = _db.batch();

      for (final void Function(WriteBatch) op in operations.skip(start).take(batchSize)) {
        op(batch);
      }

      batch.commit().catchError((Object error) => _log('scan sync failed: $error'));
    }

    for (final ScanRecord r in plan.toWrite) {
      _stored[r.id] = encode(r);
    }

    for (final String id in plan.toDelete) {
      _stored.remove(id);
    }
  }

  // =====================================================
  // CLEAR (account deletion)
  // =====================================================

  /// Deletes every scan of this user. Awaited, because it
  /// must finish before the account itself is deleted.
  @override
  Future<void> clear() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _scans.get().timeout(const Duration(seconds: 20));

    final List<DocumentReference<Map<String, dynamic>>> refs =
        snapshot.docs.map((QueryDocumentSnapshot<Map<String, dynamic>> d) => d.reference).toList();

    for (int start = 0; start < refs.length; start += 400) {
      final WriteBatch batch = _db.batch();

      for (final DocumentReference<Map<String, dynamic>> ref in refs.skip(start).take(400)) {
        batch.delete(ref);
      }

      await batch.commit().timeout(const Duration(seconds: 20));
    }

    _stored.clear();

    await moveFrom?.clear();
  }

  // =====================================================
  // PURE HELPERS (unit tested)
  // =====================================================

  static String encode(ScanRecord r) => jsonEncode(r.toJson());

  /// Which scans to write and which to delete, given what
  /// Firestore holds ([stored]: id -> encoded record).
  static SyncPlan planChanges(Map<String, String> stored, List<ScanRecord> records) {
    final Set<String> keep = <String>{};
    final List<ScanRecord> toWrite = <ScanRecord>[];

    for (final ScanRecord r in records) {
      keep.add(r.id);

      if (stored[r.id] != encode(r)) toWrite.add(r);
    }

    return SyncPlan(
      toWrite: toWrite,
      toDelete: <String>[
        for (final String id in stored.keys)
          if (!keep.contains(id)) id,
      ],
    );
  }

  /// The Firestore document for one scan.
  static Map<String, dynamic> docFor(
    ScanRecord r, {
    HistoryRetentionPolicy policy = const HistoryRetentionPolicy(),
  }) {
    final DateTime? expires = policy.expiresAt(r);

    return <String, dynamic>{
      'schema': 1,
      'record': encode(r),
      'productName': r.productName,
      'scannedAt': Timestamp.fromDate(r.scannedAt),
      'isFavourite': r.isFavourite,
      'expiresAt': expires == null ? null : Timestamp.fromDate(expires),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Reads one document; null when it is unreadable (it
  /// is skipped instead of breaking the whole history).
  static ScanRecord? recordFromDoc(Map<String, dynamic> doc) {
    final Object? text = doc['record'];

    if (text is! String) return null;

    try {
      return ScanRecord.fromJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[NutriPal scans] $message');
  }
}

class SyncPlan {
  final List<ScanRecord> toWrite;
  final List<String> toDelete;

  const SyncPlan({required this.toWrite, required this.toDelete});

  bool get isEmpty => toWrite.isEmpty && toDelete.isEmpty;
}
