import 'dart:io';

import 'package:flutter/material.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              _Thumbnail(record: record),
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
                    Text(
                      formatDate(record.scannedAt),
                      style: const TextStyle(color: _muted, fontSize: 13.5),
                    ),
                    if (record.servingText != null && showSummary) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.servingText!,
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
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final ScanRecord record;

  const _Thumbnail({required this.record});

  @override
  Widget build(BuildContext context) {
    final String? path = record.thumbnailPath;

    final Widget fallback = Icon(
      record.isBarcodeScan ? Icons.qr_code_2_rounded : Icons.inventory_2_rounded,
      color: ScanRecordCard._purple,
      size: 30,
    );

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: ScanRecordCard._lilac,
        borderRadius: BorderRadius.circular(13),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? fallback
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 160,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
            ),
    );
  }
}
