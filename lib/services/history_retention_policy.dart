// =======================================================
// HISTORY RETENTION POLICY
// =======================================================
//
//   History    = temporary: a scan is kept for 90 days
//                from its latest scannedAt.
//   Favourites = persistent: never removed automatically,
//                only when the user un-favourites them
//                (the 90 days then count from scannedAt).
//
// Pure rules, unit tested. The same rule is meant for the
// future backend clean-up (see ScanHistoryRepository).
// =======================================================

import '../models/scan_record.dart';

class HistoryRetentionPolicy {
  const HistoryRetentionPolicy({
    this.retention = const Duration(days: 90),
    this.maxHistoryRecords = 200,
  });

  final Duration retention;

  // Extra cap on non-favourite records, so local storage
  // stays small for heavy users (oldest go first).
  final int maxHistoryRecords;

  int get retentionDays => retention.inDays;

  bool isExpired(ScanRecord record, DateTime now) {
    if (record.isFavourite) return false;

    return now.difference(record.scannedAt) > retention;
  }

  /// When a non-favourite record will be removed.
  DateTime? expiresAt(ScanRecord record) =>
      record.isFavourite ? null : record.scannedAt.add(retention);

  /// Whole days left before removal (0 = goes today).
  int? daysLeft(ScanRecord record, DateTime now) {
    final DateTime? end = expiresAt(record);

    if (end == null) return null;

    final int hours = end.difference(now).inHours;

    return hours <= 0 ? 0 : (hours / 24).ceil();
  }

  /// Records to keep, newest first: favourites always, and
  /// non-favourites that are not expired (up to the cap).
  List<ScanRecord> apply(List<ScanRecord> records, DateTime now) {
    final List<ScanRecord> sorted = <ScanRecord>[...records]
      ..sort((ScanRecord a, ScanRecord b) => b.scannedAt.compareTo(a.scannedAt));

    final List<ScanRecord> kept = <ScanRecord>[];

    int history = 0;

    for (final ScanRecord r in sorted) {
      if (r.isFavourite) {
        kept.add(r);
        continue;
      }

      if (isExpired(r, now)) continue;

      if (history >= maxHistoryRecords) continue;

      history++;
      kept.add(r);
    }

    return kept;
  }
}
