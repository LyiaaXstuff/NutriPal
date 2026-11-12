import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/energy_requirement.dart';
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
// Stored values: "Lose weight", "Male", and the NASEM
// activity levels ("Inactive", "Low active", "Active",
// "Very active"). Weight is kg, height cm.
//
// Energy (rules document, Layer 2): the NASEM 2023
// maintenance estimate, adjusted for a weight goal (lose
// 500 kcal less, gain 300 kcal more by default, with the
// guideline floors), or a daily figure from the user's
// doctor or dietitian ("Set by your healthcare provider").
// See GoalEnergy in services/energy_requirement.dart.
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

  /// (stored value, description, icon). The four NASEM
  /// activity levels, described in everyday words (NASEM
  /// 2023, Table 7-1). No tool can place a person exactly,
  /// so the user picks the closest one.
  static const List<(String, String, IconData)> activities = <(String, String, IconData)>[
    (ActivityLevels.inactive, 'Mostly daily activities, little extra movement', Icons.self_improvement_rounded),
    (ActivityLevels.lowActive, 'Some extra walking and light activity', Icons.directions_walk_rounded),
    (ActivityLevels.active, 'Regular movement and moderate activity', Icons.directions_run_rounded),
    (ActivityLevels.veryActive, 'Highly active lifestyle or vigorous activity', Icons.sports_handball_rounded),
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

  /// 1720.8 -> "1,720" (rounded to 10 kcal, for estimates)
  static String kcalText(double kcal) => _thousands((kcal / 10).round() * 10);

  /// 1234 -> "1,234" (exact, for a provider's figure)
  static String exactKcalText(double kcal) => _thousands(kcal.round());

  static String _thousands(int value) {
    final String digits = value.toString();
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
      return 'NutriPal uses this instead of its own estimate to judge each '
          'product’s energy for you.';
    }

    final GoalEnergyResult? g = t.goal;

    if (g != null && g.lowBmi) {
      return 'Your weight is already in the low range, so NutriPal doesn’t take '
          'calories off. Please talk to a doctor or dietitian before trying to '
          'lose weight.';
    }

    if (g != null && !g.adjusted && g.floorApplied && g.floorKcal != null) {
      return 'NutriPal doesn’t set weight-loss guides below '
          '${exactKcalText(g.floorKcal!)} kcal a day, so it uses the energy to '
          'keep your current weight. A doctor or dietitian can set a plan that '
          'suits you.';
    }

    if (g != null && g.adjusted) {
      return 'A general guide, not a prescription. NutriPal uses it to judge each '
          'product’s energy; your other limits stay based on maintenance. You can '
          'change the amount in your weight settings.';
    }

    return 'NutriPal uses this to judge each product’s energy for you.';
  }

  // ---- energy change for a weight goal -----------------

  /// "500 kcal less a day" / "300 kcal more a day", with
  /// "(default)" for the default amount.
  static String energyChangeText(String? goal, int kcal) {
    final String? key = GoalEnergy.goalKey(goal);
    final bool isDefault = (key == 'lose' && kcal == GoalEnergy.defaultLoseKcal) ||
        (key == 'gain' && kcal == GoalEnergy.defaultGainKcal);

    return '$kcal kcal ${key == 'gain' ? 'more' : 'less'} a day'
        '${isDefault ? ' (default)' : ''}';
  }

  /// The choices for this goal, or empty for maintain.
  static List<int> energyChangeOptions(String? goal) => switch (GoalEnergy.goalKey(goal)) {
        'lose' => GoalEnergy.loseOptions,
        'gain' => GoalEnergy.gainOptions,
        _ => const <int>[],
      };

  // ---- daily figure from a doctor or dietitian ---------

  static double? parseKcal(String text) {
    final String digits = text.trim().replaceAll(',', '');

    return digits.isEmpty ? null : double.tryParse(digits);
  }

  /// The accepted figure, or null when the box is empty or
  /// out of range.
  static double? providerKcal(String text) {
    final double? kcal = parseKcal(text);

    return EnergyRequirement.providerTargetOk(kcal) ? kcal : null;
  }

  /// True when the optional box is empty or holds a figure
  /// NutriPal can use.
  static bool providerTextOk(String text) =>
      text.trim().isEmpty || providerKcal(text) != null;

  static String? providerError(String text) {
    if (providerTextOk(text)) return null;

    final double? kcal = parseKcal(text);

    if (kcal != null && kcal < EnergyRequirement.providerMinimumKcal) {
      return 'NutriPal can’t use targets below 800 kcal a day. Very low calorie '
          'diets need close medical supervision.';
    }

    return 'Please enter a daily figure up to '
        '${exactKcalText(EnergyRequirement.providerMaximumKcal)} kcal.';
  }

  /// A short note for an accepted figure below the usual
  /// guideline range, else null.
  static String? providerNote(String text, String? sex) {
    final double? kcal = providerKcal(text);

    if (kcal == null || !EnergyRequirement.providerTargetIsBelowGuideline(kcal, sex)) {
      return null;
    }

    return 'This is lower than most guideline plans. NutriPal will use it '
        'because your healthcare provider set it.';
  }

  // ---- what guidelines say for each goal ----------------
  //
  // General information only, never a plan for the user
  // (the applied change is in GoalEnergy). Sources: MOH obesity CPG 2023 and ADA 2026
  // Section 8 (lose, WT-13 / WT-14 / WT-19), NHS (gain,
  // WT-08), maintenance activity (WT-02, WT-15).

  /// BMI below this hides the weight-loss ranges (WT-17).
  static const double lowBmi = 18.5;

  static double? bmi(double? weightKg, double? heightCm) {
    if (weightKg == null || heightCm == null || weightKg <= 0 || heightCm <= 0) return null;

    final double m = heightCm / 100;

    return weightKg / (m * m);
  }

  /// (text, show the "general ranges" line) for the goal,
  /// or null when there is nothing to show.
  static (String, bool)? goalGuidance({
    required String? goal,
    required String? sex,
    required double? weightKg,
    required double? heightCm,
  }) {
    if (goal == 'Lose weight') {
      final double? b = bmi(weightKg, heightCm);

      if (b != null && b < lowBmi) {
        return (
          'Your weight is already in the low range. Please talk to a doctor '
              'or dietitian before trying to lose weight.',
          false,
        );
      }

      final String range = sex == 'Male' ? '1,500–1,800' : '1,200–1,500';

      return (
        'Guidelines suggest eating 500–750 kcal a day less than usual, or about '
            '$range kcal a day, aiming to lose 0.5–1 kg a week. A doctor or '
            'dietitian can set a plan that suits you. If you take insulin or other '
            'diabetes medicines, ask your doctor before eating less.',
        true,
      );
    }

    if (goal == 'Gain weight') {
      return (
        'Guidelines suggest adding about 300–500 kcal a day, step by step, from '
            'nourishing foods such as nuts, milk, eggs, beans and fish rather than '
            'sweets or sugary drinks. If you are losing weight without trying, '
            'see a doctor.',
        true,
      );
    }

    if (goal == 'Maintain weight') {
      return (
        'Keeping your weight steady depends on your whole day. About 150 '
            'minutes of activity a week helps.',
        false,
      );
    }

    return null;
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
            selected: ActivityLevels.normalise(selected) == WeightPlanOptions.activities[i].$1,
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

  // "Estimated daily maintenance energy" or "Set by your
  // healthcare provider".
  final String label;

  // "Likely 1,850–2,330 kcal", or null.
  final String? rangeText;

  // An estimate shows "≈", a provider's figure does not.
  final bool approximate;

  const EnergyGuideCard({
    super.key,
    required this.kcalText,
    required this.note,
    this.label = 'Estimated daily maintenance energy',
    this.rangeText,
    this.approximate = true,
  });

  /// The card for these targets. [extraNote] is added
  /// after the usual note.
  factory EnergyGuideCard.fromTargets(
    DailyTargets t, {
    Key? key,
    String? goal,
    String? extraNote,
  }) {
    final bool byProvider = t.setByProvider.contains('Energy');
    final String note = WeightPlanOptions.energyNote(t, goal);
    final GoalEnergyResult? g = byProvider ? null : t.goal;

    // Lose or gain with a change applied: show the goal
    // energy and how it was worked out.
    if (g != null && g.adjusted) {
      final bool losing = g.changeKcal < 0;
      final String maintenance = WeightPlanOptions.kcalText(g.maintenanceKcal);

      return EnergyGuideCard(
        key: key,
        kcalText: WeightPlanOptions.kcalText(g.kcal),
        label: losing ? 'Daily energy guide for weight loss' : 'Daily energy guide for weight gain',
        rangeText: g.floorApplied
            ? 'Maintenance ≈ $maintenance kcal; set to the '
                '${WeightPlanOptions.exactKcalText(g.kcal)} kcal minimum'
            : 'Maintenance ≈ $maintenance kcal '
                '${losing ? '−' : '+'} ${g.requestedKcal} kcal',
        note: extraNote == null ? note : '$note $extraNote',
      );
    }

    return EnergyGuideCard(
      key: key,
      kcalText: byProvider
          ? WeightPlanOptions.exactKcalText(t.energyKcal)
          : WeightPlanOptions.kcalText(t.energyKcal),
      approximate: !byProvider,
      label: byProvider ? 'Set by your healthcare provider' : 'Estimated daily maintenance energy',
      rangeText: !byProvider && t.energyLowKcal != null && t.energyHighKcal != null
          ? 'Likely ${WeightPlanOptions.kcalText(t.energyLowKcal!)}–'
              '${WeightPlanOptions.kcalText(t.energyHighKcal!)} kcal'
          : null,
      note: extraNote == null ? note : '$note $extraNote',
    );
  }

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
                  approximate ? '≈ $kcalText kcal' : '$kcalText kcal',
                  style: const TextStyle(
                    color: Color(0xFF0B4A47),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF0B4A47),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rangeText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    rangeText!,
                    style: const TextStyle(color: Color(0xFF24514F), fontSize: 13),
                  ),
                ],
                const SizedBox(height: 6),
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

// =======================================================
// DAILY FIGURE FROM A DOCTOR OR DIETITIAN (optional)
// =======================================================

/// Optional box for a daily calorie figure from the user's
/// doctor or dietitian. When filled in, it replaces
/// NutriPal's estimate as the energy base.
class ProviderEnergyField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  // For the "lower than most guideline plans" note.
  final String? sex;

  // Larger label, like the other section titles.
  final bool labelAsSectionTitle;

  const ProviderEnergyField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.sex,
    this.labelAsSectionTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    final String text = controller.text;
    final String? error = WeightPlanOptions.providerError(text);
    final String? note = WeightPlanOptions.providerNote(text, sex);
    final bool ok = text.trim().isNotEmpty && error == null;

    final Color borderColor = error != null
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
        Row(
          children: [
            Expanded(
              child: WeightPlanLabel(
                'Calorie target from your doctor or dietitian',
                asSectionTitle: labelAsSectionTitle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Optional',
              style: TextStyle(
                color: WeightPlanColors.stepGrey,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Only fill this in if a healthcare provider gave you a daily calorie '
          'figure. NutriPal then uses it instead of its own estimate.',
          style: TextStyle(color: WeightPlanColors.muted, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          style: const TextStyle(
            color: WeightPlanColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. 1500',
            hintStyle: const TextStyle(color: Color(0xFF8A7FA3), fontWeight: FontWeight.w500),
            filled: true,
            fillColor: const Color(0xFFFBF9FE),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (text.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, color: WeightPlanColors.stepGrey, size: 20),
                  ),
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text(
                    'kcal',
                    style: TextStyle(
                      color: WeightPlanColors.stepGrey,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            enabledBorder: outline(borderColor, 1.5),
            focusedBorder: outline(error != null ? WeightPlanColors.error : WeightPlanColors.purple, 2),
            border: outline(borderColor, 1.5),
          ),
        ),
        if (error != null || note != null) ...[
          const SizedBox(height: 8),
          Text(
            error ?? note!,
            style: TextStyle(
              color: error != null ? WeightPlanColors.error : WeightPlanColors.muted,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

// =======================================================
// WHAT GUIDELINES SAY (education only)
// =======================================================

class GoalGuidanceCard extends StatelessWidget {
  final String? goal;
  final String? sex;
  final double? weightKg;
  final double? heightCm;

  const GoalGuidanceCard({
    super.key,
    required this.goal,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
  });

  @override
  Widget build(BuildContext context) {
    final (String, bool)? guidance = WeightPlanOptions.goalGuidance(
      goal: goal,
      sex: sex,
      weightKg: weightKg,
      heightCm: heightCm,
    );

    if (guidance == null) return const SizedBox.shrink();

    final (String text, bool general) = guidance;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WeightPlanColors.lilac,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: WeightPlanColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WHAT GUIDELINES SAY',
            style: TextStyle(
              color: WeightPlanColors.stepGrey,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(color: WeightPlanColors.bodyInk, fontSize: 13.5, height: 1.45),
          ),
          if (general) ...[
            const SizedBox(height: 6),
            const Text(
              'These are general guideline ranges, not a plan for you.',
              style: TextStyle(color: WeightPlanColors.muted, fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
