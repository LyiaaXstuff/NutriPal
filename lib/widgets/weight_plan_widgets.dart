import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/nutrition_analysis_service.dart';

// =======================================================
// WEIGHT PLAN WIDGETS
// =======================================================
//
// Shared by the two places that ask for weight details,
// so they always look and behave the same:
//
//   Setup, Step 3           screens/weight_management_form.dart
//   Profile > Health        screens/health_conditions_settings.dart
//   Conditions > Weight     (Weight management sheet)
//   management
//
// Stored values are the app's existing ones ("Lose weight",
// "Male", "Lightly active"...). Weight is kg, height cm.
// =======================================================

class WeightPlanColors {
  WeightPlanColors._();

  static const Color background = Color(0xFFF7F2E9);
  static const Color purple = Color(0xFF4B2E83);
  static const Color ink = Color(0xFF38138C);
  static const Color bodyInk = Color(0xFF3A2668);
  static const Color muted = Color(0xFF5E5272);
  static const Color stepGrey = Color(0xFF67558E);
  static const Color lilac = Color(0xFFF3ECFF);
  static const Color border = Color(0xFFDCCFF0);
  static const Color cardBorder = Color(0xFFE7DDF3);
  static const Color doneTeal = Color(0xFF0F8F8A);
  static const Color doneBorder = Color(0xFFB5E4E1);
  static const Color error = Color(0xFFB3261E);
}

class WeightPlanOptions {
  WeightPlanOptions._();

  /// (stored value, tile label, icon)
  static const List<(String, String, IconData)> goals = <(String, String, IconData)>[
    ('Lose weight', 'Lose\nweight', Icons.trending_down_rounded),
    ('Maintain weight', 'Maintain\nweight', Icons.drag_handle_rounded),
    ('Gain weight', 'Gain\nweight', Icons.trending_up_rounded),
  ];

  /// (stored value, description, icon)
  static const List<(String, String, IconData)> activities = <(String, String, IconData)>[
    ('Sedentary', 'Mostly sitting, little exercise', Icons.self_improvement_rounded),
    ('Lightly active', 'Light exercise 1–3 days a week', Icons.directions_walk_rounded),
    ('Moderately active', 'Moderate exercise 3–5 days a week', Icons.directions_run_rounded),
    ('Very active', 'Hard exercise 6–7 days a week', Icons.sports_handball_rounded),
  ];

  static const double minWeightKg = 20;
  static const double maxWeightKg = 300;
  static const double minHeightCm = 100;
  static const double maxHeightCm = 250;

  static double? parse(String text) => double.tryParse(text.trim().replaceAll(',', '.'));

  static bool weightOk(double? kg) => kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  static bool heightOk(double? cm) => cm != null && cm >= minHeightCm && cm <= maxHeightCm;

  /// Message under the weight / height boxes once an
  /// out-of-range number has been typed, else null.
  static String? measurementError(String weightText, String heightText) {
    if (weightText.trim().isNotEmpty && !weightOk(parse(weightText))) {
      return 'Please enter a weight between ${minWeightKg.toInt()} and ${maxWeightKg.toInt()} kg.';
    }

    if (heightText.trim().isNotEmpty && !heightOk(parse(heightText))) {
      return 'Please enter a height between ${minHeightCm.toInt()} and ${maxHeightCm.toInt()} cm.';
    }

    return null;
  }

  static String formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();

    return value.toStringAsFixed(1);
  }

  /// The daily energy target NutriPal will use (same
  /// calculation as the nutrition analysis), or null when
  /// it cannot be personalised (for example no birthday).
  static DailyTargets? energyTargets(ProfileSetupData data) {
    final DailyTargets t =
        NutritionAnalysisService.targetsFor(NutritionProfile.fromSetupData(data));

    return t.energyIsPersonal ? t : null;
  }

  /// 1720.8 -> "1,720"
  static String kcalText(double kcal) {
    final String digits = ((kcal / 10).round() * 10).toString();
    final StringBuffer out = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }

    return out.toString();
  }

  /// The line under the energy number.
  static String energyNote(DailyTargets t, String? goal) {
    if (t.setByProvider.contains('Energy')) {
      return 'Set by your doctor or dietitian. NutriPal uses this to judge each '
          'product’s energy for you.';
    }

    return '${goal == 'Lose weight' ? 'Includes a gentle 500 kcal deficit. ' : ''}'
        'NutriPal uses this to judge each product’s energy for you.';
  }
}

// =======================================================
// LABEL
// =======================================================

class WeightPlanLabel extends StatelessWidget {
  final String text;

  // Larger, like a section title (Weight goal, Gender,
  // Activity level in the Weight management sheet).
  final bool asSectionTitle;

  const WeightPlanLabel(this.text, {super.key, this.asSectionTitle = false});

  static const TextStyle sectionTitleStyle = TextStyle(
    color: WeightPlanColors.ink,
    fontSize: 17,
    fontWeight: FontWeight.w800,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: asSectionTitle
          ? sectionTitleStyle
          : const TextStyle(
              color: WeightPlanColors.bodyInk,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
    );
  }
}

// =======================================================
// CHOICE TILES
// =======================================================

/// Purple when selected, white with a border otherwise.
class _ChoiceSurface extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final Color selectedColor;

  const _ChoiceSurface({
    required this.selected,
    required this.onTap,
    required this.child,
    this.selectedColor = WeightPlanColors.purple,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedColor : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? WeightPlanColors.purple : WeightPlanColors.border,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// Lose / Maintain / Gain, in a row of three.
class WeightGoalRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const WeightGoalRow({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < WeightPlanOptions.goals.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _GoalTile(
              label: WeightPlanOptions.goals[i].$2,
              icon: WeightPlanOptions.goals[i].$3,
              selected: selected == WeightPlanOptions.goals[i].$1,
              onTap: () => onChanged(WeightPlanOptions.goals[i].$1),
            ),
          ),
        ],
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceSurface(
      selected: selected,
      onTap: onTap,
      child: SizedBox(
        height: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: selected ? Colors.white : WeightPlanColors.purple),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : WeightPlanColors.bodyInk,
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Male / Female, side by side.
class GenderRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const GenderRow({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _GenderTile(
            label: 'Male',
            icon: Icons.male_rounded,
            selected: selected == 'Male',
            onTap: () => onChanged('Male'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _GenderTile(
            label: 'Female',
            icon: Icons.female_rounded,
            selected: selected == 'Female',
            onTap: () => onChanged('Female'),
          ),
        ),
      ],
    );
  }
}

class _GenderTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _GenderTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceSurface(
      selected: selected,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 24, color: selected ? Colors.white : WeightPlanColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : WeightPlanColors.bodyInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _Radio(selected: selected, onDark: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four activity levels as a full-width list.
class ActivityList extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const ActivityList({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < WeightPlanOptions.activities.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _ActivityTile(
            label: WeightPlanOptions.activities[i].$1,
            description: WeightPlanOptions.activities[i].$2,
            icon: WeightPlanOptions.activities[i].$3,
            selected: selected == WeightPlanOptions.activities[i].$1,
            onTap: () => onChanged(WeightPlanOptions.activities[i].$1),
          ),
        ],
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityTile({
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ChoiceSurface(
      selected: selected,
      onTap: onTap,
      selectedColor: WeightPlanColors.lilac,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? WeightPlanColors.purple : WeightPlanColors.lilac,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : WeightPlanColors.purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: WeightPlanColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(color: WeightPlanColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Radio(selected: selected, onDark: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  final bool selected;

  // White ring on a purple tile; purple ring on a light one.
  final bool onDark;

  const _Radio({required this.selected, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final Color on = onDark ? Colors.white : WeightPlanColors.purple;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? on : const Color(0xFFB9AED0), width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: on),
            )
          : null,
    );
  }
}

// =======================================================
// WEIGHT + HEIGHT FIELDS (kg / cm only)
// =======================================================

/// Weight and height side by side, with the range message
/// underneath when a number is out of range.
class MeasurementFields extends StatelessWidget {
  final TextEditingController weightController;
  final TextEditingController heightController;
  final ValueChanged<String> onWeightChanged;
  final ValueChanged<String> onHeightChanged;

  // "Current weight" / "Height" styled as section titles.
  final bool labelsAsSectionTitles;

  const MeasurementFields({
    super.key,
    required this.weightController,
    required this.heightController,
    required this.onWeightChanged,
    required this.onHeightChanged,
    this.labelsAsSectionTitles = false,
  });

  @override
  Widget build(BuildContext context) {
    final String w = weightController.text;
    final String h = heightController.text;
    final String? error = WeightPlanOptions.measurementError(w, h);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _MeasureField(
                label: 'Current weight',
                hint: 'e.g. 65',
                unit: 'kg',
                controller: weightController,
                ok: WeightPlanOptions.weightOk(WeightPlanOptions.parse(w)),
                invalid: w.trim().isNotEmpty && !WeightPlanOptions.weightOk(WeightPlanOptions.parse(w)),
                onChanged: onWeightChanged,
                labelAsSectionTitle: labelsAsSectionTitles,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MeasureField(
                label: 'Height',
                hint: 'e.g. 158',
                unit: 'cm',
                controller: heightController,
                ok: WeightPlanOptions.heightOk(WeightPlanOptions.parse(h)),
                invalid: h.trim().isNotEmpty && !WeightPlanOptions.heightOk(WeightPlanOptions.parse(h)),
                onChanged: onHeightChanged,
                labelAsSectionTitle: labelsAsSectionTitles,
              ),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(color: WeightPlanColors.error, fontSize: 13, height: 1.3),
          ),
        ],
      ],
    );
  }
}

class _MeasureField extends StatelessWidget {
  final String label;
  final String hint;
  final String unit;
  final TextEditingController controller;
  final bool ok;
  final bool invalid;
  final ValueChanged<String> onChanged;
  final bool labelAsSectionTitle;

  const _MeasureField({
    required this.label,
    required this.hint,
    required this.unit,
    required this.controller,
    required this.ok,
    required this.invalid,
    required this.onChanged,
    this.labelAsSectionTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = invalid
        ? WeightPlanColors.error
        : ok
            ? WeightPlanColors.purple
            : WeightPlanColors.border;

    OutlineInputBorder outline(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeightPlanLabel(label, asSectionTitle: labelAsSectionTitle),
        SizedBox(height: labelAsSectionTitle ? 10 : 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: <TextInputFormatter>[
            // Up to 3 digits and 1 decimal place, e.g. 65.5
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d?)?')),
          ],
          style: const TextStyle(
            color: WeightPlanColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF8A7FA3), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: const Color(0xFFFBF9FE),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            // Always visible (suffixText only shows while
            // the box is focused or has a value).
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                unit,
                style: const TextStyle(
                  color: WeightPlanColors.stepGrey,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            enabledBorder: outline(borderColor, 1.5),
            focusedBorder: outline(invalid ? WeightPlanColors.error : WeightPlanColors.purple, 2),
            border: outline(borderColor, 1.5),
          ),
        ),
      ],
    );
  }
}

// =======================================================
// YOUR DAILY ENERGY GUIDE
// =======================================================

class EnergyGuideCard extends StatelessWidget {
  final String kcalText;
  final String note;

  const EnergyGuideCard({super.key, required this.kcalText, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WeightPlanColors.doneBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF0E6F6B), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR DAILY ENERGY GUIDE',
                  style: TextStyle(
                    color: Color(0xFF0E5E5A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '≈ $kcalText kcal',
                  style: const TextStyle(
                    color: Color(0xFF0B4A47),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(color: Color(0xFF24514F), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
