import 'package:flutter/material.dart';

import '../models/nutrition_label_data.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/nutrition_label_editor.dart';
import '../services/value_check_service.dart';
import '../widgets/nutripal_ui.dart';
import 'extracted_nutrition_review_screen.dart';
import 'nutrition_insights_screen.dart';
import 'scan_flow.dart';

// =======================================================
// 3b · QUICK VERIFICATION
// =======================================================
//
// Shown only when ValueCheckService found values that look
// misread. The user compares them with the pack, fixes
// them (or taps "Use …"), then sees the result.
// =======================================================

class QuickVerificationScreen extends StatefulWidget {
  final NutritionLabelData data;

  final List<ValueIssue> issues;

  final String? imagePath;

  final ScanFlowContext flow;

  const QuickVerificationScreen({
    super.key,
    required this.data,
    required this.issues,
    required this.flow,
    this.imagePath,
  });

  @override
  State<QuickVerificationScreen> createState() =>
      _QuickVerificationScreenState();
}

class _QuickVerificationScreenState extends State<QuickVerificationScreen> {
  late final List<TextEditingController> _amounts;
  late final List<String> _units;

  @override
  void initState() {
    super.initState();

    _amounts = <TextEditingController>[
      for (final ValueIssue i in widget.issues)
        TextEditingController(
          text: NutritionAnalysisService.formatAmount(i.current.amount, i.current.unit),
        ),
    ];

    _units = <String>[
      for (final ValueIssue i in widget.issues)
        i.kind == ValueIssueKind.unitMissing && i.suggestedUnit.isNotEmpty
            ? i.suggestedUnit
            : i.current.unit,
    ];
  }

  @override
  void dispose() {
    for (final TextEditingController c in _amounts) {
      c.dispose();
    }

    super.dispose();
  }

  void _useSuggestion(int i) {
    final ValueIssue issue = widget.issues[i];

    if (issue.suggestedAmount == null) return;

    setState(() {
      _amounts[i].text =
          NutritionAnalysisService.formatAmount(issue.suggestedAmount!, issue.suggestedUnit);
      _units[i] = issue.suggestedUnit;
    });
  }

  void _confirm() {
    NutritionLabelData data = widget.data;

    for (int i = 0; i < widget.issues.length; i++) {
      final ValueIssue issue = widget.issues[i];
      final double? amount =
          double.tryParse(_amounts[i].text.trim().replaceAll(',', '.'));

      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please enter a number for ${issue.nutrient}.'),
            backgroundColor: NpColors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final bool changed = _amounts[i].text.trim() !=
              NutritionAnalysisService.formatAmount(issue.current.amount, issue.current.unit) ||
          _units[i] != issue.current.unit;

      if (!changed) continue;

      data = NutritionLabelEditor.setValue(
        data,
        row: issue.row,
        column: issue.column,
        valueIndex: issue.valueIndex,
        value: NutritionValue(
          amount: amount,
          unit: _units[i],
          rawText: 'checked by you',
        ),
      );
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => NutritionInsightsScreen(
          data: data,
          imagePath: widget.imagePath,
          flow: widget.flow,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int n = widget.issues.length;
    final int others = ValueCheckService.countValues(widget.data) - n;

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              NpTopBar(
                title: 'Quick verification',
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NpColors.warnBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$n value${n == 1 ? '' : 's'} need${n == 1 ? 's' : ''} checking',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: NpColors.warnInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'NutriPal found a possible mismatch. Compare them with '
                            'the label before continuing.',
                            style: TextStyle(fontSize: 13.5, height: 1.45, color: NpColors.bodyInk),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int i = 0; i < n; i++) ...[
                      _IssueCard(
                        issue: widget.issues[i],
                        controller: _amounts[i],
                        unit: _units[i],
                        onUnitChanged: (String u) => setState(() => _units[i] = u),
                        onUseSuggestion: () => _useSuggestion(i),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (others > 0)
                      NpCard(
                        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: NpColors.okInk, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$others other value${others == 1 ? '' : 's'} look${others == 1 ? 's' : ''} right',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: NpColors.ink,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      ExtractedNutritionReviewScreen(data: widget.data),
                                ),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(fontWeight: FontWeight.w800, color: NpColors.link),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NpPrimaryButton(label: 'Confirm and see my result', onPressed: _confirm),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  widget.imagePath == null ? 'Scan again instead' : 'Retake photo instead',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: NpColors.purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final ValueIssue issue;
  final TextEditingController controller;
  final String unit;
  final ValueChanged<String> onUnitChanged;
  final VoidCallback onUseSuggestion;

  const _IssueCard({
    required this.issue,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    required this.onUseSuggestion,
  });

  static const List<String> _unitChoices = <String>['g', 'mg', 'µg', 'kcal', 'kJ', 'ml', 'IU'];

  @override
  Widget build(BuildContext context) {
    final List<String> units = <String>{
      ..._unitChoices,
      if (unit.isNotEmpty && unit != '?') unit,
    }.toList();

    final String? selected = units.contains(unit) ? unit : null;

    return NpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${issue.nutrient} · ${issue.columnLabel}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NpColors.ink,
                  ),
                ),
              ),
              NpPill(text: issue.tag, background: NpColors.warnBg, ink: NpColors.warnInk),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: NpColors.ink),
                  decoration: InputDecoration(
                    labelText: 'Value on the pack',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFDCCFF0), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: NpColors.teal, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: selected,
                hint: const Text('unit'),
                underline: const SizedBox.shrink(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: NpColors.muted),
                items: <DropdownMenuItem<String>>[
                  for (final String u in units) DropdownMenuItem<String>(value: u, child: Text(u)),
                ],
                onChanged: (String? u) {
                  if (u != null) onUnitChanged(u);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            issue.message,
            style: const TextStyle(fontSize: 13.5, height: 1.45, color: NpColors.bodyInk),
          ),
          if (issue.suggestedAmount != null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: NpColors.okInk,
                backgroundColor: NpColors.okBg,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onUseSuggestion,
              child: Text(
                'Use ${NutritionAnalysisService.formatAmount(issue.suggestedAmount!, issue.suggestedUnit)} ${issue.suggestedUnit}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
