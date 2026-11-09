import 'dart:io';

import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/scan_record.dart';
import '../services/nutrition_analysis_service.dart';

// =======================================================
// SCAN RECORD CARD
// =======================================================
//
// One card for Recent scans (Home), History and
// Favourites, so the three lists look like one family but
// each screen decides what extra line to show.
// =======================================================

class ScanRecordCard extends StatelessWidget {
  final ScanRecord record;

  final VoidCallback? onTap;

  // Heart button; hidden when null.
  final VoidCallback? onFavouriteTap;

  // Extra line under the date ("Kept for 12 more days").
  final String? note;

  // Key nutrients line ("92 kcal · 1.7 g sugar · 40 mg
  // sodium per serving").
  final bool showSummary;

  const ScanRecordCard({
    super.key,
    required this.record,
    this.onTap,
    this.onFavouriteTap,
    this.note,
    this.showSummary = false,
  });

  static const Color _ink = Color(0xFF38138C);
  static const Color _muted = Color(0xFF67558E);
  static const Color _purple = Color(0xFF4B2E83);
  static const Color _border = Color(0xFFDCCFF0);
  static const Color _lilac = Color(0xFFF3ECFF);
  static const Color _heart = Color(0xFFD2453B);

  /// "236 ml (1 cup) per serving", "30 g (3 biscuits) per
  /// serving"; the everyday measure only when the label
  /// prints one. Null when the label has no serving size.
  static String? servingLine(ScanRecord record) {
    final String? base = record.servingText;

    if (base == null) return null;

    final HouseholdMeasure? m = NutritionAnalysisService.householdMeasure(record.label);

    if (m == null) return base;

    return base.replaceFirst(' per serving', ' (${m.label(m.perServing)}) per serving');
  }

  /// Shorter, for the small Home cards: "236 ml (1 cup)".
  static String? servingShort(ScanRecord record) =>
      servingLine(record)?.replaceFirst(' per serving', '');

  static String formatDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final int hour = date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final String minute = date.minute.toString().padLeft(2, '0');
    final String period = date.hour >= 12 ? 'PM' : 'AM';

    return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $period';
  }

  /// "9 Nov, 12:38 AM": the year only when it is not this year.
  static String formatShortDate(DateTime date, {DateTime? now}) {
    final String full = formatDate(date);
    final int year = (now ?? DateTime.now()).year;

    if (date.year != year) return full;

    return full.replaceFirst(' ${date.year},', ',');
  }

  String? get _summary {
    final List<String> parts = <String>[
      if (record.energyKcal != null)
        '${NutritionAnalysisService.formatAmount(record.energyKcal!, 'kcal')} kcal',
      if (record.sugarsG != null)
        '${NutritionAnalysisService.formatAmount(record.sugarsG!, 'g')} g sugar',
      if (record.sodiumMg != null)
        '${NutritionAnalysisService.formatAmount(record.sodiumMg!, 'mg')} mg sodium',
    ];

    if (parts.isEmpty) return null;

    return '${parts.join(' · ')} ${record.summaryBasis}';
  }

  @override
  Widget build(BuildContext context) {
    final String? summary = showSummary ? _summary : null;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // Same height for every card in Scan History and
        // Favourites (room for a 2-line name, the serving size
        // and the date), so the list looks even.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: showSummary ? 0 : 104),
          child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumbnail(record: record, width: 64, height: 64, radius: 14, iconSize: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Lists (History, Favourites): serving size,
                    // then the scan date and time.
                    if (!showSummary && ScanRecordCard.servingLine(record) != null) ...[
                      Text(
                        ScanRecordCard.servingLine(record)!,
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      formatDate(record.scannedAt),
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                    if (ScanRecordCard.servingLine(record) != null && showSummary) ...[
                      const SizedBox(height: 2),
                      Text(
                        ScanRecordCard.servingLine(record)!,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                    if (summary != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        summary,
                        style: const TextStyle(
                          color: _purple,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (note != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        note!,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (onFavouriteTap != null)
                IconButton(
                  tooltip: record.isFavourite ? 'Remove from favourites' : 'Add to favourites',
                  onPressed: onFavouriteTap,
                  icon: Icon(
                    record.isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: record.isFavourite ? _heart : _purple,
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: _purple),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ScanRecord record;
  final double? width;
  final double height;
  final double radius;
  final double iconSize;

  const _Thumbnail({
    required this.record,
    this.width = 54,
    this.height = 54,
    this.radius = 13,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    final String? path = record.thumbnailPath;

    final Widget fallback = Icon(
      record.isBarcodeScan ? Icons.qr_code_2_rounded : Icons.inventory_2_rounded,
      color: ScanRecordCard._purple,
      size: iconSize,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ScanRecordCard._lilac,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: path != null
          ? Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 320,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                  _database(fallback),
            )
          : _database(fallback),
    );
  }

  // Barcode scans without the user's own photo: the Open
  // Food Facts front photo, when the database has one.
  Widget _database(Widget fallback) {
    final String? url = record.label.productImageUrl;

    if (url == null) return fallback;

    return Image.network(
      url,
      fit: BoxFit.cover,
      cacheWidth: 320,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
    );
  }
}

// =======================================================
// SCAN RECORD TILE
// =======================================================
//
// Compact card for the Recent scans carousel on Home:
// photo on top, name and date below, heart on the photo.
// =======================================================

class ScanRecordTile extends StatelessWidget {
  final ScanRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onFavouriteTap;

  // Tile size; the Home carousel uses the same values.
  static const double width = 152;
  static const double height = 216;

  const ScanRecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.onFavouriteTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: ScanRecordCard._border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _Thumbnail(
                      record: record,
                      width: double.infinity,
                      height: 100,
                      radius: 12,
                      iconSize: 36,
                    ),
                    if (onFavouriteTap != null)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.white,
                          shape: const CircleBorder(),
                          elevation: 1,
                          shadowColor: const Color(0x334B2E83),
                          child: IconButton(
                            tooltip: record.isFavourite
                                ? 'Remove from favourites'
                                : 'Add to favourites',
                            onPressed: onFavouriteTap,
                            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                            padding: EdgeInsets.zero,
                            iconSize: 21,
                            icon: Icon(
                              record.isFavourite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: record.isFavourite
                                  ? ScanRecordCard._heart
                                  : ScanRecordCard._purple,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  record.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ScanRecordCard._ink,
                    fontSize: 15,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Serving size, then date and time.
                if (ScanRecordCard.servingShort(record) != null)
                  Text(
                    ScanRecordCard.servingShort(record)!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ScanRecordCard._purple,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(
                  ScanRecordCard.formatShortDate(record.scannedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ScanRecordCard._muted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
