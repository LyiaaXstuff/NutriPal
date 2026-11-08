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
// OCR before the label is analysed:
//   - Nutrition table detected
//   - Text is clear enough to read
//   - Serving information detected
// =======================================================

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

  bool? get _tableOk {
    if (_failed) return false;
    if (_result == null) return null;

    return _result!.status != LabelDetectionStatus.notDetected;
  }

  bool? get _textOk {
    if (_failed) return false;
    if (_result == null) return null;

    return _result!.status == LabelDetectionStatus.detected;
  }

  bool? get _servingOk {
    if (_failed) return false;
    if (_result == null) return null;

    return _result!.hasServingInformation;
  }

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
    final bool tableFound = _tableOk == true;
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
                      checking: _checking,
                      tableFound: tableFound,
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
                          _CheckRow(ok: _tableOk, text: 'Nutrition table detected'),
                          const SizedBox(height: 12),
                          _CheckRow(ok: _textOk, text: 'Text is clear enough to read'),
                          const SizedBox(height: 12),
                          _CheckRow(ok: _servingOk, text: 'Serving information detected'),
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
                      label: _textOk == false && tableFound ? 'Analyse anyway' : 'Analyse',
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
  final bool checking;
  final bool tableFound;
  final VoidCallback onExpand;

  const _Photo({
    required this.imagePath,
    required this.checking,
    required this.tableFound,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final String text = checking
        ? 'Checking photo…'
        : tableFound
            ? 'Nutrition table detected'
            : 'No nutrition table found';

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
          Image.file(File(imagePath), fit: BoxFit.cover),
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
                    Icon(
                      tableFound ? Icons.check_rounded : Icons.close_rounded,
                      size: 15,
                      color: tableFound ? NpColors.okInk : NpColors.errorInk,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: checking
                          ? NpColors.purple
                          : tableFound
                              ? NpColors.okInk
                              : NpColors.errorInk,
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
