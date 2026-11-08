import 'dart:io';

import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../services/insight_text_service.dart';
import '../models/scan_record.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/scan_history_service.dart';
import '../widgets/nutripal_ui.dart';
import 'ask_nutripal_screen.dart';
import 'edit_nutrients_sheet.dart';
import 'extracted_nutrition_review_screen.dart';
import 'scan_flow.dart';

// =======================================================
// 4 · YOUR NUTRITION INSIGHTS
// =======================================================
//
// Personalised result for one product. The portion picker
// drives every number; "Edit" re-runs the analysis with
// corrected values. All levels come from
// NutritionAnalysisService (Layers 1-3); the AI only
// explains (Ask NutriPal).
//
// A fresh scan is saved to history (90 days) when this
// screen opens; the heart keeps it in Favourites. Saved
// scans reopen here too (savedRecordId) without being
// recorded again.
// =======================================================

class NutritionInsightsScreen extends StatefulWidget {
  final NutritionLabelData data;

  final String? imagePath;

  final ScanFlowContext flow;

  // Set when reopening a scan from Recent scans, History
  // or Favourites.
  final String? savedRecordId;

  final String? savedProductName;

  const NutritionInsightsScreen({
    super.key,
    required this.data,
    required this.flow,
    this.imagePath,
    this.savedRecordId,
    this.savedProductName,
  });

  @override
  State<NutritionInsightsScreen> createState() => _NutritionInsightsScreenState();
}

class _NutritionInsightsScreenState extends State<NutritionInsightsScreen> {
  late NutritionLabelData _data;
  late Portion _portion;
  late String _productName;

  final ScanHistoryService _history = ScanHistoryService.instance;

  // History record of this scan (null until saved).
  String? _recordId;

  bool get _isSavedScan => widget.savedRecordId != null;

  @override
  void initState() {
    super.initState();

    _data = widget.data;
    _portion = NutritionAnalysisService.defaultPortion(_data);
    _productName = widget.savedProductName ?? _initialName(_data);
    _recordId = widget.savedRecordId;

    if (_recordId == null) _recordScan();
  }

  Future<void> _recordScan() async {
    final ScanRecord record = await _history.recordScan(
      label: _data,
      productName: _productName,
      imagePath: widget.imagePath,
      // This name came from the barcode, the photo or the
      // default: a name saved earlier for the same product
      // (for example one the user typed) wins.
      keepExistingName: true,
    );

    if (!mounted) return;

    setState(() {
      _recordId = record.id;
      _productName = record.productName;
    });
  }

  static String _initialName(NutritionLabelData data) {
    final String name = data.productName?.trim() ?? '';
    final String brand = data.productBrand?.trim() ?? '';

    if (name.isEmpty) return 'Scanned product';
    if (brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase())) return name;

    return '$brand $name';
  }

  NutritionProfile get _profile => NutritionProfile.fromSetupData(widget.flow.profile);

  NutritionAnalysis get _analysis => NutritionAnalysisService.analyse(
        data: _data,
        profile: _profile,
        portion: _portion,
      );

  // =====================================================
  // TEXT HELPERS
  // =====================================================

  String _portionText(NutritionAnalysis a) {
    if (a.portionAmount != null && a.portionUnit != null) {
      return 'Your ${NutritionAnalysisService.formatAmount(a.portionAmount!, a.portionUnit!)} ${a.portionUnit}';
    }

    final double s = a.portionServings ?? 1;

    return s == 1 ? 'One serving' : '${NutritionAnalysisService.formatAmount(s, 'g')} servings';
  }

  String _portionNote(NutritionAnalysis a) {
    final double? s = a.portionServings;

    if (s == null) return '';

    final String n = NutritionAnalysisService.formatAmount(s, 'g');

    return '$n serving${n == '1' ? '' : 's'}';
  }

  String get _sourceLine {
    final String source = switch (_data.extractionMethod) {
      NutritionExtractionMethod.onDevice => 'Label scan',
      NutritionExtractionMethod.ai => 'Label scan (AI checked)',
      NutritionExtractionMethod.barcode => 'Barcode · Open Food Facts',
    };

    final List<String> parts = <String>[source];

    if (_data.servingSizeAmount != null && _data.servingSizeUnit != null) {
      parts.add(
        '${NutritionAnalysisService.formatAmount(_data.servingSizeAmount!, _data.servingSizeUnit!)} '
        '${_data.servingSizeUnit} per serving',
      );
    }

    if (_data.servingsPerPackage != null) {
      final String n = NutritionAnalysisService.formatAmount(_data.servingsPerPackage!, 'g');
      parts.add('$n serving${n == '1' ? '' : 's'}');
    }

    return parts.join(' · ');
  }

  // =====================================================
  // ACTIONS
  // =====================================================

  Future<void> _customPortion(NutritionAnalysis a) async {
    final String unit = a.portionUnit ??
        (a.form == ProductForm.drink ? 'ml' : 'g');

    final TextEditingController controller = TextEditingController();

    final double? amount = await showDialog<double>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('How much will you have?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: unit, hintText: 'Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NpColors.purple),
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('Use'),
          ),
        ],
      ),
    );

    // Not disposed here: the dialog is still fading out
    // and its text field keeps using the controller for a
    // few frames (disposing now crashes in debug). It holds
    // no listeners, so it is simply garbage collected.

    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _portion = Portion.amount(amount, unit));
  }

  Future<void> _rename() async {
    final TextEditingController controller = TextEditingController(
      text: _productName == 'Scanned product' ? '' : _productName,
    );

    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Product name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Homesoy Soya Bean Drink'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NpColors.purple),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // Not disposed here: the dialog is still fading out
    // and its text field keeps using the controller for a
    // few frames (disposing now crashes in debug). It holds
    // no listeners, so it is simply garbage collected.

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _productName = name);

    if (_recordId != null) _history.updateScan(_recordId!, productName: name);
  }

  Future<void> _edit() async {
    final NutritionLabelData? edited = await showEditNutrientsSheet(
      context,
      data: _data,
      productName: _productName,
    );

    if (edited == null || !mounted) return;

    if (_recordId != null) _history.updateScan(_recordId!, label: edited);

    setState(() {
      _data = edited;

      // A changed serving size changes what "1 serving" is.
      final List<PortionOption> options = NutritionAnalysisService.portionOptions(_data);

      if (!options.any((PortionOption o) => o.portion == _portion) &&
          _portion.amount == null) {
        _portion = NutritionAnalysisService.defaultPortion(_data);
      }
    });
  }

  void _ask(NutritionAnalysis a, [String? question]) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AskNutriPalScreen(
          productName: _productName,
          data: _data,
          analysis: a,
          profile: widget.flow.profile,
          portionText: _portionText(a),
          firstQuestion: question,
        ),
      ),
    );
  }

  Future<void> _toggleFavourite() async {
    final String? id = _recordId;

    if (id == null) return;

    final ScanRecord? updated = await _history.toggleFavourite(id);

    if (!mounted || updated == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            updated.isFavourite
                ? '$_productName added to Favourites. It stays until you remove it.'
                : '$_productName removed from Favourites.',
          ),
          backgroundColor: NpColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _openDetails() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ExtractedNutritionReviewScreen(data: _data),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final NutritionAnalysis a = _analysis;
    final OverallText overall = InsightTextService.overall(a);
    final List<PortionOption> options = NutritionAnalysisService.portionOptions(_data);
    final bool customSelected = !options.any((PortionOption o) => o.portion == _portion);

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
          children: [
            NpTopBar(
              title: 'Your nutrition insights',
              leading: NpCircleButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
              trailing: PopupMenuButton<String>(
                tooltip: 'More options',
                icon: const Icon(Icons.more_horiz_rounded, color: NpColors.purple),
                onSelected: (String value) {
                  if (value == 'details') _openDetails();
                  if (value == 'rename') _rename();
                },
                itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'rename', child: Text('Rename product')),
                  PopupMenuItem<String>(value: 'details', child: Text('Extraction details')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- product ---------------------------------
            NpCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Thumb(imagePath: widget.imagePath),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productName,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: NpColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _sourceLine,
                          style: const TextStyle(fontSize: 12.5, color: NpColors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Rename product',
                    style: IconButton.styleFrom(
                      backgroundColor: NpColors.lilac,
                      foregroundColor: NpColors.purple,
                    ),
                    onPressed: _rename,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- overall verdict -------------------------
            _OverallCard(level: a.overall, text: overall),
            const SizedBox(height: 16),

            // ---- portion picker --------------------------
            NpCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'How much will you have?',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NpColors.ink),
                        ),
                      ),
                      Text(
                        _portionNote(a),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NpColors.link),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.5,
                    children: [
                      for (final PortionOption o in options)
                        _PortionButton(
                          label: o.label,
                          sub: o.sub,
                          selected: o.portion == _portion,
                          onTap: () => setState(() => _portion = o.portion),
                        ),
                      if (_data.servingSizeAmount != null ||
                          _data.hasPer100gColumn ||
                          _data.hasPer100mlColumn)
                      _PortionButton(
                        label: 'Other amount',
                        sub: customSelected && a.portionAmount != null
                            ? '${NutritionAnalysisService.formatAmount(a.portionAmount!, a.portionUnit ?? 'g')} ${a.portionUnit ?? ''}'
                            : 'type it in',
                        selected: customSelected,
                        onTap: () => _customPortion(a),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ---- health areas ----------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _profile.areas.isEmpty ? 'For general health' : 'For your health areas',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: NpColors.ink),
              ),
            ),
            const SizedBox(height: 12),
            for (final AreaAssessment area in a.areas) ...[
              _AreaCard(area: area, text: InsightTextService.area(area, a)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),

            // ---- NutriPal explains -----------------------
            NpCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/images/NutriPal Mascot3.png', width: 52, height: 52),
                      const SizedBox(width: 10),
                      const Text(
                        'NutriPal explains',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NpColors.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    InsightTextService.summary(a, _portionText(a)),
                    style: const TextStyle(fontSize: 14, height: 1.55, color: NpColors.bodyInk),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final String q in InsightTextService.suggestedQuestions(a))
                        ActionChip(
                          label: Text(q),
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: NpColors.purple,
                          ),
                          backgroundColor: NpColors.lilac,
                          side: BorderSide.none,
                          shape: const StadiumBorder(),
                          onPressed: () => _ask(a, q),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: NpPrimaryButton(
                      label: 'Ask NutriPal',
                      icon: Icons.chat_bubble_outline_rounded,
                      color: NpColors.teal,
                      textColor: const Color(0xFF06302E),
                      onPressed: () => _ask(a),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ---- choosing similar products ---------------
            if (InsightTextService.tips(a).isNotEmpty) ...[
              NpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Choosing similar products',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NpColors.ink),
                    ),
                    const SizedBox(height: 10),
                    for (final ProductTip tip in InsightTextService.tips(a)) ...[
                      _TipRow(tip: tip),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ---- nutrition facts -------------------------
            _FactsCard(
              analysis: a,
              portionHeader: _portionText(a).toUpperCase(),
              onEdit: _edit,
            ),
            const SizedBox(height: 16),

            ListenableBuilder(
              listenable: _history,
              builder: (BuildContext context, Widget? child) {
                final bool favourite =
                    _recordId != null && (_history.byId(_recordId!)?.isFavourite ?? false);

                return Row(
                  children: [
                    Expanded(
                      child: NpOutlineButton(
                        label: _isSavedScan ? 'Back' : 'Scan another',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NpPrimaryButton(
                        label: favourite ? 'In favourites' : 'Add to favourites',
                        icon: favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        onPressed: _recordId == null ? null : _toggleFavourite,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              npDisclaimer,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, height: 1.5, color: NpColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// PIECES
// =======================================================

class _Thumb extends StatelessWidget {
  final String? imagePath;

  const _Thumb({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: NpColors.lilac,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? const Icon(Icons.qr_code_2_rounded, color: NpColors.purple, size: 30)
          : Image.file(File(imagePath!), fit: BoxFit.cover),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final NutrientLevel? level;
  final OverallText text;

  const _OverallCard({required this.level, required this.text});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color ink) = switch (level) {
      NutrientLevel.low => (const Color(0xFF5FE3DE), const Color(0xFF06302E)),
      NutrientLevel.moderate => (const Color(0xFFFFD27A), const Color(0xFF4A2C00)),
      NutrientLevel.high => (const Color(0xFFFFB4AC), const Color(0xFF5C0E07)),
      null => (const Color(0xFFE6DDF7), NpColors.purple),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
      decoration: BoxDecoration(
        color: NpColors.purple,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NpPill(text: text.tag, background: bg, ink: ink),
                const SizedBox(height: 8),
                Text(
                  text.title,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text.text,
                  style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFFE6DDF7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Image.asset('assets/images/NutriPal Mascot7.png', width: 100, height: 116, fit: BoxFit.contain),
        ],
      ),
    );
  }
}

class _PortionButton extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  const _PortionButton({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? NpColors.selectedBg : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? NpColors.teal : NpColors.softBorder,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: selected ? NpColors.selectedInk : NpColors.bodyInk,
                ),
              ),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (selected ? NpColors.selectedInk : NpColors.bodyInk).withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final AreaAssessment area;
  final AreaText text;

  const _AreaCard({required this.area, required this.text});

  @override
  Widget build(BuildContext context) {
    final LevelStyle style = LevelStyle.of(area.level);

    final (Color iconBg, Color iconInk) = switch (area.area) {
      HealthArea.diabetes => (const Color(0xFFE8F7F6), const Color(0xFF0B5E5A)),
      HealthArea.bloodPressure => (const Color(0xFFEFE7FA), NpColors.purple),
      HealthArea.cholesterol => (const Color(0xFFFFF1D6), const Color(0xFF8A5200)),
      HealthArea.weight => (const Color(0xFFFDE8F1), const Color(0xFF9C1F5C)),
    };

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  area.area.short,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: iconInk),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.area.title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: NpColors.ink),
                    ),
                    Text(
                      area.area.focus,
                      style: const TextStyle(fontSize: 12.5, color: NpColors.muted),
                    ),
                  ],
                ),
              ),
              NpPill.level(area.level),
            ],
          ),
          if (area.level != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  text.value,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: NpColors.ink),
                ),
                const SizedBox(width: 6),
                Text(
                  text.unit,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NpColors.muted),
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Text(
                    text.share,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NpColors.bodyInk),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: text.bar,
                minHeight: 8,
                backgroundColor: NpColors.track,
                color: style.bar,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            text.why,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: NpColors.bodyInk),
          ),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final ProductTip tip;

  const _TipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tip.ok ? const Color(0xFFDDF4E7) : NpColors.warnBg,
            shape: BoxShape.circle,
          ),
          child: tip.ok
              ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF155E39))
              : const Text(
                  '!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NpColors.warnInk),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip.text,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: NpColors.bodyInk),
          ),
        ),
      ],
    );
  }
}

class _FactsCard extends StatelessWidget {
  final NutritionAnalysis analysis;
  final String portionHeader;
  final VoidCallback onEdit;

  const _FactsCard({
    required this.analysis,
    required this.portionHeader,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    const TextStyle head = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: NpColors.muted);

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Nutrition facts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: NpColors.ink),
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: NpColors.lilac,
                  foregroundColor: NpColors.purple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: NpColors.softBorder, width: 1.5)),
            ),
            child: Row(
              children: [
                const Expanded(child: Text('NUTRIENT', style: head)),
                Expanded(child: Text(portionHeader, textAlign: TextAlign.right, style: head)),
                Expanded(
                  child: Text(
                    analysis.per100Label.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: head,
                  ),
                ),
              ],
            ),
          ),
          for (final FactRow r in analysis.facts)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1EAF9))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: r.isSubRow ? 14 : 0),
                      child: Text(
                        r.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NpColors.ink),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.portion,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NpColors.ink),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r.per100,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, color: NpColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Read from your label. Tap Edit if anything differs from the pack.',
            style: TextStyle(fontSize: 12.5, color: NpColors.muted),
          ),
        ],
      ),
    );
  }
}
