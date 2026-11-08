import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_label_data.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/nutrition_extraction_service.dart';
import '../services/product_name_service.dart';
import '../services/value_check_service.dart';
import '../widgets/nutripal_ui.dart';
import 'nutrition_insights_screen.dart';
import 'quick_verification_screen.dart';
import 'scan_flow.dart';

// =======================================================
// 3 · ANALYSING
// =======================================================
//
// 1. Read the nutrition table (on-device OCR, AI fallback)
//    - or use the barcode lookup result. Label photos also
//    look for the product name (ProductNameService).
// 2. Double-check the numbers (ValueCheckService).
// 3. Suspicious values -> Quick verification.
//    Otherwise         -> Your nutrition insights.
// =======================================================

class AnalysingScreen extends StatefulWidget {
  // Label photo to read, or...
  final String? imagePath;

  // ...a table that is already known (barcode lookup).
  final NutritionLabelData? data;

  final ScanFlowContext flow;

  const AnalysingScreen({
    super.key,
    this.imagePath,
    this.data,
    required this.flow,
  }) : assert(imagePath != null || data != null);

  @override
  State<AnalysingScreen> createState() => _AnalysingScreenState();
}

enum _StepState { waiting, running, done, warning }

class _AnalysingScreenState extends State<AnalysingScreen> {
  final List<_StepState> _steps = List<_StepState>.filled(4, _StepState.waiting);

  String _readNote = '';
  String _checkNote = '';
  String _areasNote = '';

  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _pause() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  void _set(int step, _StepState state) {
    if (!mounted) return;

    setState(() => _steps[step] = state);
  }

  Future<void> _run() async {
    // ---- 1. read ---------------------------------------

    _set(0, _StepState.running);

    // Label photos: look for the product name (barcode in
    // the photo, or a name printed on the pack) while the
    // table is read. It never changes a nutrition value.
    final Future<DetectedProductName?> nameSearch = widget.data == null
        ? ProductNameService.detect(widget.imagePath!)
        : Future<DetectedProductName?>.value(null);

    NutritionLabelData data;

    try {
      data = widget.data ?? await NutritionExtractionService.extract(widget.imagePath!);
    } catch (_) {
      if (!mounted) return;

      setState(() => _error =
          'NutriPal could not read the nutrition values. Please try another photo.');
      return;
    }

    if (!mounted) return;

    if (!data.hasNutrients) {
      setState(() => _error =
          'No nutrition values could be read from this photo. '
          'Make sure the whole table is inside the frame and try again.');
      return;
    }

    final int rows = data.nutrients.where((NutrientRow r) => r.hasAnyValue).length;

    setState(() {
      _readNote = '$rows nutrient${rows == 1 ? '' : 's'} found';
      _steps[0] = _StepState.done;
      _steps[1] = _StepState.running;
    });

    await _pause();

    // ---- 2. double-check --------------------------------

    final List<ValueIssue> issues = ValueCheckService.find(data);

    if (!mounted) return;

    final String per100 = data.hasPer100mlColumn ? 'per 100 ml' : 'per 100 g';

    setState(() {
      _checkNote = issues.isEmpty
          ? data.hasPerServingColumn &&
                  (data.hasPer100gColumn || data.hasPer100mlColumn)
              ? 'Per serving matches $per100'
              : 'Values look consistent'
          : '${issues.length} value${issues.length == 1 ? '' : 's'} need checking';
      _steps[1] = issues.isEmpty ? _StepState.done : _StepState.warning;
      _steps[2] = _StepState.running;
    });

    await _pause();

    if (!mounted) return;

    // ---- 3. health areas --------------------------------

    final NutritionProfile profile =
        NutritionProfile.fromSetupData(widget.flow.profile);

    setState(() {
      _areasNote = profile.areasToShow.map((HealthArea a) => a.title).join(' · ');
      _steps[2] = _StepState.done;
      _steps[3] = _StepState.running;
    });

    await _pause();

    if (!mounted) return;

    // Add the product name if one was found in time
    // (otherwise "Scanned product"; the user can rename).
    if ((data.productName ?? '').trim().isEmpty) {
      final DetectedProductName? name = await nameSearch.timeout(
        const Duration(seconds: 6),
        onTimeout: () => null,
      );

      if (!mounted) return;

      if (name != null) {
        data = data.copyWith(productName: name.name, productBrand: name.brand);
      }
    }

    _set(3, _StepState.done);

    // ---- 4. next screen ---------------------------------

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => issues.isEmpty
            ? NutritionInsightsScreen(
                data: data,
                imagePath: widget.imagePath,
                flow: widget.flow,
              )
            : QuickVerificationScreen(
                data: data,
                issues: issues,
                imagePath: widget.imagePath,
                flow: widget.flow,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              NpTopBar(
                title: 'Analysing label',
                leading: NpCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
              const SizedBox(height: 24),
              Image.asset('assets/images/NutriPal Mascot2.png', height: 140),
              const SizedBox(height: 16),
              Text(
                _error == null ? 'Reading your label…' : 'Something went wrong',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: NpColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? 'NutriPal is matching this product to your health profile.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.45, color: NpColors.muted),
              ),
              const SizedBox(height: 22),
              if (_error == null)
                NpCard(
                  child: Column(
                    children: [
                      _StepRow(
                        state: _steps[0],
                        title: widget.data == null
                            ? 'Reading the nutrition table'
                            : 'Loading the product facts',
                        note: _readNote,
                      ),
                      _StepRow(
                        state: _steps[1],
                        title: 'Double-checking the numbers',
                        note: _checkNote,
                      ),
                      _StepRow(
                        state: _steps[2],
                        title: 'Checking your health areas',
                        note: _areasNote,
                      ),
                      _StepRow(
                        state: _steps[3],
                        title: 'Writing your summary',
                        note: '',
                        last: true,
                      ),
                    ],
                  ),
                ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error == null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NpColors.lilac,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Tip: labels show values per serving and per 100 g or ml. '
                    'NutriPal works out the amount for the portion you actually have.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: NpColors.bodyInk),
                  ),
                )
              else
                NpPrimaryButton(
                  label: 'Retake photo',
                  onPressed: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final _StepState state;
  final String title;
  final String note;
  final bool last;

  const _StepRow({
    required this.state,
    required this.title,
    required this.note,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool? ok = switch (state) {
      _StepState.done => true,
      _StepState.warning => false,
      _ => null,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        children: [
          if (state == _StepState.waiting)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: NpColors.softBorder, width: 2),
              ),
            )
          else
            NpCheckIcon(ok: ok),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: state == _StepState.waiting ? NpColors.muted : NpColors.ink,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: const TextStyle(fontSize: 12.5, color: NpColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
