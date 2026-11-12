import 'dart:io';

import 'package:flutter/material.dart';

import '../models/label_detection_status.dart';
import '../services/nutrition_label_ocr_service.dart';
import '../widgets/nutripal_ui.dart';
import 'analysing_screen.dart';
import 'scan_flow.dart';

// =======================================================
// 2 · CONFIRM PHOTO
// =======================================================
//
// Shows the photo and a short PHOTO CHECK from on-device
// OCR before the label is analysed. Each row says what was
// actually found, e.g. "Nutrition table is cut off" rather
// than a warning icon next to "Nutrition table detected":
//   - the whole table is in the photo
//   - the text is clear enough to read
//   - the serving information can be read
// =======================================================

enum _TableState { checking, whole, cutOff, none }

class ConfirmPhotoScreen extends StatefulWidget {
  final String imagePath;

  final ScanFlowContext flow;

  const ConfirmPhotoScreen({
    super.key,
    required this.imagePath,
    required this.flow,
  });

  @override
  State<ConfirmPhotoScreen> createState() => _ConfirmPhotoScreenState();
}

class _ConfirmPhotoScreenState extends State<ConfirmPhotoScreen> {
  NutritionLabelValidationResult? _result;

  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final NutritionLabelValidationResult result =
          await NutritionLabelOcrService.validateImage(widget.imagePath);

      if (!mounted) return;

      setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;

      setState(() => _failed = true);
    }
  }

  bool get _checking => _result == null && !_failed;

  Set<PhotoProblem> get _problems => _result?.problems ?? const <PhotoProblem>{};

  _TableState get _table {
    if (_failed) return _TableState.none;
    if (_result == null) return _TableState.checking;
    if (_result!.status == LabelDetectionStatus.notDetected) return _TableState.none;
    if (_problems.contains(PhotoProblem.cutOff)) return _TableState.cutOff;

    return _TableState.whole;
  }

  bool? get _tableOk => switch (_table) {
        _TableState.checking => null,
        _TableState.whole => true,
        _ => false,
      };

  bool? get _textOk {
    if (_failed) return false;
    if (_result == null) return null;
    if (_table == _TableState.none) return false;

    return !_problems.contains(PhotoProblem.unreadableNames) &&
        !_problems.contains(PhotoProblem.tooFewRows) &&
        !_problems.contains(PhotoProblem.noEnergy);
  }

  bool? get _servingOk {
    if (_failed) return false;
    if (_result == null) return null;
    if (_table == _TableState.none) return false;

    return _result!.hasServingInformation &&
        !_problems.contains(PhotoProblem.noServingBasis);
  }

  String get _tableText => switch (_table) {
        _TableState.checking => 'Looking for the nutrition table',
        _TableState.whole => 'Whole nutrition table in the photo',
        _TableState.cutOff => 'Nutrition table is cut off',
        _TableState.none => 'No nutrition table found',
      };

  String get _textText => switch (_textOk) {
        null => 'Checking the text',
        true => 'Text is clear enough to read',
        false => _table == _TableState.none
            ? 'No nutrition text could be read'
            : 'Some text is unclear or cut off',
      };

  String get _servingText => switch (_servingOk) {
        null => 'Checking the serving information',
        true => 'Serving information detected',
        false => 'Serving information not found',
      };

  void _analyse() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AnalysingScreen(
          imagePath: widget.imagePath,
          flow: widget.flow,
        ),
      ),
    );
  }

  void _openFullScreen() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.file(File(widget.imagePath))),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _TableState table = _table;
    final bool tableFound = table == _TableState.whole || table == _TableState.cutOff;
    final bool allOk = _tableOk == true && _textOk == true && _servingOk == true;
    final List<String> issues = _result?.issues ?? const <String>[];

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              NpTopBar(
                title: 'Confirm photo',
                leading: NpCircleButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _Photo(
                      imagePath: widget.imagePath,
                      table: table,
                      onExpand: _openFullScreen,
                    ),
                    const SizedBox(height: 16),
                    NpCard(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PHOTO CHECK',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: NpColors.muted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CheckRow(ok: _tableOk, text: _tableText),
                          const SizedBox(height: 12),
                          _CheckRow(ok: _textOk, text: _textText),
                          const SizedBox(height: 12),
                          _CheckRow(ok: _servingOk, text: _servingText),
                          if (_failed) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'NutriPal could not check this photo. Please retake it.',
                              style: TextStyle(fontSize: 13.5, color: NpColors.bodyInk),
                            ),
                          ],
                          for (final String issue in issues) ...[
                            const SizedBox(height: 10),
                            Text(
                              issue,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: NpColors.bodyInk,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: NpOutlineButton(
                      label: 'Retake',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NpPrimaryButton(
                      label: tableFound && !allOk && !_checking ? 'Analyse anyway' : 'Analyse',
                      onPressed: tableFound ? _analyse : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String imagePath;
  final _TableState table;
  final VoidCallback onExpand;

  const _Photo({
    required this.imagePath,
    required this.table,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final bool checking = table == _TableState.checking;

    final String text = switch (table) {
      _TableState.checking => 'Checking photo…',
      _TableState.whole => 'Nutrition table detected',
      _TableState.cutOff => 'Nutrition table cut off',
      _TableState.none => 'No nutrition table found',
    };

    final Color ink = switch (table) {
      _TableState.checking => NpColors.purple,
      _TableState.whole => NpColors.okInk,
      _TableState.cutOff => NpColors.warnInk,
      _TableState.none => NpColors.errorInk,
    };

    final IconData icon = switch (table) {
      _TableState.whole => Icons.check_rounded,
      _TableState.cutOff => Icons.priority_high_rounded,
      _ => Icons.close_rounded,
    };

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: const Color(0xFF2B2238),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: NpColors.purple.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // contain, not cover: show the whole photo that is
          // checked, so a cut-off table is visible here too.
          Image.file(File(imagePath), fit: BoxFit.contain),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (checking)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2, color: NpColors.purple),
                    )
                  else
                    Icon(icon, size: 15, color: ink),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 14,
            top: 14,
            child: Material(
              color: const Color(0x99140E24),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onExpand,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool? ok;
  final String text;

  const _CheckRow({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NpCheckIcon(ok: ok),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: NpColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
