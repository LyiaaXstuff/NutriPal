import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/user_profile_service.dart';
import '../widgets/weight_plan_widgets.dart';
import 'home_screen.dart';

// =======================================================
// STEP 3 · YOUR WEIGHT PLAN (profile setup)
// =======================================================
//
// Three questions, each in its own card:
//
//   1. Weight goal      Lose / Maintain / Gain
//   2. About your body  gender, weight (kg), height (cm)
//   3. Activity level   NASEM's four levels
//
// Then one optional box: a daily calorie figure from the
// user's doctor or dietitian. When filled in it replaces
// NutriPal's estimate (shown as "Set by your healthcare
// provider"). It is not one of the three questions.
//
// Each card's number turns into a tick when answered. The
// footer shows progress and Continue only works once all
// three are answered (no error pop-ups). When everything
// is filled in, "Your daily energy guide" shows the energy
// target NutriPal will use, from the same calculation as
// the nutrition analysis.
//
// The tiles and fields are shared with Profile > Health
// Conditions > Weight management (weight_plan_widgets.dart).
// =======================================================

class WeightManagementForm extends StatefulWidget {
  final ProfileSetupData data;

  const WeightManagementForm({
    super.key,
    required this.data,
  });

  @override
  State<WeightManagementForm> createState() => _WeightManagementFormState();
}

class _WeightManagementFormState extends State<WeightManagementForm> {
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _providerController;

  // =====================================================
  // INIT / DISPOSE
  // =====================================================

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

  // Older profiles may hold lb / inches: convert once, so
  // the screen only ever shows kg and cm.
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

  bool get _goalDone => widget.data.weightGoal != null;

  bool get _bodyDone =>
      widget.data.genderForEnergyEstimate != null &&
      WeightPlanOptions.weightOk(widget.data.currentWeight) &&
      WeightPlanOptions.heightOk(widget.data.height);

  bool get _activityDone => widget.data.activityLevel != null;

  int get _doneCount => (_goalDone ? 1 : 0) + (_bodyDone ? 1 : 0) + (_activityDone ? 1 : 0);

  bool get _allDone => _doneCount == 3;

  // The optional provider box must be empty or valid.
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
    final DailyTargets? targets = _allDone ? WeightPlanOptions.energyTargets(widget.data) : null;
    final int left = 3 - _doneCount;

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
                  'Your weight plan',
                  style: TextStyle(
                    color: WeightPlanColors.ink,
                    fontSize: 32,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Three quick questions so NutriPal can estimate how much energy you need each day.',
                  style: TextStyle(color: WeightPlanColors.muted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 18),

                // ---- 1. weight goal ----------------------
                _QuestionCard(
                  number: 1,
                  done: _goalDone,
                  title: 'What is your weight goal?',
                  child: WeightGoalRow(
                    selected: widget.data.weightGoal,
                    onChanged: (String goal) => setState(() => widget.data.weightGoal = goal),
                  ),
                ),
                const SizedBox(height: 14),

                // ---- 2. about your body ------------------
                _QuestionCard(
                  number: 2,
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

                // ---- 3. activity -------------------------
                _QuestionCard(
                  number: 3,
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
                if (targets != null) ...[
                  const SizedBox(height: 14),
                  EnergyGuideCard.fromTargets(
                    targets,
                    goal: widget.data.weightGoal,
                    extraNote: 'You can change your details in Profile.',
                  ),
                  const SizedBox(height: 14),
                  GoalGuidanceCard(
                    goal: widget.data.weightGoal,
                    sex: widget.data.genderForEnergyEstimate,
                    weightKg: widget.data.currentWeight,
                    heightCm: widget.data.height,
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
                    for (final bool done in <bool>[_goalDone, _bodyDone, _activityDone])
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
                      '$_doneCount of 3 done',
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
                          ? (_providerOk ? 'Continue' : 'Check the calorie target')
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
