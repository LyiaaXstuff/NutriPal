import 'package:flutter/material.dart';

import '../models/profile_setup_data.dart';
import '../services/user_profile_service.dart';
import '../widgets/energy_details_fields.dart';
import '../widgets/weight_plan_widgets.dart';
import 'home_screen.dart';

// =======================================================
// STEP 3 · YOUR DAILY ENERGY (profile setup)
// =======================================================
//
// For a user who chose High LDL cholesterol but not weight
// management. It is the weight management step without the
// weight goal:
//
//   1. About your body  gender, weight (kg), height (cm)
//   2. Activity level   NASEM's four levels
//
// and the same optional box for a daily energy figure from
// the user's doctor or dietitian.
//
// Saturated fat and trans fat are limited as a share of the
// day's energy, so NutriPal needs the energy figure. A user
// who also chose weight management sees only the weight
// management form (setup never asks twice).
// =======================================================

class EnergyDetailsForm extends StatefulWidget {
  final ProfileSetupData data;

  const EnergyDetailsForm({
    super.key,
    required this.data,
  });

  @override
  State<EnergyDetailsForm> createState() => _EnergyDetailsFormState();
}

class _EnergyDetailsFormState extends State<EnergyDetailsForm> {
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _providerController;

  @override
  void initState() {
    super.initState();

    _normaliseUnitsToMetric();

    _weightController = TextEditingController(
      text: WeightPlanOptions.formatNumber(widget.data.currentWeight),
    );

    _heightController = TextEditingController(
      text: WeightPlanOptions.formatNumber(widget.data.height),
    );

    final double? provider = widget.data.providerEnergyKcal;

    _providerController = TextEditingController(
      text: provider == null ? '' : provider.round().toString(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _providerController.dispose();

    super.dispose();
  }

  // Older profiles may hold lb / inches: convert once.
  void _normaliseUnitsToMetric() {
    if (widget.data.weightUnit == 'lb' && widget.data.currentWeight != null) {
      widget.data.currentWeight = widget.data.currentWeight! * 0.45359237;
    }

    if (widget.data.heightUnit == 'in' && widget.data.height != null) {
      widget.data.height = widget.data.height! * 2.54;
    }

    widget.data.weightUnit = 'kg';
    widget.data.heightUnit = 'cm';
  }

  // =====================================================
  // PROGRESS
  // =====================================================

  EnergyDetails get _details => EnergyDetails.fromProfile(widget.data);

  bool get _bodyDone => _details.bodyDone;

  bool get _activityDone => _details.activityDone;

  int get _doneCount => (_bodyDone ? 1 : 0) + (_activityDone ? 1 : 0);

  bool get _allDone => _doneCount == 2;

  bool get _providerOk => WeightPlanOptions.providerTextOk(_providerController.text);

  bool get _canContinue => _allDone && _providerOk;

  // =====================================================
  // CONTINUE
  // =====================================================

  void _continue() {
    FocusScope.of(context).unfocus();

    if (!_canContinue) return;

    widget.data.weightUnit = 'kg';
    widget.data.heightUnit = 'cm';

    // No weight goal here: this user did not choose weight
    // management.
    widget.data.weightGoal = null;

    // Setup finished: save the profile to Firestore.
    UserProfileService.save(widget.data);

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(data: widget.data),
      ),
      (route) => false,
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final int left = 2 - _doneCount;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: WeightPlanColors.background,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- header (same as the other steps) ----
                SizedBox(
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.arrow_back_rounded, color: WeightPlanColors.purple, size: 28),
                        ),
                      ),
                      const Text(
                        'STEP 3',
                        style: TextStyle(
                          color: WeightPlanColors.stepGrey,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const LinearProgressIndicator(
                    value: 1,
                    minHeight: 8,
                    backgroundColor: Color(0xFFE4D9F7),
                    valueColor: AlwaysStoppedAnimation<Color>(WeightPlanColors.purple),
                  ),
                ),
                const SizedBox(height: 18),

                // ---- title -------------------------------
                const Text(
                  'Your daily energy',
                  style: TextStyle(
                    color: WeightPlanColors.ink,
                    fontSize: 24,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us a little about you so NutriPal can estimate how much energy you need each day.',
                  style: TextStyle(color: WeightPlanColors.muted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 18),

                // ---- 1. about your body ------------------
                _QuestionCard(
                  number: 1,
                  done: _bodyDone,
                  title: 'About your body',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WeightPlanLabel('Gender'),
                      const SizedBox(height: 8),
                      GenderRow(
                        selected: widget.data.genderForEnergyEstimate,
                        onChanged: (String gender) =>
                            setState(() => widget.data.genderForEnergyEstimate = gender),
                      ),
                      const SizedBox(height: 16),
                      MeasurementFields(
                        weightController: _weightController,
                        heightController: _heightController,
                        onWeightChanged: (String v) =>
                            setState(() => widget.data.currentWeight = WeightPlanOptions.parse(v)),
                        onHeightChanged: (String v) =>
                            setState(() => widget.data.height = WeightPlanOptions.parse(v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- 2. activity -------------------------
                _QuestionCard(
                  number: 2,
                  done: _activityDone,
                  title: 'How active are you?',
                  child: ActivityList(
                    selected: widget.data.activityLevel,
                    onChanged: (String a) => setState(() => widget.data.activityLevel = a),
                  ),
                ),

                // ---- optional: provider's figure ---------
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: WeightPlanColors.cardBorder),
                  ),
                  child: ProviderEnergyField(
                    controller: _providerController,
                    sex: widget.data.genderForEnergyEstimate,
                    onChanged: (String v) => setState(
                      () => widget.data.providerEnergyKcal = WeightPlanOptions.providerKcal(v),
                    ),
                  ),
                ),

                // ---- energy guide ------------------------
                if (_allDone) ...[
                  const SizedBox(height: 14),
                  EnergyDetailsGuideCard(
                    details: EnergyDetails(
                      sex: widget.data.genderForEnergyEstimate,
                      weightKg: widget.data.currentWeight,
                      heightCm: widget.data.height,
                      activity: widget.data.activityLevel,
                      providerText: _providerController.text,
                    ),
                    dateOfBirth: widget.data.dateOfBirth,
                  ),
                ],
              ],
            ),
          ),
        ),

        // ---- footer: progress + continue ---------------
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: WeightPlanColors.background,
              border: Border(top: BorderSide(color: WeightPlanColors.cardBorder)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    for (final bool done in <bool>[_bodyDone, _activityDone])
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: done ? WeightPlanColors.doneTeal : const Color(0xFFE4D9F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '$_doneCount of 2 done',
                      style: const TextStyle(
                        color: WeightPlanColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canContinue ? _continue : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WeightPlanColors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFDCD3EC),
                      disabledForegroundColor: const Color(0xFF4F4268),
                      elevation: _canContinue ? 4 : 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      _allDone
                          ? (_providerOk ? 'Submit' : 'Check the energy target')
                          : left == 1
                              ? 'Answer 1 more question'
                              : 'Answer $left more questions',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// QUESTION CARD (number turns into a tick when answered)
// =======================================================

class _QuestionCard extends StatelessWidget {
  final int number;
  final bool done;
  final String title;
  final Widget child;

  const _QuestionCard({
    required this.number,
    required this.done,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: done ? WeightPlanColors.doneBorder : WeightPlanColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? WeightPlanColors.doneTeal : WeightPlanColors.purple,
                ),
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 18, semanticLabel: 'Answered')
                    : Text(
                        '$number',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: WeightPlanColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
