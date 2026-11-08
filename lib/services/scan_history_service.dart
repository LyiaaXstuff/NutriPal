// =======================================================
// SCAN HISTORY SERVICE
// =======================================================
//
// One place for Recent scans, History and Favourites.
//
//   recordScan()       every finished analysis is saved to
//                      history (a rescan of the same
//                      product updates its record).
//   toggleFavourite()  favourites are protected from the
//                      90-day clean-up.
//   cleanUpExpired()   applies HistoryRetentionPolicy.
//
// CLEAN-UP STRATEGY (local, on use): expired records are
// removed when history is loaded (Home opens), when a scan
// is recorded and when History / Favourites open. There is
// no backend yet, so nothing runs in the background; with
// Firestore later, a scheduled Cloud Function or a
// Firestore TTL policy can run the same rule server-side.
//
// Screens listen with ListenableBuilder(listenable:
// ScanHistoryService.instance, ...).
// =======================================================

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../models/scan_record.dart';
import 'history_retention_policy.dart';
import 'nutrition_analysis_service.dart';
import 'scan_history_repository.dart';

typedef Clock = DateTime Function();

class ScanHistoryService extends ChangeNotifier {
  ScanHistoryService({
    ScanHistoryRepository? repository,
    this.policy = const HistoryRetentionPolicy(),
    Clock? clock,
    this.storeThumbnails = true,
  })  : _repository = repository,
        _injected = repository != null,
        _clock = clock ?? DateTime.now;

  /// The app-wide instance (local storage).
  static final ScanHistoryService instance = ScanHistoryService();

  ScanHistoryRepository? _repository;

  // True in tests: never switch to local storage.
  final bool _injected;

  // 90-day rule (shown on the History screen too).
  final HistoryRetentionPolicy policy;

  final Clock _clock;

  // False in tests: no photo copies on disk.
  final bool storeThumbnails;

  String? _loadedFor;

  List<ScanRecord> _records = <ScanRecord>[];

  bool _loaded = false;

  bool get isLoaded => _loaded;

  DateTime get now => _clock();

  // =====================================================
  // VIEWS
  // =====================================================

  /// Everything kept (history), newest first.
  List<ScanRecord> get history => List<ScanRecord>.unmodifiable(_records);

  /// The latest few, for Home.
  List<ScanRecord> recent([int count = 5]) =>
      List<ScanRecord>.unmodifiable(_records.take(count));

  /// Favourites, most recently favourited first.
  List<ScanRecord> get favourites {
    final List<ScanRecord> list = _records.where((ScanRecord r) => r.isFavourite).toList()
      ..sort((ScanRecord a, ScanRecord b) =>
          (b.favouritedAt ?? b.scannedAt).compareTo(a.favouritedAt ?? a.scannedAt));

    return List<ScanRecord>.unmodifiable(list);
  }

  ScanRecord? byId(String id) {
    for (final ScanRecord r in _records) {
      if (r.id == id) return r;
    }

    return null;
  }

  // =====================================================
  // LOAD (per signed-in user) + CLEAN-UP
  // =====================================================

  static String _currentUserId() {
    try {
      if (Firebase.apps.isNotEmpty) {
        return FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      }
    } catch (_) {
      // Firebase not available: local guest history.
    }

    return 'guest';
  }

  ScanHistoryRepository _repositoryFor(String userId) =>
      LocalScanHistoryRepository(userId: userId);

  /// Loads the signed-in user's history (again if the user
  /// changed) and removes expired scans.
  Future<void> load() async {
    if (!_injected) {
      final String user = _currentUserId();

      if (_repository == null || user != _loadedFor) {
        _repository = _repositoryFor(user);
        _loadedFor = user;
      }
    }

    final List<ScanRecord> stored = await _repository!.loadAll();

    _records = policy.apply(stored, now);
    _loaded = true;

    if (_records.length != stored.length) {
      await _deleteThumbnails(stored.where((ScanRecord r) => !_records.contains(r)));
      await _repository!.saveAll(_records);
    }

    notifyListeners();
  }

  Future<void> _ensureLoaded() async {
    if (!_loaded) await load();
  }

  /// Removes expired non-favourite scans now.
  Future<void> cleanUpExpired() async {
    await _ensureLoaded();

    final List<ScanRecord> kept = policy.apply(_records, now);

    if (kept.length == _records.length) return;

    final List<ScanRecord> removed =
        _records.where((ScanRecord r) => !kept.contains(r)).toList();

    _records = kept;

    await _deleteThumbnails(removed);
    await _save();
  }

  // =====================================================
  // RECORD A SCAN
  // =====================================================

  /// Saves a finished analysis to history and returns the
  /// record. Scanning a product that is already in history
  /// (same barcode or same label values) updates it and
  /// keeps its favourite state.
  Future<ScanRecord> recordScan({
    required NutritionLabelData label,
    required String productName,
    String? imagePath,
  }) async {
    await _ensureLoaded();

    final String key = ScanRecord.productKeyFor(label);
    final DateTime time = now;
    final _Summary summary = _summaryFor(label);

    final int existing = _records.indexWhere((ScanRecord r) => r.productKey == key);

    ScanRecord record;

    if (existing >= 0) {
      final ScanRecord old = _records.removeAt(existing);

      record = old.copyWith(
        productName: productName == 'Scanned product' ? old.productName : productName,
        scannedAt: time,
        label: _stripRaw(label),
        summaryBasis: summary.basis,
        energyKcal: summary.energy,
        sugarsG: summary.sugars,
        sodiumMg: summary.sodium,
      );
    } else {
      record = ScanRecord(
        id: '${time.microsecondsSinceEpoch.toRadixString(36)}-${key.hashCode.toUnsigned(20).toRadixString(36)}',
        productKey: key,
        productName: productName,
        scannedAt: time,
        label: _stripRaw(label),
        summaryBasis: summary.basis,
        energyKcal: summary.energy,
        sugarsG: summary.sugars,
        sodiumMg: summary.sodium,
      );
    }

    if (imagePath != null) {
      final String? thumb = await _copyThumbnail(imagePath, record.id);

      if (thumb != null) record = record.copyWith(thumbnailPath: thumb);
    }

    _records.insert(0, record);
    _records = policy.apply(_records, time);

    await _save();

    return record;
  }

  /// After the user renames the product or edits values on
  /// the result screen.
  Future<ScanRecord?> updateScan(
    String id, {
    String? productName,
    NutritionLabelData? label,
  }) async {
    await _ensureLoaded();

    final int i = _records.indexWhere((ScanRecord r) => r.id == id);

    if (i < 0) return null;

    final _Summary? summary = label == null ? null : _summaryFor(label);

    final ScanRecord updated = _records[i].copyWith(
      productName: productName,
      label: label == null ? null : _stripRaw(label),
      summaryBasis: summary?.basis,
      energyKcal: summary?.energy,
      sugarsG: summary?.sugars,
      sodiumMg: summary?.sodium,
    );

    _records[i] = updated;

    await _save();

    return updated;
  }

  // =====================================================
  // FAVOURITES
  // =====================================================

  Future<ScanRecord?> setFavourite(String id, bool favourite) async {
    await _ensureLoaded();

    final int i = _records.indexWhere((ScanRecord r) => r.id == id);

    if (i < 0) return null;

    final ScanRecord r = _records[i];

    if (r.isFavourite == favourite) return r;

    _records[i] = favourite
        ? r.copyWith(isFavourite: true, favouritedAt: now)
        : r.copyWith(isFavourite: false, clearFavouritedAt: true);

    // Un-favouriting an old scan lets the 90-day rule
    // apply again straight away.
    if (!favourite) {
      final List<ScanRecord> kept = policy.apply(_records, now);

      if (kept.length != _records.length) {
        await _deleteThumbnails(_records.where((ScanRecord x) => !kept.contains(x)));
        _records = kept;
      }
    }

    await _save();

    return byId(id);
  }

  Future<ScanRecord?> toggleFavourite(String id) async {
    final ScanRecord? r = byId(id);

    if (r == null) return null;

    return setFavourite(id, !r.isFavourite);
  }

  /// Removes a scan from history. Favourites are protected:
  /// the user must remove them from Favourites first.
  Future<bool> deleteScan(String id) async {
    await _ensureLoaded();

    final int i = _records.indexWhere((ScanRecord r) => r.id == id);

    if (i < 0 || _records[i].isFavourite) return false;

    final ScanRecord removed = _records.removeAt(i);

    // Notify first: a swiped (Dismissible) card must leave
    // the list in the same frame.
    await _save();
    await _deleteThumbnails(<ScanRecord>[removed]);

    return true;
  }

  /// Puts back a record (undo after a removal).
  Future<void> restore(ScanRecord record) async {
    await _ensureLoaded();

    _records.removeWhere((ScanRecord r) => r.id == record.id);
    _records.add(record);
    _records = policy.apply(_records, now);

    await _save();
  }

  // =====================================================
  // ACCOUNT DELETION
  // =====================================================

  /// Removes every saved scan and favourite of [userId]
  /// from this phone, photos included. Called after the
  /// account has been deleted.
  Future<void> deleteAllForUser(String userId) async {
    final ScanHistoryRepository repository =
        _injected ? _repository! : _repositoryFor(userId);

    final List<ScanRecord> stored = await repository.loadAll();

    await _deleteThumbnails(stored);
    await repository.clear();

    if (_injected || _loadedFor == userId) {
      _records = <ScanRecord>[];
      _loaded = false;
      _loadedFor = null;

      if (!_injected) _repository = null;

      notifyListeners();
    }
  }

  // =====================================================
  // HELPERS
  // =====================================================

  Future<void> _save() async {
    notifyListeners();

    await _repository?.saveAll(_records);
  }

  static NutritionLabelData _stripRaw(NutritionLabelData d) =>
      d.rawText.isEmpty ? d : d.copyWith(rawText: '');

  static _Summary _summaryFor(NutritionLabelData label) {
    final NutritionAnalysis a = NutritionAnalysisService.analyse(
      data: label,
      profile: const NutritionProfile(),
    );

    final String basis = a.portion.servings != null
        ? (a.portion.servings == 1 ? 'per serving' : 'per portion')
        : a.per100Label;

    return _Summary(
      basis: basis,
      energy: a.nutrients['Energy']?.amount,
      sugars: a.nutrients['Total Sugars']?.amount,
      sodium: a.nutrients['Sodium']?.amount,
    );
  }

  Future<String?> _copyThumbnail(String imagePath, String id) async {
    if (!storeThumbnails) return null;

    try {
      final File source = File(imagePath);

      if (!await source.exists()) return null;

      final Directory docs = await getApplicationDocumentsDirectory();
      final Directory folder = Directory('${docs.path}${Platform.pathSeparator}scan_thumbnails');

      if (!await folder.exists()) await folder.create(recursive: true);

      final String target = '${folder.path}${Platform.pathSeparator}$id.jpg';

      await source.copy(target);

      return target;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteThumbnails(Iterable<ScanRecord> records) async {
    if (!storeThumbnails) return;

    for (final ScanRecord r in records.toList()) {
      final String? path = r.thumbnailPath;

      if (path == null) continue;

      try {
        final File f = File(path);

        if (await f.exists()) await f.delete();
      } catch (_) {
        // Not important: the file is only a thumbnail.
      }
    }
  }
}

class _Summary {
  final String basis;
  final double? energy;
  final double? sugars;
  final double? sodium;

  const _Summary({
    required this.basis,
    required this.energy,
    required this.sugars,
    required this.sodium,
  });
}
