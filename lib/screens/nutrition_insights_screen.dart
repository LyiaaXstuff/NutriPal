import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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

  // The user's own product photo (label photo, or one added
  // here). Barcode scans fall back to the Open Food Facts
  // photo in _data.productImageUrl.
  String? _photoPath;

  bool get _isSavedScan => widget.savedRecordId != null;

  @override
  void initState() {
    super.initState();

    _data = widget.data;
    _portion = NutritionAnalysisService.defaultPortion(_data);
    _productName = widget.savedProductName ?? _initialName(_data);
    _recordId = widget.savedRecordId;
    _photoPath = widget.imagePath;

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
      // A photo added earlier for the same product.
      _photoPath = record.thumbnailPath ?? _photoPath;
    });
  }

  // =====================================================
  // PRODUCT PHOTO
  // =====================================================

  Future<void> _openPhoto() async {
    final String? result = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (BuildContext context) =>
            _PhotoViewer(path: _photoPath, url: _data.productImageUrl),
      ),
    );

    if (result == 'change' && mounted) await _choosePhoto();
  }

  Future<void> _choosePhoto() async {
    final String? choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: NpColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 8),
                child: Text(
                  'Product photo',
                  style: TextStyle(color: NpColors.purple, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: NpColors.purple),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: NpColors.purple),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(sheetContext, 'gallery'),
              ),
              if (_photoPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: NpColors.errorInk),
                  title: const Text('Remove my photo', style: TextStyle(color: NpColors.errorInk)),
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final String? id = _recordId;

    if (id == null) {
      _snack('Please wait a moment, NutriPal is still saving this scan.');
      return;
    }

    if (choice == 'remove') {
      await _history.setPhoto(id, null);
      if (mounted) setState(() => _photoPath = null);
      return;
    }

    final XFile? picked;

    try {
      picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      _snack('Could not open the ${choice == 'camera' ? 'camera' : 'gallery'}.');
      return;
    }

    if (picked == null || !mounted) return;

    final String pickedPath = picked.path;
    final ScanRecord? updated = await _history.setPhoto(id, pickedPath);

    if (!mounted) return;

    setState(() => _photoPath = updated?.thumbnailPath ?? pickedPath);
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: NpColors.purple,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  ExplainText _explain(NutritionAnalysis a) {
    final String amount = a.portionAmount == null || a.portionUnit == null
        ? ''
        : '${NutritionAnalysisService.formatAmount(a.portionAmount!, a.portionUnit!)} ${a.portionUnit}';

    final String? household = a.portionServings == null
        ? null
        : NutritionAnalysisService.householdText(_data, a.portionServings!);

    final String portion = household != null && amount.isNotEmpty
        ? 'your $household ($amount)'
        : (amount.isNotEmpty ? 'your $amount' : _portionText(a).toLowerCase());

    return InsightTextService.explain(
      a,
      data: _data,
      profile: _profile,
      portionText: portion,
      weightGoal: _profile.weightGoal,
    );
  }

  // ---- household measure counter --------------------

  static bool _isWholeCount(HouseholdMeasure m, double servings) {
    final double c = m.countFor(servings);

    return c >= 1 && (c - c.roundToDouble()).abs() < 1e-6;
  }

  /// The count shown: the chosen one, else one serving's
  /// worth (at least 1).
  int _countFor(HouseholdMeasure m) {
    final double? s = _portion.servings;

    if (s != null && _isWholeCount(m, s)) return m.countFor(s).round();

    return m.perServing.round().clamp(1, _maxCount(m));
  }

  /// Not capped at one pack: the user may have two cans
  /// or several packs.
  int _maxCount(HouseholdMeasure m) => 99;

  String _portionNote(NutritionAnalysis a) {
    final double? s = a.portionServings;

    if (s == null) return '';

    final String? household = NutritionAnalysisService.householdText(_data, s);

    if (household != null) return household;

    final String n = NutritionAnalysisService.formatAmount(s, 'g');

    return '$n serving${n == '1' ? '' : 's'}';
  }

  String get _sourceLine {
    // Only the serving details (no scan method or source).
    final List<String> parts = <String>[];

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
      // Tapping outside only hides the keyboard; Cancel
      // (or the back button) closes the popup.
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _TapToHideKeyboard(
        child: AlertDialog(
          // Same look as the Product name popup.
          backgroundColor: const Color(0xFFF8F4FD),
          surfaceTintColor: Colors.transparent,
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'How much will you have?',
            style: TextStyle(
              color: NpColors.purple,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Amount',
                  // Unit inside the box, on the right.
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 14),
                    child: Text(
                      unit,
                      style: const TextStyle(
                        color: NpColors.purple,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: const Color(0xFFEDE4F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: NpColors.purple, width: 1.4),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: Color(0xFF38138C), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'Enter the amount in $unit.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: NpColors.muted, fontSize: 12.5),
                ),
              ),
            ],
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
      // Tapping outside only hides the keyboard; Cancel
      // (or the back button) closes the popup.
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _TapToHideKeyboard(
        child: AlertDialog(
          // Light purple card; the text box inside is a
          // slightly deeper purple so it stands out.
          backgroundColor: const Color(0xFFF8F4FD),
          surfaceTintColor: Colors.transparent,
          // Tighter than Flutter's default spacing, so the
          // popup itself is smaller.
          titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Product name',
            style: TextStyle(
              color: NpColors.purple,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g. Homesoy Soya Bean Drink',
                  // Character count inside the box, on the right
                  // (the default one under the box is hidden).
                  counterText: '',
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(left: 8, right: 14),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (BuildContext context, TextEditingValue value, Widget? child) => Text(
                        '${value.text.characters.length}/60',
                        style: const TextStyle(color: NpColors.muted, fontSize: 12.5),
                      ),
                    ),
                  ),
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  // Rounded box instead of an underline.
                  filled: true,
                  fillColor: const Color(0xFFEDE4F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: NpColors.purple, width: 1.4),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                    borderSide: BorderSide(color: Color(0xFF38138C), width: 2),
                  ),
                ),
              ),
              // Caption under the box, lined up with its left
              // edge (helperText would be indented).
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.only(left: 2),
                child: Text(
                  'Use the name on the pack, or your own.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: NpColors.muted, fontSize: 12.5),
                ),
              ),
            ],
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
    final OverallText overall =
        InsightTextService.overall(a, weightGoal: _profile.weightGoal);
    final List<PortionOption> options = NutritionAnalysisService.portionOptions(_data);
    final HouseholdMeasure? measure = NutritionAnalysisService.householdMeasure(_data);
    final bool countSelected = measure != null &&
        _portion.servings != null &&
        _isWholeCount(measure, _portion.servings!);
    final bool customSelected =
        !countSelected && !options.any((PortionOption o) => o.portion == _portion);

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
          children: [
            // Same header as My Account, Security and Scan
            // History: thin back arrow, centred title; the
            // "more" menu stays on the right.
            SizedBox(
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF38138C),
                        size: 21,
                      ),
                    ),
                  ),
                  const Padding(
                    // Keeps the title clear of the two icons.
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Your Nutrition Insights',
                        maxLines: 1,
                        style: TextStyle(
                          color: Color(0xFF38138C),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: PopupMenuButton<String>(
                      tooltip: 'More options',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Color(0xFF38138C),
                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- product ---------------------------------
            NpCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _Thumb(
                    imagePath: _photoPath,
                    imageUrl: _data.productImageUrl,
                    onOpen: _openPhoto,
                    onAddPhoto: _choosePhoto,
                  ),
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
                            color: NpColors.purple,
                          ),
                        ),
                        if (_sourceLine.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _sourceLine,
                            style: const TextStyle(fontSize: 12.5, color: NpColors.muted),
                          ),
                        ],
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
                  _PortionGrid(
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
                  // Count by the label's own measure, e.g.
                  // biscuits or cups (only when printed).
                  if (measure != null) ...[
                    const SizedBox(height: 10),
                    _CountPicker(
                      measure: measure,
                      count: _countFor(measure),
                      max: _maxCount(measure),
                      selected: countSelected,
                      onChanged: (int count) => setState(
                        () => _portion = Portion.servings(measure.servingsFor(count.toDouble())),
                      ),
                    ),
                  ],
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
              _AreaCard(
                area: area,
                text: InsightTextService.plainArea(area, a, weightGoal: _profile.weightGoal),
                weightGoal: _profile.weightGoal,
              ),
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
                  _ExplainBody(text: _explain(a)),
                  const SizedBox(height: 14),
                  // Chips sit closer together: no extra tap
                  // padding around each one.
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      for (final String q in InsightTextService.suggestedQuestions(a))
                        ActionChip(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
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

                // The favourites button gets more room so
                // "Add to favourites" fits.
                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: NpOutlineButton(
                        label: _isSavedScan ? 'Back' : 'Scan another',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: NpPrimaryButton(
                        label: favourite ? 'In favourites' : 'Add to favourites',
                        icon: favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        // Red once saved, like the filled heart.
                        color: favourite ? const Color(0xFFD2453B) : NpColors.purple,
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
  // The user's own photo (label photo or one they added).
  final String? imagePath;

  // Open Food Facts front photo (barcode scans).
  final String? imageUrl;

  final VoidCallback onOpen;
  final VoidCallback onAddPhoto;

  const _Thumb({
    required this.imagePath,
    required this.imageUrl,
    required this.onOpen,
    required this.onAddPhoto,
  });

  bool get _hasPhoto => imagePath != null || imageUrl != null;

  @override
  Widget build(BuildContext context) {
    final Widget box = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: NpColors.lilac,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasPhoto
          ? Hero(
              tag: 'product-photo',
              child: _ProductImage(path: imagePath, url: imageUrl, fit: BoxFit.cover),
            )
          // No photo yet: invite the user to add one.
          : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: NpColors.purple, size: 24),
                SizedBox(height: 3),
                Text(
                  'Add photo',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: NpColors.purple),
                ),
              ],
            ),
    );

    return Semantics(
      button: true,
      label: _hasPhoto ? 'View product photo' : 'Add a product photo',
      child: GestureDetector(
        onTap: _hasPhoto ? onOpen : onAddPhoto,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            box,
            if (_hasPhoto)
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: NpColors.purple,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A product photo from the phone or from Open Food Facts.
class _ProductImage extends StatelessWidget {
  final String? path;
  final String? url;
  final BoxFit fit;

  const _ProductImage({required this.path, required this.url, required this.fit});

  static const Widget _broken =
      Center(child: Icon(Icons.image_not_supported_outlined, color: NpColors.muted));

  @override
  Widget build(BuildContext context) {
    final String? p = path;

    if (p != null) {
      return Image.file(
        File(p),
        fit: fit,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            url == null ? _broken : _network(url!),
      );
    }

    return _network(url!);
  }

  Widget _network(String link) => Image.network(
        link,
        fit: fit,
        loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) =>
            progress == null
                ? child
                : const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: NpColors.purple),
                    ),
                  ),
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) => _broken,
      );
}

// =======================================================
// FULL-SCREEN PRODUCT PHOTO
// =======================================================
//
// Pinch or double-tap to zoom. "Change photo" closes the
// viewer with the result 'change'.

class _PhotoViewer extends StatefulWidget {
  final String? path;
  final String? url;

  const _PhotoViewer({required this.path, required this.url});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  final TransformationController _zoom = TransformationController();

  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoom.value != Matrix4.identity()) {
      _zoom.value = Matrix4.identity();
      return;
    }

    final Offset p = _doubleTap?.localPosition ?? Offset.zero;

    // Zoom 2.5x around the tapped point.
    _zoom.value = Matrix4.diagonal3Values(2.5, 2.5, 1)
      ..setTranslationRaw(-p.dx * 1.5, -p.dy * 1.5, 0);
  }

  @override
  Widget build(BuildContext context) {
    // Open Food Facts photos are shared under CC BY-SA and
    // must be credited.
    final bool fromDatabase = widget.path == null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (TapDownDetails d) => _doubleTap = d,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _zoom,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: 'product-photo',
                    child: _ProductImage(path: widget.path, url: widget.url, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, 'change'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Change photo', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (fromDatabase)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Photo: Open Food Facts (CC BY-SA)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ),
                  const Text(
                    'Pinch or double-tap to zoom',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  final PlainAreaText text;

  // 'lose' | 'maintain' | 'gain' from the profile.
  final String? weightGoal;

  const _AreaCard({required this.area, required this.text, this.weightGoal});

  /// Weight shows the user's own goal; other areas their
  /// usual title.
  String get _title =>
      area.area == HealthArea.weight ? 'Weight management' : area.area.title;

  String get _subtitle {
    if (area.area != HealthArea.weight) return area.area.focus;

    final String? goal = switch (weightGoal) {
      'lose' => 'Lose weight',
      'maintain' => 'Maintain weight',
      'gain' => 'Gain weight',
      _ => null,
    };

    return goal == null ? area.area.focus : '$goal · ${area.area.focus}';
  }

  @override
  Widget build(BuildContext context) {
    // Same symbols as Health Conditions and the Profile
    // chips.
    final IconData icon = switch (area.area) {
      HealthArea.diabetes => Icons.water_drop_outlined,
      HealthArea.bloodPressure => Icons.monitor_heart_outlined,
      HealthArea.cholesterol => Icons.favorite_border_rounded,
      HealthArea.weight => Icons.monitor_weight_outlined,
    };

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
                child: Icon(icon, size: 24, color: iconInk),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: NpColors.ink),
                    ),
                    Text(
                      _subtitle,
                      style: const TextStyle(fontSize: 12.5, color: NpColors.muted),
                    ),
                  ],
                ),
              ),
              NpPill.level(area.level),
            ],
          ),
          // ---- plain answer first ----------------------
          const SizedBox(height: 14),
          Text(
            text.headline,
            style: const TextStyle(
              fontSize: 18.5,
              height: 1.25,
              fontWeight: FontWeight.w900,
              color: NpColors.ink,
            ),
          ),
          if (text.marker != null) ...[
            const SizedBox(height: 14),
            _LevelMeter(position: text.marker!),
          ],
          for (final PlainFact fact in text.facts) ...[
            const SizedBox(height: 12),
            _FactRow(fact: fact),
          ],
          if (text.tip != null) ...[
            const SizedBox(height: 14),
            _NoteBox(
              icon: Icons.lightbulb_outline_rounded,
              lead: 'Tip: ',
              text: text.tip!,
              background: NpColors.lilac,
              ink: NpColors.bodyInk,
            ),
          ],
          if (text.goodNews != null) ...[
            const SizedBox(height: 10),
            _NoteBox(
              icon: Icons.check_circle_outline_rounded,
              lead: 'Good news: ',
              text: text.goodNews!,
              background: NpColors.okBg,
              ink: NpColors.okInk,
            ),
          ],
          if (text.note != null) ...[
            const SizedBox(height: 10),
            Text(
              text.note!,
              style: const TextStyle(fontSize: 12.5, height: 1.4, color: NpColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// =======================================================
// LOW | MODERATE | HIGH BAR
// =======================================================

class _LevelMeter extends StatelessWidget {
  // 0..1 along the bar.
  final double position;

  const _LevelMeter({required this.position});

  static const double _dot = 18;

  @override
  Widget build(BuildContext context) {
    const TextStyle label = TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: NpColors.muted,
    );

    return Column(
      children: [
        SizedBox(
          height: _dot,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) {
              final double left = (box.maxWidth * position - _dot / 2)
                  .clamp(0.0, box.maxWidth - _dot);

              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: const <Color>[
                                Color(0xFF8FE0DC),
                                Color(0xFFFFD27A),
                                Color(0xFFFF9C90),
                              ][i],
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(i == 0 ? 5 : 0),
                                right: Radius.circular(i == 2 ? 5 : 0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Positioned(
                    left: left,
                    child: Container(
                      width: _dot,
                      height: _dot,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: NpColors.ink, width: 3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Expanded(child: Text('Low', style: label)),
            Expanded(child: Text('Moderate', textAlign: TextAlign.center, style: label)),
            Expanded(child: Text('High', textAlign: TextAlign.right, style: label)),
          ],
        ),
      ],
    );
  }
}

// =======================================================
// ONE NUTRIENT LINE: "Sugar 14.7 g · almost half..."
// =======================================================

class _FactRow extends StatelessWidget {
  final PlainFact fact;

  const _FactRow({required this.fact});

  static IconData _icon(String nutrient) => switch (nutrient) {
        'Carbohydrate' => Icons.rice_bowl_outlined,
        'Total Sugars' => Icons.cookie_outlined,
        'Sodium' => Icons.grain_rounded,
        'Energy' => Icons.local_fire_department_outlined,
        _ => Icons.opacity_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: NpColors.lilac,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon(fact.nutrient), size: 18, color: NpColors.purple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${fact.label} ${fact.amount}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: NpColors.ink),
                  ),
                  TextSpan(text: ' · ${fact.meaning}'),
                ],
              ),
              style: const TextStyle(fontSize: 14, height: 1.35, color: NpColors.bodyInk),
            ),
          ),
        ),
      ],
    );
  }
}

// =======================================================
// TIP / GOOD NEWS BOX
// =======================================================

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String lead;
  final String text;
  final Color background;
  final Color ink;

  const _NoteBox({
    required this.icon,
    required this.lead,
    required this.text,
    required this.background,
    required this.ink,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: lead, style: const TextStyle(fontWeight: FontWeight.w800)),
                  TextSpan(text: text),
                ],
              ),
              style: TextStyle(fontSize: 13.5, height: 1.4, color: ink),
            ),
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
                // Wider name column so long names like
                // "Monounsaturated Fat" wrap between words,
                // never inside one.
                const Expanded(flex: 6, child: Text('NUTRIENT', style: head)),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(portionHeader, style: head),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(analysis.per100Label.toUpperCase(), style: head),
                    ),
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
                    flex: 6,
                    child: Padding(
                      padding: EdgeInsets.only(left: r.isSubRow ? 14 : 0),
                      child: Text(
                        r.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: NpColors.ink),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      r.portion,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: NpColors.ink),
                    ),
                  ),
                  Expanded(
                    flex: 3,
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

// =======================================================
// TAP OUTSIDE TO HIDE THE KEYBOARD
// =======================================================
//
// Wraps a popup so a tap anywhere outside its text box
// closes the keyboard instead of the popup.

class _TapToHideKeyboard extends StatelessWidget {
  final Widget child;

  const _TapToHideKeyboard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}

// =======================================================
// COUNT PICKER ("How many biscuits?")
// =======================================================
//
// Shown only when the label prints an everyday measure,
// e.g. "30 g (3 biscuits)". One biscuit = 10 g comes from
// the label itself, never from a guess.

class _CountPicker extends StatelessWidget {
  final HouseholdMeasure measure;
  final int count;
  final int max;
  final bool selected;
  final ValueChanged<int> onChanged;

  const _CountPicker({
    required this.measure,
    required this.count,
    required this.max,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color ink = selected ? NpColors.selectedInk : NpColors.bodyInk;
    final String each =
        '1 ${measure.name} = ${NutritionAnalysisService.formatAmount(measure.amountEach, measure.unit)} ${measure.unit}';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: selected ? NpColors.selectedBg : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? NpColors.teal : NpColors.softBorder,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How many ${measure.nameFor(2)}?',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  each,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ink.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          _CountButton(
            icon: Icons.remove_rounded,
            tooltip: 'One ${measure.name} less',
            // First tap on an unselected picker just
            // selects the shown count.
            onPressed: !selected
                ? () => onChanged(count)
                : (count > 1 ? () => onChanged(count - 1) : null),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ink),
            ),
          ),
          _CountButton(
            icon: Icons.add_rounded,
            tooltip: 'One ${measure.name} more',
            onPressed: !selected
                ? () => onChanged(count)
                : (count < max ? () => onChanged(count + 1) : null),
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CountButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: NpColors.lilac,
        foregroundColor: NpColors.purple,
        disabledBackgroundColor: NpColors.track,
        minimumSize: const Size(40, 40),
      ),
    );
  }
}

// =======================================================
// PORTION GRID
// =======================================================
//
// Two choices per row. With an odd number, the last one
// ("Other amount") takes the full row, so there is no
// empty gap.

class _PortionGrid extends StatelessWidget {
  final List<Widget> children;

  const _PortionGrid({required this.children});

  static const double _height = 62;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];

    for (int i = 0; i < children.length; i += 2) {
      final bool pair = i + 1 < children.length;

      rows.add(
        SizedBox(
          height: _height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              if (pair) ...[
                const SizedBox(width: _gap),
                Expanded(child: children[i + 1]),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: _gap),
          rows[r],
        ],
      ],
    );
  }
}

// =======================================================
// NUTRIPAL EXPLAINS BODY
// =======================================================
//
// The portion at a glance: what is in it, its share of the
// day's energy, and one worked-out tip (what twice or
// half the portion would do). Good news and what to watch are on the health area
// cards above, so they are not repeated here.

class _ExplainBody extends StatelessWidget {
  final ExplainText text;

  const _ExplainBody({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text.portion,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: NpColors.ink),
        ),
        if (text.amounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final String v in text.amounts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: NpColors.softBorder),
                  ),
                  child: Text(
                    v,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: NpColors.bodyInk),
                  ),
                ),
            ],
          ),
        ],
        if (text.energy != null) ...[
          const SizedBox(height: 8),
          Text(
            text.energy!,
            style: const TextStyle(fontSize: 13.5, height: 1.4, color: NpColors.muted),
          ),
        ],
        const SizedBox(height: 12),
        _ExplainLine(
          icon: Icons.lightbulb_outline_rounded,
          background: NpColors.lilac,
          ink: NpColors.purple,
          text: text.tip,
        ),
        if (text.note != null) ...[
          const SizedBox(height: 10),
          Text(
            text.note!,
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: NpColors.muted),
          ),
        ],
      ],
    );
  }
}

class _ExplainLine extends StatelessWidget {
  final IconData icon;
  final Color background;
  final Color ink;
  final String text;

  const _ExplainLine({
    required this.icon,
    required this.background,
    required this.ink,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: ink),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4, color: NpColors.bodyInk),
            ),
          ),
        ),
      ],
    );
  }
}

