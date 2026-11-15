import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import 'weight_plan_widgets.dart';

// =======================================================
// ENERGY DETAILS (users with High LDL cholesterol but no
// weight management)
// =======================================================
//
// Saturated fat and trans fat limits are a share of the
// day's energy (under 10 % and under 1 %), so a user with
// High LDL cholesterol needs an energy figure too. This is
// the weight management form without the weight goal:
//
//   gender, current weight, height, activity level, and an
//   optional daily energy figure from a doctor or
//   dietitian.
//
// A user who chose weight management answers the weight
// management form instead, so nobody is asked twice.
//
// Used by:
//   Setup, Step 3         screens/energy_details_form.dart
//   Profile > Daily       screens/daily_energy_estimation_screen.dart
//   Energy Estimation
//   Profile > Health      the pop-up from [EnergyDetailsSheet]
//   Conditions > LDL
// =======================================================

/// What the user entered. [providerText] is the raw text of
/// the optional calorie box (empty or valid is fine).
class EnergyDetails {
  final String? sex;
  final double? weightKg;
  final double? heightCm;
  final String? activity;
  final String providerText;

  const EnergyDetails({
    this.sex,
    this.weightKg,
    this.heightCm,
    this.activity,
    this.providerText = '',
  });

  bool get bodyDone =>
      sex != null && WeightPlanOptions.weightOk(weightKg) && WeightPlanOptions.heightOk(heightCm);

  bool get activityDone => activity != null;

  bool get providerOk => WeightPlanOptions.providerTextOk(providerText);

  /// Everything answered and the optional box valid.
  bool get complete => bodyDone && activityDone && providerOk;

  double? get providerKcal => WeightPlanOptions.providerKcal(providerText);

  /// What the profile already holds.
  factory EnergyDetails.fromProfile(ProfileSetupData d) => EnergyDetails(
        sex: d.genderForEnergyEstimate,
        weightKg: d.currentWeight,
        heightCm: d.height,
        activity: d.activityLevel,
        providerText: d.providerEnergyKcal == null ? '' : d.providerEnergyKcal!.round().toString(),
      );

  /// True when [d] already holds all four answers, so the
  /// user does not need to be asked.
  static bool profileHasDetails(ProfileSetupData d) => EnergyDetails.fromProfile(d).bodyDone && d.activityLevel != null;

  /// Writes the answers into the profile (kg and cm).
  void applyTo(ProfileSetupData d) {
    d.genderForEnergyEstimate = sex;
    d.currentWeight = weightKg;
    d.height = heightCm;
    d.activityLevel = activity;
    d.providerEnergyKcal = providerKcal;
    d.weightUnit = 'kg';
    d.heightUnit = 'cm';
  }

  /// Removes the answers (no area needs them any more).
  static void clearFrom(ProfileSetupData d) {
    d.genderForEnergyEstimate = null;
    d.currentWeight = null;
    d.height = null;
    d.activityLevel = null;
    d.providerEnergyKcal = null;
    d.weightUnit = 'kg';
    d.heightUnit = 'cm';
  }
}

// =======================================================
// ENERGY GUIDE CARD (no weight goal)
// =======================================================

class EnergyDetailsGuideCard extends StatelessWidget {
  final EnergyDetails details;
  final DateTime? dateOfBirth;

  const EnergyDetailsGuideCard({
    super.key,
    required this.details,
    required this.dateOfBirth,
  });

  @override
  Widget build(BuildContext context) {
    if (!details.complete) return const SizedBox.shrink();

    final DailyTargets? t = WeightPlanOptions.energyTargets(
      ProfileSetupData(
        dateOfBirth: dateOfBirth,
        genderForEnergyEstimate: details.sex,
        currentWeight: details.weightKg,
        height: details.heightCm,
        activityLevel: details.activity,
        providerEnergyKcal: details.providerKcal,
      ),
    );

    if (t == null) return const SizedBox.shrink();

    final bool byProvider = t.setByProvider.contains('Energy');

    return EnergyGuideCard(
      kcalText: byProvider
          ? WeightPlanOptions.exactKcalText(t.energyKcal)
          : WeightPlanOptions.kcalText(t.energyKcal),
      approximate: !byProvider,
      label: byProvider ? 'Your own energy target' : 'Estimated daily energy',
      rangeText: !byProvider && t.energyLowKcal != null && t.energyHighKcal != null
          ? 'Likely ${WeightPlanOptions.kcalText(t.energyLowKcal!)}–'
              '${WeightPlanOptions.kcalText(t.energyHighKcal!)} kcal'
          : null,
      note: byProvider
          ? 'NutriPal uses this to work out your saturated fat and trans fat '
              'limits (under 10% and under 1% of daily energy).'
          : 'A general guide, not a prescription. NutriPal uses it to work out '
              'your saturated fat and trans fat limits (under 10% and under 1% '
              'of daily energy).',
    );
  }
}

// =======================================================
// FIELDS (section-title style, used in the pop-up and in
// the Profile screen)
// =======================================================

class EnergyDetailsFields extends StatefulWidget {
  final EnergyDetails initial;
  final DateTime? dateOfBirth;
  final ValueChanged<EnergyDetails> onChanged;

  const EnergyDetailsFields({
    super.key,
    required this.initial,
    required this.dateOfBirth,
    required this.onChanged,
  });

  @override
  State<EnergyDetailsFields> createState() => _EnergyDetailsFieldsState();
}

class _EnergyDetailsFieldsState extends State<EnergyDetailsFields> {
  late String? _sex = widget.initial.sex;
  late String? _activity = widget.initial.activity;

  late final TextEditingController _weightController =
      TextEditingController(text: WeightPlanOptions.formatNumber(widget.initial.weightKg));

  late final TextEditingController _heightController =
      TextEditingController(text: WeightPlanOptions.formatNumber(widget.initial.heightCm));

  late final TextEditingController _providerController =
      TextEditingController(text: widget.initial.providerText);

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  EnergyDetails get _details => EnergyDetails(
        sex: _sex,
        weightKg: WeightPlanOptions.parse(_weightController.text),
        heightCm: WeightPlanOptions.parse(_heightController.text),
        activity: _activity,
        providerText: _providerController.text,
      );

  void _changed() {
    setState(() {});
    widget.onChanged(_details);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WeightPlanLabel('Gender', asSectionTitle: true),
        const SizedBox(height: 10),
        GenderRow(
          selected: _sex,
          onChanged: (String v) {
            _sex = v;
            _changed();
          },
        ),
        const SizedBox(height: 18),
        MeasurementFields(
          weightController: _weightController,
          heightController: _heightController,
          onWeightChanged: (_) => _changed(),
          onHeightChanged: (_) => _changed(),
          labelsAsSectionTitles: true,
        ),
        const SizedBox(height: 22),
        const WeightPlanLabel('Activity level', asSectionTitle: true),
        const SizedBox(height: 10),
        ActivityList(
          selected: _activity,
          onChanged: (String v) {
            _activity = v;
            _changed();
          },
        ),
        const SizedBox(height: 22),
        ProviderEnergyField(
          controller: _providerController,
          sex: _sex,
          onChanged: (_) => _changed(),
          labelAsSectionTitle: true,
        ),
        const SizedBox(height: 18),
        EnergyDetailsGuideCard(details: _details, dateOfBirth: widget.dateOfBirth),
      ],
    );
  }
}

// =======================================================
// POP-UP (Profile > Health Conditions > High LDL
// cholesterol, when weight management is not selected)
// =======================================================

class EnergyDetailsSheet {
  EnergyDetailsSheet._();

  /// Returns the answers when the user taps Done, or null
  /// when the pop-up is closed. Nothing is saved here.
  static Future<EnergyDetails?> show(
    BuildContext context, {
    required EnergyDetails initial,
    required DateTime? dateOfBirth,
  }) {
    return showModalBottomSheet<EnergyDetails>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _EnergyDetailsSheetBody(
        initial: initial,
        dateOfBirth: dateOfBirth,
      ),
    );
  }
}

class _EnergyDetailsSheetBody extends StatefulWidget {
  final EnergyDetails initial;
  final DateTime? dateOfBirth;

  const _EnergyDetailsSheetBody({required this.initial, required this.dateOfBirth});

  @override
  State<_EnergyDetailsSheetBody> createState() => _EnergyDetailsSheetBodyState();
}

class _EnergyDetailsSheetBodyState extends State<_EnergyDetailsSheetBody> {
  late EnergyDetails _details = widget.initial;

  @override
  Widget build(BuildContext context) {
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bool complete = _details.complete;

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.9,
          decoration: const BoxDecoration(
            color: WeightPlanColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4D9F7),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Daily energy estimation',
                        style: TextStyle(
                          color: WeightPlanColors.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: WeightPlanColors.purple, size: 28),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + keyboard),
                  child: EnergyDetailsFields(
                    initial: widget.initial,
                    dateOfBirth: widget.dateOfBirth,
                    onChanged: (EnergyDetails d) => setState(() => _details = d),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: WeightPlanColors.cardBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: complete ? () => Navigator.pop(context, _details) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WeightPlanColors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFDCD3EC),
                      disabledForegroundColor: const Color(0xFF4F4268),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      complete ? 'Done' : 'Complete all details',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
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
