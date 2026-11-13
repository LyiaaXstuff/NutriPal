import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/nutrition_targets.dart';
import '../models/profile_setup_data.dart';
import '../services/nutrition_analysis_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/nutripal_ui.dart';

// =======================================================
// PROFILE > NUTRITION TARGETS
// =======================================================
//
// Optional targets, usually from the user's doctor or
// dietitian. Each one replaces NutriPal's default for that
// nutrient in every analysis. Empty = NutriPal's guide,
// which is shown under each field.
//
// Main nutrients (carbohydrate, protein, fat) are always
// shown; the others follow the user's health conditions.
// Daily energy lives on the Weight Management Goal screen.
// =======================================================

class NutritionTargetsScreen extends StatefulWidget {
  final ProfileSetupData data;

  const NutritionTargetsScreen({super.key, required this.data});

  @override
  State<NutritionTargetsScreen> createState() => _NutritionTargetsScreenState();
}

class _NutritionTargetsScreenState extends State<NutritionTargetsScreen> {
  late final Map<String, TextEditingController> _controllers = <String, TextEditingController>{
    for (final NutritionTargetField f in NutritionTargets.fields)
      f.key: TextEditingController(text: _text(widget.data.nutritionTargets.valueOf(f.key))),
  };

  late NutritionTargets _saved = widget.data.nutritionTargets.copy();

  // NutriPal's own targets for this profile (no user
  // targets), shown as the guide under each field.
  late final DailyTargets _guide = _guideTargets();

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }

    super.dispose();
  }

  static String _text(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toInt().toString();

    return v.toStringAsFixed(1);
  }

  DailyTargets _guideTargets() {
    final NutritionTargets own = widget.data.nutritionTargets;

    widget.data.nutritionTargets = NutritionTargets();

    try {
      return NutritionAnalysisService.targetsFor(NutritionProfile.fromSetupData(widget.data));
    } finally {
      widget.data.nutritionTargets = own;
    }
  }

  // ---- which fields to show ---------------------------

  Set<HealthArea> get _areas => <HealthArea>{
        if (widget.data.diabetes) HealthArea.diabetes,
        if (widget.data.hypertension) HealthArea.bloodPressure,
        if (widget.data.highCholesterol) HealthArea.cholesterol,
        if (widget.data.weightManagement) HealthArea.weight,
      };

  bool _relevant(NutritionTargetField f) {
    if (f.isMain) return true;

    final Set<HealthArea> areas = _areas;

    // General nutrition only: every target is offered.
    if (areas.isEmpty) return true;

    return f.areas.any(areas.contains);
  }

  // A field with a saved value stays visible so it can be
  // cleared, even after a condition was removed.
  bool _visible(NutritionTargetField f) =>
      _relevant(f) || _controllers[f.key]!.text.trim().isNotEmpty;

  // ---- values -----------------------------------------

  double? _value(NutritionTargetField f) => NutritionTargets.parse(_controllers[f.key]!.text);

  String? _error(NutritionTargetField f) {
    final String text = _controllers[f.key]!.text.trim();

    if (text.isEmpty) return null;

    final double? v = _value(f);

    if (NutritionTargets.valid(f, v) != null) return null;

    return 'Enter ${_text(f.min)}–${_text(f.max)} ${f.unit}, or leave it empty.';
  }

  bool get _valid => NutritionTargets.fields.every((NutritionTargetField f) => _error(f) == null);

  NutritionTargets get _current {
    final NutritionTargets t = NutritionTargets();

    for (final NutritionTargetField f in NutritionTargets.fields) {
      t.setValue(f.key, NutritionTargets.valid(f, _value(f)));
    }

    return t;
  }

  bool get _hasChanges => _current != _saved;

  /// "NutriPal's guide: 45 g per meal (carb-counting guide for women)".
  String _guideText(NutritionTargetField f) {
    final DailyTargets t = _guide;

    String amount(double v) => '${NutritionAnalysisService.formatAmount(v, f.unit)} ${f.unit}';

    switch (f.key) {
      case 'carbsPerMealG':
        {
          final String why = t.carbsBasis == CarbBudgetBasis.carbCounting
              ? 'carb-counting guide for '
                  '${widget.data.genderForEnergyEstimate == 'Male' ? 'men' : 'women'}'
              : 'half of your daily energy, over 3 meals';

          return "NutriPal's guide: ${amount(t.carbsPerMealG)} per meal ($why).";
        }
      case 'proteinG':
        return 'Not set by default: protein is shown, not rated.';
      case 'fatG':
        return "NutriPal's guide: up to ${amount(t.totalFatG)} a day (30% of your energy).";
      case 'sugarsG':
        return "NutriPal's guide: under ${amount(t.freeSugarsG)} a day (10% of your energy).";
      case 'sodiumMg':
        return "NutriPal's guide: under ${amount(t.sodiumMg)} a day.";
      case 'saturatedFatG':
        return "NutriPal's guide: under ${amount(t.saturatedFatG)} a day (10% of your energy).";
      case 'fibreG':
        return "NutriPal's guide: at least ${amount(t.fibreG)} a day.";
    }

    return '';
  }

  // ---- save -------------------------------------------

  void _save() {
    if (!_valid) return;

    FocusScope.of(context).unfocus();

    final NutritionTargets targets = _current;

    widget.data.nutritionTargets = targets;

    // Saved to Firestore (works offline, sent later).
    UserProfileService.save(widget.data);

    setState(() => _saved = targets.copy());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nutrition targets updated.')),
    );
  }

  void _clear(NutritionTargetField f) {
    setState(() => _controllers[f.key]!.clear());
  }

  @override
  Widget build(BuildContext context) {
    final List<NutritionTargetField> main =
        NutritionTargets.fields.where((NutritionTargetField f) => f.isMain).toList();

    final List<NutritionTargetField> others = NutritionTargets.fields
        .where((NutritionTargetField f) => !f.isMain && _visible(f))
        .toList();

    return Scaffold(
      backgroundColor: NpColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              NpTopBar(
                title: 'Nutrition Targets',
                leading: NpCircleButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Optional. Enter the targets your doctor or dietitian gave you, '
                      "or your own. Leave a field empty to use NutriPal's guide.",
                      style: TextStyle(fontSize: 14, height: 1.45, color: NpColors.bodyInk),
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('MAIN NUTRIENTS'),
                    const SizedBox(height: 10),
                    for (final NutritionTargetField f in main) ...[
                      _field(f),
                      const SizedBox(height: 12),
                    ],
                    if (others.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _SectionTitle(_areas.isEmpty ? 'OTHER TARGETS' : 'FOR YOUR HEALTH CONDITIONS'),
                      const SizedBox(height: 10),
                      for (final NutritionTargetField f in others) ...[
                        _field(f),
                        const SizedBox(height: 12),
                      ],
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      'Daily calories are set in Weight Management Goal.',
                      style: TextStyle(fontSize: 13, color: NpColors.muted),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      npDisclaimer,
                      style: TextStyle(fontSize: 12, height: 1.4, color: NpColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              NpPrimaryButton(
                label: 'Save changes',
                onPressed: _hasChanges && _valid ? _save : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(NutritionTargetField f) {
    final TextEditingController c = _controllers[f.key]!;
    final String? error = _error(f);

    return NpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  f.label,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: NpColors.ink,
                  ),
                ),
              ),
              Text(
                f.basis,
                style: const TextStyle(fontSize: 13, color: NpColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            f.help,
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: NpColors.muted),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Not set',
              suffixText: f.unit,
              errorText: error,
              errorMaxLines: 2,
              isDense: true,
              filled: true,
              fillColor: NpColors.lilac,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: c.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _clear(f),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _guideText(f),
            style: const TextStyle(fontSize: 12.5, height: 1.35, color: NpColors.bodyInk),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: NpColors.muted,
      ),
    );
  }
}
