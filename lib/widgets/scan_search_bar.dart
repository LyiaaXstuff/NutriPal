import 'package:flutter/material.dart';

import '../services/scan_filter.dart';

// =======================================================
// SEARCH BOX + FILTER CHIPS (Favourites, Scan History)
// =======================================================

/// [T] is the filter type: [ScanKind] (Favourites) or
/// [ScanPeriod] (Scan History).
class ScanSearchBar<T> extends StatelessWidget {
  final TextEditingController controller;
  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final IconData? Function(T) iconOf;
  final ValueChanged<T> onSelected;
  final ValueChanged<String> onQueryChanged;

  const ScanSearchBar({
    super.key,
    required this.controller,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.iconOf,
    required this.onSelected,
    required this.onQueryChanged,
  });

  /// Favourites: All · Label scans · Barcode scans.
  static IconData? kindIcon(ScanKind k) => switch (k) {
        ScanKind.all => null,
        ScanKind.label => Icons.document_scanner_outlined,
        ScanKind.barcode => Icons.qr_code_2_rounded,
      };

  /// Scan History: All · Today · 7 days · 30 days · Favourites.
  static IconData? periodIcon(ScanPeriod p) => switch (p) {
        ScanPeriod.all => null,
        ScanPeriod.today => Icons.today_rounded,
        ScanPeriod.week => Icons.date_range_rounded,
        ScanPeriod.month => Icons.calendar_month_rounded,
        ScanPeriod.favourites => Icons.favorite_border_rounded,
      };

  static const Color _purple = Color(0xFF4B2E83);
  static const Color _ink = Color(0xFF38138C);
  static const Color _muted = Color(0xFF67558E);
  static const Color _lilac = Color(0xFFF3ECFF);
  static const Color _border = Color(0xFFDCCFF0);
  static const Color _teal = Color(0xFF17B6B1);
  static const Color _tealBg = Color(0xFFE3F7F6);
  static const Color _tealInk = Color(0xFF0B4F4C);

  Widget _chip(T option) {
    final bool on = option == selected;
    final IconData? icon = iconOf(option);
    final Color ink = on ? _tealInk : _purple;

    return ChoiceChip(
      label: Text(labelOf(option)),
      selected: on,
      onSelected: (_) => onSelected(option),
      showCheckmark: false,
      avatar: icon == null ? null : Icon(icon, size: 16, color: ink),
      labelStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
      backgroundColor: _lilac,
      selectedColor: _tealBg,
      side: BorderSide(color: on ? _teal : Colors.transparent, width: 1.5),
      shape: const StadiumBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- search box ---------------------------------
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (BuildContext context, TextEditingValue value, Widget? child) {
            return TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search by product name',
                hintStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w400),
                prefixIcon: const Icon(Icons.search_rounded, color: _purple),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded, color: _muted),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      ),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: _border, width: 1.4),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  borderSide: BorderSide(color: _purple, width: 1.8),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),

        // ---- filter chips -------------------------------
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _chip(options[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown when the search or filter leaves nothing.
class ScanNoMatches extends StatelessWidget {
  final VoidCallback onClear;

  const ScanNoMatches({super.key, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF67558E)),
          const SizedBox(height: 10),
          const Text(
            'No matching products',
            style: TextStyle(color: Color(0xFF38138C), fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onClear,
            child: const Text('Clear search and filters'),
          ),
        ],
      ),
    );
  }
}
