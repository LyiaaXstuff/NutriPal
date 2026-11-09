import '../models/scan_record.dart';

// =======================================================
// SCAN LIST SEARCH AND FILTER
// =======================================================
//
// Used by Favourites and Scan History. Pure Dart, unit
// tested (test/scan_filter_test.dart).
// =======================================================

enum ScanKind { all, label, barcode }

extension ScanKindText on ScanKind {
  String get label => switch (this) {
        ScanKind.all => 'All',
        ScanKind.label => 'Label scans',
        ScanKind.barcode => 'Barcode scans',
      };
}

/// Scan History filters: by when it was scanned, or
/// favourites only.
enum ScanPeriod { all, today, week, month, favourites }

extension ScanPeriodText on ScanPeriod {
  String get label => switch (this) {
        ScanPeriod.all => 'All',
        ScanPeriod.today => 'Today',
        ScanPeriod.week => 'Last 7 days',
        ScanPeriod.month => 'Last 30 days',
        ScanPeriod.favourites => 'Favourites',
      };
}

class ScanFilter {
  ScanFilter._();

  /// Scans whose product name or brand contains [query]
  /// (any case, any order of words), of the chosen [kind].
  /// The original order (newest first) is kept.
  static List<ScanRecord> apply(
    List<ScanRecord> scans, {
    String query = '',
    ScanKind kind = ScanKind.all,
    ScanPeriod period = ScanPeriod.all,
    DateTime? now,
  }) {
    final DateTime today = _startOfDay(now ?? DateTime.now());

    final List<String> words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();

    return <ScanRecord>[
      for (final ScanRecord r in scans)
        if (_kindMatches(r, kind) && _periodMatches(r, period, today) && _textMatches(r, words))
          r,
    ];
  }

  static DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);

  /// Today = since midnight; 7 / 30 days = today and the
  /// days before it, by calendar day.
  static bool _periodMatches(ScanRecord r, ScanPeriod period, DateTime today) {
    final DateTime day = _startOfDay(r.scannedAt);

    return switch (period) {
      ScanPeriod.all => true,
      ScanPeriod.today => !day.isBefore(today),
      ScanPeriod.week => !day.isBefore(today.subtract(const Duration(days: 6))),
      ScanPeriod.month => !day.isBefore(today.subtract(const Duration(days: 29))),
      ScanPeriod.favourites => r.isFavourite,
    };
  }

  static bool _kindMatches(ScanRecord r, ScanKind kind) => switch (kind) {
        ScanKind.all => true,
        ScanKind.label => !r.isBarcodeScan,
        ScanKind.barcode => r.isBarcodeScan,
      };

  static bool _textMatches(ScanRecord r, List<String> words) {
    if (words.isEmpty) return true;

    final String text = '${r.productName} ${r.label.productBrand ?? ''}'.toLowerCase();

    return words.every(text.contains);
  }
}
