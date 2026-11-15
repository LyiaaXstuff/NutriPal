import 'dart:io';

import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../models/scan_record.dart';
import '../services/compare_service.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/scan_history_service.dart';
import '../widgets/nutripal_ui.dart';
import '../widgets/scan_record_card.dart';
import 'saved_scan_navigation.dart';
import 'scan_flow.dart';
import 'scan_screen.dart';

// =======================================================
// COMPARE (bottom-navigation tab)
// =======================================================
//
// The user picks two products (from Scan history or
// Favourites, or by scanning a new one) and sees:
//
//   1. Which one fits their health goals better, and why.
//   2. One line per health area (decided by that area's
//      nutrients, rules document order).
//   3. Every comparable nutrient side by side, with the
//      same colours as "Your nutrition insights".
//
// Values come from the labels the user confirmed when
// scanning (CompareService -> NutritionAnalysisService);
// this screen only shows them. All rules are in
// CompareService.
//
// Only two foods (per 100 g) or two drinks (per 100 ml)
// can be compared, so products of the other type are
// greyed out once one product is chosen, and a new scan of
// the other type is refused.
//
// The two chosen products are remembered while the app is
// open, so switching tabs does not lose them.
// =======================================================

class CompareScreen extends StatefulWidget {
  final ProfileSetupData profile;

  // Opens the scanner from the Home shell. Compare itself
  // scans for product A or B through the product picker.
  final VoidCallback onScanTap;

  const CompareScreen({
    super.key,
    required this.profile,
    required this.onScanTap,
  });

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  static const Color _background = Color(0xFFF7F2E9);
  static const Color _ink = Color(0xFF38138C);
  static const Color _muted = Color(0xFF67558E);
  static const Color _purple = Color(0xFF4B2E83);

  // Kept while the app is open (tabs are rebuilt when
  // switching). Ids of records in ScanHistoryService.
  static String? _keptFirstId;
  static String? _keptSecondId;
  static CompareBasis? _keptBasis;

  final ScanHistoryService _history = ScanHistoryService.instance;

  @override
  void initState() {
    super.initState();

    // Loads saved scans if needed and drops expired ones.
    _history.cleanUpExpired();
  }

  // =====================================================
  // SELECTION
  // =====================================================

  ScanRecord? get _first => _keptFirstId == null ? null : _history.byId(_keptFirstId!);

  ScanRecord? get _second => _keptSecondId == null ? null : _history.byId(_keptSecondId!);

  static ProductForm _formOf(ScanRecord r) => NutritionAnalysisService.formOf(r.label);

  Future<void> _pick({required bool first}) async {
    final ScanRecord? other = first ? _second : _first;

    // A ScanRecord, or _scanNew when the user wants to scan.
    final Object? chosen = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _ProductPickerSheet(
        letter: first ? 'A' : 'B',
        records: _history.history,
        favourites: _history.favourites,
        disabledId: other?.id,
        otherLetter: first ? 'B' : 'A',
        requiredForm: other == null ? null : _formOf(other),
      ),
    );

    if (chosen == null || !mounted) return;

    if (chosen == _scanNew) {
      await _scanForCompare(first: first);
      return;
    }

    if (chosen is ScanRecord) _choose(first: first, record: chosen);
  }

  void _choose({required bool first, required ScanRecord record}) {
    if (first) {
      _keptFirstId = record.id;
    } else {
      _keptSecondId = record.id;
    }

    // New pair: start again from the fair default.
    _keptBasis = null;

    if (mounted) setState(() {});
  }

  // Opens the scanner for product A or B. The result
  // screen's "Use as product A/B" button calls _choose and
  // returns here.
  Future<void> _scanForCompare({required bool first}) async {
    final ScanRecord? other = first ? _second : _first;
    final Route<dynamic>? here = ModalRoute.of(context);

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ScanScreen(
          profile: widget.profile,
          flow: ScanFlowContext(
            profile: widget.profile,
            compareLetter: first ? 'A' : 'B',
            compareForm: other == null ? null : _formOf(other),
            compareRoute: here,
            onCompareResult: (ScanRecord record) => _choose(first: first, record: record),
          ),
        ),
      ),
    );
  }

  void _clear({required bool first}) {
    setState(() {
      if (first) {
        _keptFirstId = null;
      } else {
        _keptSecondId = null;
      }

      _keptBasis = null;
    });
  }

  void _swap() {
    setState(() {
      final String? a = _keptFirstId;
      _keptFirstId = _keptSecondId;
      _keptSecondId = a;
    });
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _history,
          builder: (BuildContext context, Widget? child) {
            final ScanRecord? a = _first;
            final ScanRecord? b = _second;

            return ListView(
              // Room for the floating navigation bar.
              padding: EdgeInsets.fromLTRB(
                22,
                22,
                22,
                30 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                const Text(
                  'Compare',
                  style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick two foods or two drinks to see which fits your health goals better.',
                  style: TextStyle(color: _muted, fontSize: 14.5, height: 1.35),
                ),
                const SizedBox(height: 18),
                if (!_history.isLoaded)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator(color: _purple)),
                  )
                else ...[
                  _buildSlots(a, b),
                  const SizedBox(height: 18),
                  if (a != null && b != null)
                    ..._buildComparison(a, b)
                  else
                    const _HintCard(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlots(ScanRecord? a, ScanRecord? b) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ProductSlot(
                  letter: 'A',
                  record: a,
                  onTap: () => _pick(first: true),
                  onClear: a == null ? null : () => _clear(first: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ProductSlot(
                  letter: 'B',
                  record: b,
                  onTap: () => _pick(first: false),
                  onClear: b == null ? null : () => _clear(first: false),
                ),
              ),
            ],
          ),
        ),
        if (a != null && b != null)
          Material(
            color: Colors.white,
            shape: const CircleBorder(side: BorderSide(color: NpColors.softBorder)),
            elevation: 2,
            shadowColor: _purple.withValues(alpha: 0.2),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _swap,
              child: const Tooltip(
                message: 'Swap A and B',
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(Icons.swap_horiz_rounded, color: _purple, size: 20),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // =====================================================
  // COMPARISON
  // =====================================================

  List<Widget> _buildComparison(ScanRecord a, ScanRecord b) {
    // Same name (e.g. two "Scanned product"): use letters.
    final bool sameName =
        a.productName.trim().toLowerCase() == b.productName.trim().toLowerCase();

    final String nameA = sameName ? 'Product A' : a.productName.trim();
    final String nameB = sameName ? 'Product B' : b.productName.trim();

    final CompareBasis basis =
        _keptBasis ?? CompareService.defaultBasis(a.label, b.label);

    final ProductComparison c = CompareService.compare(
      first: a.label,
      second: b.label,
      profile: NutritionProfile.fromSetupData(widget.profile),
      basis: basis,
      firstName: nameA,
      secondName: nameB,
    );

    return [
      SegmentedButton<CompareBasis>(
        showSelectedIcon: false,
        segments: const <ButtonSegment<CompareBasis>>[
          ButtonSegment<CompareBasis>(
            value: CompareBasis.per100,
            label: Text('Per 100 g / ml'),
          ),
          ButtonSegment<CompareBasis>(
            value: CompareBasis.perServing,
            label: Text('Per serving'),
          ),
        ],
        selected: <CompareBasis>{basis},
        onSelectionChanged: (Set<CompareBasis> s) => setState(() => _keptBasis = s.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          selectedBackgroundColor: NpColors.selectedBg,
          selectedForegroundColor: NpColors.selectedInk,
          foregroundColor: _purple,
          side: const BorderSide(color: NpColors.softBorder),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        basis == CompareBasis.per100
            ? 'Compares the products themselves, gram for gram.'
            : 'Compares one serving of each, as printed on the labels.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _muted, fontSize: 12.5),
      ),
      const SizedBox(height: 16),
      _VerdictCard(comparison: c),
      for (final String note in c.notes) ...[
        const SizedBox(height: 10),
        _NoteCard(text: note),
      ],
      const SizedBox(height: 22),
      const _SectionTitle('Your health areas'),
      const SizedBox(height: 10),
      for (final AreaComparison area in c.areas) ...[
        _AreaCard(area: area),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 12),
      const _SectionTitle('Nutrients side by side'),
      const SizedBox(height: 10),
      _NutrientTable(comparison: c),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _DetailsButton(
              label: 'A details',
              onPressed: () => openSavedScan(context, record: a, profile: widget.profile),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DetailsButton(
              label: 'B details',
              onPressed: () => openSavedScan(context, record: b, profile: widget.profile),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      const Text(
        npDisclaimer,
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
      ),
    ];
  }
}

// =======================================================
// SMALL PIECES
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF38138C), fontSize: 19, fontWeight: FontWeight.w900),
    );
  }
}

/// Round "A" / "B" badge.
class _LetterBadge extends StatelessWidget {
  final String letter;
  final double size;

  const _LetterBadge(this.letter, {this.size = 26});

  @override
  Widget build(BuildContext context) {
    final bool isA = letter == 'A';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isA ? NpColors.purple : NpColors.teal,
        shape: BoxShape.circle,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// =======================================================
// PRODUCT SLOT (A or B)
// =======================================================

class _ProductSlot extends StatelessWidget {
  final String letter;
  final ScanRecord? record;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _ProductSlot({
    required this.letter,
    required this.record,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final ScanRecord? r = record;

    return Material(
      color: r == null ? NpColors.lilac : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: r == null ? NpColors.softBorder : const Color(0xFFDCCFF0),
          width: r == null ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LetterBadge(letter),
                  const Spacer(),
                  if (onClear != null)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: IconButton(
                        tooltip: 'Remove product $letter',
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        onPressed: onClear,
                        icon: const Icon(Icons.close_rounded, color: NpColors.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (r == null) ...[
                const Icon(Icons.add_circle_outline_rounded, color: NpColors.purple, size: 30),
                const SizedBox(height: 8),
                const Text(
                  'Choose product',
                  style: TextStyle(
                    color: NpColors.purple,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'From your scans',
                  style: TextStyle(color: NpColors.muted, fontSize: 12.5),
                ),
              ] else ...[
                _SlotThumbnail(record: r),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    r.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF38138C),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                ),
                if (r.servingText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    r.servingText!,
                    style: const TextStyle(color: NpColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Tap to change',
                  style: TextStyle(
                    color: NpColors.link,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotThumbnail extends StatelessWidget {
  final ScanRecord record;

  const _SlotThumbnail({required this.record});

  @override
  Widget build(BuildContext context) {
    final String? path = record.thumbnailPath;

    final Widget fallback = Icon(
      record.isBarcodeScan ? Icons.qr_code_2_rounded : Icons.inventory_2_rounded,
      color: NpColors.purple,
      size: 26,
    );

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECFF),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: path == null
          ? fallback
          : Image.file(
              File(path),
              fit: BoxFit.cover,
              cacheWidth: 140,
              errorBuilder: (BuildContext context, Object error, StackTrace? stack) => fallback,
            ),
    );
  }
}

// =======================================================
// VERDICT
// =======================================================

class _VerdictCard extends StatelessWidget {
  final ProductComparison comparison;

  const _VerdictCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final ProductComparison c = comparison;

    final (String heading, String? winner, IconData icon) = switch (c.overall) {
      CompareResult.first => ('Better fit for you', 'A', Icons.emoji_events_rounded),
      CompareResult.second => ('Better fit for you', 'B', Icons.emoji_events_rounded),
      CompareResult.mixed => ('It depends on your priority', null, Icons.balance_rounded),
      CompareResult.same => ('About the same for you', null, Icons.drag_handle_rounded),
      CompareResult.unknown => ('Not enough information', null, Icons.help_outline_rounded),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38138C), Color(0xFF4B2E83), Color(0xFF7050B6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4B2E83).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFFC20B), size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  heading,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (winner != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: _LetterBadge(winner, size: 30),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    c.nameOf(c.overall),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            c.summary,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final String text;

  const _NoteCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: NpColors.warnBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: NpColors.warnInk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: NpColors.warnInk, fontSize: 13.5, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// HEALTH AREA
// =======================================================

class _AreaCard extends StatelessWidget {
  final AreaComparison area;

  const _AreaCard({required this.area});

  @override
  Widget build(BuildContext context) {
    final Widget chip = switch (area.result) {
      CompareResult.first => const _ResultChip(letter: 'A', text: 'better'),
      CompareResult.second => const _ResultChip(letter: 'B', text: 'better'),
      CompareResult.same => const NpPill(
          text: 'Similar',
          background: NpColors.lilac,
          ink: NpColors.purple,
        ),
      _ => NpPill.level(null),
    };

    return NpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.area.title,
                      style: const TextStyle(
                        color: NpColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      area.area.focus,
                      style: const TextStyle(color: NpColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              chip,
            ],
          ),
          const SizedBox(height: 10),
          Text(
            area.reason,
            style: const TextStyle(color: NpColors.bodyInk, fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String letter;
  final String text;

  const _ResultChip({required this.letter, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 11, 4),
      decoration: BoxDecoration(
        color: NpColors.okBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LetterBadge(letter, size: 20),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: NpColors.okInk,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// NUTRIENT TABLE
// =======================================================

class _NutrientTable extends StatelessWidget {
  final ProductComparison comparison;

  const _NutrientTable({required this.comparison});

  static String _basisText(ProductComparison c, NutritionAnalysis a) {
    final String unit = a.form == ProductForm.drink ? 'ml' : 'g';

    if (c.basis == CompareBasis.per100) return 'per 100 $unit';

    if (a.portion.servings == null) {
      return 'per 100 ${a.portionUnit ?? unit}';
    }

    final double? amount = a.portionAmount;

    if (amount == null) return '1 serving';

    return '1 serving · ${NutritionAnalysisService.formatAmount(amount, 'g')} '
        '${a.portionUnit ?? unit}';
  }

  @override
  Widget build(BuildContext context) {
    final ProductComparison c = comparison;

    if (c.nutrients.isEmpty) {
      return const NpCard(
        child: Text(
          'These labels have no nutrients NutriPal can compare.',
          style: TextStyle(color: NpColors.muted, fontSize: 14),
        ),
      );
    }

    return NpCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        children: [
          // ---- header ----------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                flex: 4,
                child: Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Nutrient',
                    style: TextStyle(
                      color: NpColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _ColumnHead(letter: 'A', basis: _basisText(c, c.firstAnalysis)),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _ColumnHead(letter: 'B', basis: _basisText(c, c.secondAnalysis)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: NpColors.cardBorder),

          // ---- rows ------------------------------------
          for (final ComparedNutrient n in c.nutrients) _NutrientRow(nutrient: n),

          // ---- legend ----------------------------------
          const SizedBox(height: 8),
          const Row(
            children: [
              _Dot(),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Matters for your health areas',
                  style: TextStyle(color: NpColors.muted, fontSize: 12),
                ),
              ),
              Icon(Icons.check_circle_rounded, color: NpColors.teal, size: 15),
              SizedBox(width: 4),
              Text(
                'Better choice',
                style: TextStyle(color: NpColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              c.basis == CompareBasis.per100
                  ? 'Colours: low, moderate or high per 100.'
                  : 'Colours: level for one serving, as on Your nutrition insights.',
              style: const TextStyle(color: NpColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _ColumnHead extends StatelessWidget {
  final String letter;
  final String basis;

  const _ColumnHead({required this.letter, required this.basis});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LetterBadge(letter, size: 24),
        const SizedBox(height: 4),
        Text(
          basis,
          textAlign: TextAlign.center,
          style: const TextStyle(color: NpColors.muted, fontSize: 11, height: 1.2),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(color: NpColors.teal, shape: BoxShape.circle),
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final ComparedNutrient nutrient;

  const _NutrientRow({required this.nutrient});

  @override
  Widget build(BuildContext context) {
    final ComparedNutrient n = nutrient;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: NpColors.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      CompareService.displayName(n.name),
                      style: TextStyle(
                        color: NpColors.ink,
                        fontSize: 14,
                        fontWeight: n.mattersForUser ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (n.mattersForUser) ...[
                    const SizedBox(width: 6),
                    const _Dot(),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _ValueCell(
              value: n.first,
              unit: n.unit,
              level: n.firstLevel,
              isBetter: n.result == CompareResult.first,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: _ValueCell(
              value: n.second,
              unit: n.unit,
              level: n.secondLevel,
              isBetter: n.result == CompareResult.second,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCell extends StatelessWidget {
  final double? value;
  final String unit;
  final NutrientLevel? level;
  final bool isBetter;

  const _ValueCell({
    required this.value,
    required this.unit,
    required this.level,
    required this.isBetter,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null) {
      return const Tooltip(
        message: 'Not on the label',
        child: Text(
          '–',
          textAlign: TextAlign.center,
          style: TextStyle(color: NpColors.muted, fontSize: 15, fontWeight: FontWeight.w700),
        ),
      );
    }

    final LevelStyle style = LevelStyle.of(level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: level == null ? Colors.transparent : style.background,
        borderRadius: BorderRadius.circular(10),
        border: isBetter ? Border.all(color: NpColors.teal, width: 1.6) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              '${NutritionAnalysisService.formatAmount(value!, unit)} $unit',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: level == null ? NpColors.ink : style.ink,
                fontSize: 13.5,
                fontWeight: isBetter ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          if (isBetter) ...[
            const SizedBox(width: 3),
            const Icon(Icons.check_circle_rounded, color: NpColors.teal, size: 14),
          ],
        ],
      ),
    );
  }
}

class _DetailsButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DetailsButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: NpColors.purple,
          side: const BorderSide(color: NpColors.purple, width: 1.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// =======================================================
// EMPTY STATE
// =======================================================

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return const NpCard(
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, color: NpColors.purple, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose product A and B from your scan history or favourites, or scan '
              'a new product. Compare two foods or two drinks. NutriPal then shows '
              'which one suits your health areas better, and why.',
              style: TextStyle(color: NpColors.bodyInk, fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// =======================================================
// PRODUCT PICKER (bottom sheet)
// =======================================================

class _ProductPickerSheet extends StatefulWidget {
  final String letter;

  // All saved scans, newest first.
  final List<ScanRecord> records;

  // Favourites, most recently favourited first.
  final List<ScanRecord> favourites;

  // The product already chosen for the other slot.
  final String? disabledId;
  final String otherLetter;

  // Food or drink of the other chosen product; products of
  // the other type cannot be picked. Null = any.
  final ProductForm? requiredForm;

  const _ProductPickerSheet({
    required this.letter,
    required this.records,
    required this.favourites,
    required this.disabledId,
    required this.otherLetter,
    required this.requiredForm,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final TextEditingController _search = TextEditingController();

  String _query = '';

  // Which list to choose from: favourites or the whole scan
  // history.
  bool _showFavourites = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(ScanRecord r) =>
      _query.isEmpty || r.productName.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final List<ScanRecord> source = _showFavourites ? widget.favourites : widget.records;
    final List<ScanRecord> shown = source.where(_matches).toList();

    final String emptyText = source.isEmpty
        ? (_showFavourites
            ? 'No favourites yet. Tap the heart on a product to save it here.'
            : 'No scans in the last 30 days.')
        : 'No ${_showFavourites ? 'favourites' : 'scans'} match your search.';

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F2E9),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4D9F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _LetterBadge(widget.letter, size: 30),
                  const SizedBox(width: 10),
                  Text(
                    'Choose product ${widget.letter}',
                    style: const TextStyle(
                      color: Color(0xFF38138C),
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (widget.requiredForm != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Product ${widget.otherLetter} is a '
                  '${widget.requiredForm == ProductForm.drink ? 'drink' : 'food'}, '
                  'so choose another '
                  '${widget.requiredForm == ProductForm.drink ? 'drink' : 'food'}.',
                  style: const TextStyle(color: NpColors.muted, fontSize: 13.5, height: 1.35),
                ),
              ],
              const SizedBox(height: 14),
              _ScanNewButton(
                onTap: () => Navigator.pop<Object>(context, _scanNew),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PickerFilterChip(
                      label: 'Scan history',
                      icon: Icons.history_rounded,
                      count: widget.records.length,
                      selected: !_showFavourites,
                      onTap: () => setState(() => _showFavourites = false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickerFilterChip(
                      label: 'Favourites',
                      icon: Icons.favorite_rounded,
                      count: widget.favourites.length,
                      selected: _showFavourites,
                      onTap: () => setState(() => _showFavourites = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (String v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: _showFavourites ? 'Search your favourites' : 'Search your scans',
                  prefixIcon: const Icon(Icons.search_rounded, color: NpColors.purple),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: NpColors.softBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: NpColors.softBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: NpColors.purple, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Text(
                    emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: NpColors.muted, fontSize: 14, height: 1.4),
                  ),
                ),
              for (final ScanRecord r in shown) _pickerTile(r),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerTile(ScanRecord r) {
    final bool taken = r.id == widget.disabledId;
    final ProductForm? need = widget.requiredForm;
    final bool otherType =
        !taken && need != null && NutritionAnalysisService.formOf(r.label) != need;
    final bool blocked = taken || otherType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: blocked ? 0.45 : 1,
        child: ScanRecordCard(
          record: r,
          showSummary: true,
          note: taken
              ? 'Already chosen as ${widget.otherLetter}'
              : otherType
                  ? (need == ProductForm.drink
                      ? 'Food - compare with another food'
                      : 'Drink - compare with another drink')
                  : null,
          onTap: blocked ? null : () => Navigator.pop<Object>(context, r),
        ),
      ),
    );
  }
}

// Returned by the picker when the user taps "Scan a new
// product".
const Object _scanNew = 'scan-new-product';

class _ScanNewButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanNewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NpColors.purple,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.document_scanner_outlined, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan a new product',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Nutrition label or barcode',
                      style: TextStyle(color: Color(0xFFE4D9F7), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PickerFilterChip({
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = selected ? Colors.white : NpColors.purple;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? NpColors.purple : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? NpColors.purple : NpColors.softBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: fg, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$label ($count)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w800),
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
