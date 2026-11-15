import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/user_profile_service.dart';
import '../widgets/energy_details_fields.dart';
import '../widgets/weight_plan_widgets.dart';

class HealthConditionsSettings extends StatefulWidget {
  final ProfileSetupData data;

  const HealthConditionsSettings({
    super.key,
    required this.data,
  });

  @override
  State<HealthConditionsSettings> createState() =>
      _HealthConditionsSettingsState();
}

class _HealthConditionsSettingsState
    extends State<HealthConditionsSettings> {
  // =====================================================
  // COLOURS
  // =====================================================

  static const Color backgroundColor =
      Color(0xFFF7F2E9);

  static const Color primaryPurple =
      Color(0xFF4B2E83);

  static const Color darkPurple =
      Color(0xFF38138C);

  static const Color mediumPurple =
      Color(0xFF67558E);

  static const Color lightPurple =
      Color(0xFFE4D9F7);

  // =====================================================
  // CURRENT VALUES
  // =====================================================

  late bool _diabetes;
  late bool _hypertension;
  late bool _highCholesterol;
  late bool _weightManagement;

  String? _weightGoal;
  String? _gender;

  double? _currentWeight;
  double? _height;
  double? _providerEnergyKcal;

  String? _activityLevel;

  // =====================================================
  // ORIGINAL VALUES
  // =====================================================

  late bool _originalDiabetes;
  late bool _originalHypertension;
  late bool _originalHighCholesterol;
  late bool _originalWeightManagement;

  String? _originalWeightGoal;
  String? _originalGender;

  double? _originalCurrentWeight;
  double? _originalHeight;
  double? _originalProviderEnergyKcal;

  String? _originalActivityLevel;

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _loadValues();
  }

  void _loadValues() {
    _diabetes =
        widget.data.diabetes;

    _hypertension =
        widget.data.hypertension;

    _highCholesterol =
        widget.data.highCholesterol;

    _weightManagement =
        widget.data.weightManagement;

    _weightGoal =
        widget.data.weightGoal;

    _gender =
        widget.data.genderForEnergyEstimate;

    _currentWeight =
        widget.data.currentWeight;

    _height =
        widget.data.height;

    _activityLevel =
        widget.data.activityLevel;

    _providerEnergyKcal =
        widget.data.providerEnergyKcal;

    _originalDiabetes =
        _diabetes;

    _originalHypertension =
        _hypertension;

    _originalHighCholesterol =
        _highCholesterol;

    _originalWeightManagement =
        _weightManagement;

    _originalWeightGoal =
        _weightGoal;

    _originalGender =
        _gender;

    _originalCurrentWeight =
        _currentWeight;

    _originalHeight =
        _height;

    _originalActivityLevel =
        _activityLevel;

    _originalProviderEnergyKcal =
        _providerEnergyKcal;
  }

  // =====================================================
  // CHANGES
  // =====================================================

  bool get _hasChanges {
    return _diabetes !=
            _originalDiabetes ||
        _hypertension !=
            _originalHypertension ||
        _highCholesterol !=
            _originalHighCholesterol ||
        _weightManagement !=
            _originalWeightManagement ||
        _weightGoal !=
            _originalWeightGoal ||
        _gender !=
            _originalGender ||
        _currentWeight !=
            _originalCurrentWeight ||
        _height !=
            _originalHeight ||
        _activityLevel !=
            _originalActivityLevel ||
        _providerEnergyKcal !=
            _originalProviderEnergyKcal;
  }

  // =====================================================
  // SUBTITLES
  // =====================================================

  String? get _weightSubtitle {
    if (!_weightManagement) {
      return null;
    }

    return _weightGoal;
  }

  // =====================================================
  // DIABETES (no follow-up questions)
  // =====================================================

  void _handleDiabetesTap() {
    setState(() {
      _diabetes =
          !_diabetes;
    });
  }

  // =====================================================
  // HYPERTENSION
  // =====================================================

  void _handleHypertensionTap() {
    setState(() {
      _hypertension =
          !_hypertension;
    });
  }

  // =====================================================
  // HIGH LDL CHOLESTEROL
  // =====================================================
  //
  // Saturated fat and trans fat are limited as a share of
  // daily energy, so without weight management (which asks
  // the same details) a pop-up asks gender, weight, height,
  // activity level and the optional calorie figure. It is
  // not asked again when weight management is selected or
  // the details are already there.

  // Weight management, or these details, already hold what
  // the energy estimate needs.
  bool get _hasEnergyDetails =>
      _weightManagement ||
      EnergyDetails(
            sex: _gender,
            weightKg: _currentWeight,
            heightCm: _height,
            activity: _activityLevel,
          ).bodyDone &&
          _activityLevel != null;

  Future<void> _handleCholesterolTap() async {
    if (_highCholesterol) {
      setState(() {
        _highCholesterol =
            false;
      });

      return;
    }

    if (_hasEnergyDetails) {
      setState(() {
        _highCholesterol =
            true;
      });

      return;
    }

    await _showEnergyDetailsSheet();
  }

  // The pencil on the LDL card (only when weight management
  // is off; weight management edits these in its own sheet).
  Future<void> _editEnergyDetails() async {
    await _showEnergyDetailsSheet();
  }

  Future<void> _showEnergyDetailsSheet() async {
    final EnergyDetails? result = await EnergyDetailsSheet.show(
      context,
      initial: EnergyDetails(
        sex: _gender,
        weightKg: _currentWeight,
        heightCm: _height,
        activity: _activityLevel,
        providerText: _providerEnergyKcal == null ? '' : _providerEnergyKcal!.round().toString(),
      ),
      dateOfBirth: widget.data.dateOfBirth,
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _gender = result.sex;
      _currentWeight = result.weightKg;
      _height = result.heightCm;
      _activityLevel = result.activity;
      _providerEnergyKcal = result.providerKcal;
      _highCholesterol = true;
    });
  }

  // =====================================================
  // WEIGHT MANAGEMENT
  // =====================================================

  Future<void>
      _handleWeightManagementTap() async {
    if (_weightManagement) {
      setState(() {
        _weightManagement =
            false;
      });

      return;
    }

    await _showWeightManagementSheet();
  }

  Future<void>
      _editWeightManagement() async {
    await _showWeightManagementSheet();
  }

  // =====================================================
  // WEIGHT MANAGEMENT SHEET
  // =====================================================
  //
  // Same tiles and fields as setup Step 3
  // (weight_plan_widgets.dart). Nothing changes until the
  // user taps Done; the main screen's "Save changes" then
  // saves it.

  Future<void> _showWeightManagementSheet() async {
    final _WeightSheetResult? result =
        await showModalBottomSheet<_WeightSheetResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) => _WeightManagementSheet(
        goal: _weightGoal,
        sex: _gender,
        weightKg: _currentWeight,
        heightCm: _height,
        activity: _activityLevel,
        dateOfBirth: widget.data.dateOfBirth,
        providerEnergyKcal: _providerEnergyKcal,
        diabetes: _diabetes,
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _weightGoal = result.goal;
      _gender = result.sex;
      _currentWeight = result.weightKg;
      _height = result.heightCm;
      _activityLevel = result.activity;
      _providerEnergyKcal = result.providerEnergyKcal;
      _weightManagement = true;
    });
  }

  // =====================================================
  // VALIDATION
  // =====================================================

  bool _validate() {
    // Only weight management has details to complete.
    if (_weightManagement &&
        (_weightGoal ==
                null ||
            _gender ==
                null ||
            _currentWeight ==
                null ||
            _height ==
                null ||
            _activityLevel ==
                null)) {
      _showMessage(
        'Please complete your weight management details.',
      );

      return false;
    }

    // High LDL cholesterol without weight management needs
    // the energy details (no goal).
    if (_highCholesterol && !_weightManagement && !_hasEnergyDetails) {
      _showMessage(
        'Please complete your daily energy details.',
      );

      return false;
    }

    return true;
  }

  // =====================================================
  // SAVE
  // =====================================================

  void _saveChanges() {
    if (!_validate()) {
      return;
    }

    widget.data.diabetes =
        _diabetes;

    widget.data.hypertension =
        _hypertension;

    widget.data.highCholesterol =
        _highCholesterol;

    widget.data.weightManagement =
        _weightManagement;

    // Without weight management there is no weight goal;
    // without an area that needs them, no energy details.
    if (!_weightManagement) {
      _weightGoal = null;
    }

    if (!_weightManagement && !_highCholesterol) {
      _gender = null;
      _currentWeight = null;
      _height = null;
      _activityLevel = null;
      _providerEnergyKcal = null;
    }

    widget.data.weightGoal =
        _weightGoal;

    widget.data.genderForEnergyEstimate =
        _gender;

    widget.data.currentWeight =
        _currentWeight;

    widget.data.height =
        _height;

    widget.data.activityLevel =
        _activityLevel;

    widget.data.providerEnergyKcal =
        _providerEnergyKcal;

    widget.data.weightUnit =
        'kg';

    widget.data.heightUnit =
        'cm';

    widget.data.generalNutrition =
        !_diabetes &&
            !_hypertension &&
            !_highCholesterol &&
            !_weightManagement;

    // Saved to Firestore (works offline, sent later).
    UserProfileService.save(widget.data);

    setState(() {
      _originalDiabetes =
          _diabetes;

      _originalHypertension =
          _hypertension;

      _originalHighCholesterol =
          _highCholesterol;

      _originalWeightManagement =
          _weightManagement;

      _originalWeightGoal =
          _weightGoal;

      _originalGender =
          _gender;

      _originalCurrentWeight =
          _currentWeight;

      _originalHeight =
          _height;

      _originalActivityLevel =
          _activityLevel;

      _originalProviderEnergyKcal =
          _providerEnergyKcal;
    });

    _showMessage(
      'Health conditions updated.',
    );
  }

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(
          message,
        ),

        backgroundColor:
            primaryPurple,

        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =====================================================
  // MAIN BUILD
  // =====================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          backgroundColor,

      body:
          SafeArea(
        bottom:
            false,

        child:
            SingleChildScrollView(
          physics:
              const ClampingScrollPhysics(),

          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            120,
          ),

          child:
              Column(
            children: [
              // =================================================
              // HEADER
              // =================================================

              SizedBox(
                height:
                    48,

                child:
                    Stack(
                  alignment:
                      Alignment.center,

                  children: [
                    Align(
                      alignment:
                          Alignment.centerLeft,

                      child:
                          IconButton(
                        onPressed:
                            () {
                          Navigator.pop(
                            context,
                          );
                        },

                        padding:
                            EdgeInsets.zero,

                        constraints:
                            const BoxConstraints(),

                        icon:
                            const Icon(
                          Icons
                              .arrow_back_ios_new_rounded,

                          color:
                              darkPurple,

                          size:
                              21,
                        ),
                      ),
                    ),

                    const Text(
                      'Health Conditions',

                      style:
                          TextStyle(
                        color:
                            darkPurple,

                        fontSize:
                            22,

                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              const Text(
                'Select all that apply.',

                textAlign:
                    TextAlign.center,

                style:
                    TextStyle(
                  color:
                      mediumPurple,

                  fontSize:
                      17,
                ),
              ),

              const SizedBox(
                height:
                    34,
              ),

              _ConditionCard(
                title:
                    'Diabetes',

                icon:
                    Icons.water_drop_outlined,

                selected:
                    _diabetes,

                onTap:
                    _handleDiabetesTap,
              ),

              const SizedBox(
                height:
                    11,
              ),

              _ConditionCard(
                title:
                    'Hypertension',

                icon:
                    Icons.monitor_heart_outlined,

                selected:
                    _hypertension,

                onTap:
                    _handleHypertensionTap,
              ),

              const SizedBox(
                height:
                    11,
              ),

              _ConditionCard(
                title:
                    'High LDL cholesterol',

                icon:
                    Icons.favorite_border_rounded,

                selected:
                    _highCholesterol,

                onTap:
                    _handleCholesterolTap,

                onEditTap:
                    _highCholesterol &&
                            !_weightManagement
                        ? _editEnergyDetails
                        : null,
              ),

              const SizedBox(
                height:
                    11,
              ),

              _ConditionCard(
                title:
                    'Weight management',

                icon:
                    Icons.monitor_weight_outlined,

                subtitle:
                    _weightSubtitle,

                selected:
                    _weightManagement,

                onTap:
                    _handleWeightManagementTap,

                onEditTap:
                    _weightManagement
                        ? _editWeightManagement
                        : null,
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar:
          SafeArea(
        top:
            false,

        child:
            Container(
          color:
              backgroundColor,

          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            18,
          ),

          child:
              SizedBox(
            height:
                56,

            child:
                ElevatedButton(
              onPressed:
                  _hasChanges
                      ? _saveChanges
                      : null,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryPurple,

                foregroundColor:
                    Colors.white,

                disabledBackgroundColor:
                    lightPurple,

                disabledForegroundColor:
                    Colors.white,

                elevation:
                    _hasChanges
                        ? 3
                        : 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
              ),

              child:
                  const Text(
                'Save changes',

                style:
                    TextStyle(
                  fontSize:
                      18,

                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// CONDITION CARD
// =======================================================

class _ConditionCard
    extends StatelessWidget {
  final String title;

  // Symbol on the left (same ones as the Profile chips).
  final IconData icon;

  final String? subtitle;

  final bool selected;

  final VoidCallback onTap;

  final VoidCallback? onEditTap;

  const _ConditionCard({
    required this.title,
    required this.icon,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.onEditTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds:
            180,
      ),

      width:
          double.infinity,

      constraints:
          const BoxConstraints(
        minHeight:
            94,
      ),

      decoration:
          BoxDecoration(
        color:
            selected
                ? const Color(
                    0xFFF8F4FF,
                  )
                : Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        border:
            Border.all(
          color:
              selected
                  ? const Color(
                      0xFF4B2E83,
                    )
                  : const Color(
                      0xFFDCCFF0,
                    ),

          width:
              selected
                  ? 1.7
                  : 1.2,
        ),
      ),

      child:
          Material(
        color:
            Colors.transparent,

        child:
            InkWell(
          onTap:
              onTap,

          borderRadius:
              BorderRadius.circular(
            18,
          ),

          child:
              Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              18,
              18,
              18,
            ),

            child:
                Row(
              children: [
                // Symbol: purple tile when selected.
                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds:
                        180,
                  ),
                  width:
                      46,
                  height:
                      46,
                  decoration:
                      BoxDecoration(
                    color:
                        selected
                            ? const Color(
                                0xFF4B2E83,
                              )
                            : const Color(
                                0xFFF3ECFF,
                              ),
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child:
                      Icon(
                    icon,
                    size:
                        24,
                    color:
                        selected
                            ? Colors.white
                            : const Color(
                                0xFF4B2E83,
                              ),
                  ),
                ),

                const SizedBox(
                  width:
                      14,
                ),

                Expanded(
                  child:
                      Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      Text(
                        title,

                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF38138C,
                          ),

                          fontSize:
                              18,

                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      if (selected &&
                          subtitle !=
                              null &&
                          subtitle!
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(
                          height:
                              4,
                        ),

                        GestureDetector(
                          onTap:
                              onEditTap,

                          behavior:
                              HitTestBehavior.opaque,

                          child:
                              Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical:
                                  2,
                            ),

                            child:
                                Text(
                              subtitle!,

                              style:
                                  const TextStyle(
                                color:
                                    Color(
                                  0xFF67558E,
                                ),

                                fontSize:
                                    15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(
                  width:
                      14,
                ),

                AnimatedContainer(
                  duration:
                      const Duration(
                    milliseconds:
                        180,
                  ),

                  width:
                      42,

                  height:
                      42,

                  decoration:
                      BoxDecoration(
                    shape:
                        BoxShape.circle,

                    color:
                        selected
                            ? const Color(
                                0xFF5631AE,
                              )
                            : Colors.white,

                    border:
                        Border.all(
                      color:
                          const Color(
                        0xFF4B2E83,
                      ),

                      width:
                          2,
                    ),
                  ),

                  child:
                      selected
                          ? const Icon(
                              Icons
                                  .check_rounded,

                              color:
                                  Colors.white,

                              size:
                                  27,
                            )
                          : null,
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
// SINGLE SELECT OPTION
// =======================================================

class _WeightSheetResult {
  final String goal;
  final String sex;
  final double weightKg;
  final double heightCm;
  final String activity;

  // Daily figure from a doctor or dietitian, or null.
  final double? providerEnergyKcal;

  const _WeightSheetResult({
    required this.goal,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
    required this.providerEnergyKcal,
  });
}

class _WeightManagementSheet extends StatefulWidget {
  final String? goal;
  final String? sex;
  final double? weightKg;
  final double? heightCm;
  final String? activity;

  // For the energy guide.
  final DateTime? dateOfBirth;

  // Editable in the sheet (optional).
  final double? providerEnergyKcal;

  // Shows the insulin / diabetes-medicine line only for diabetes.
  final bool diabetes;

  const _WeightManagementSheet({
    required this.goal,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
    required this.dateOfBirth,
    required this.providerEnergyKcal,
    required this.diabetes,
  });

  @override
  State<_WeightManagementSheet> createState() => _WeightManagementSheetState();
}

class _WeightManagementSheetState extends State<_WeightManagementSheet> {
  late String? _goal = widget.goal;
  late String? _sex = widget.sex;
  late String? _activity = widget.activity;

  late final TextEditingController _weightController =
      TextEditingController(text: WeightPlanOptions.formatNumber(widget.weightKg));

  late final TextEditingController _heightController =
      TextEditingController(text: WeightPlanOptions.formatNumber(widget.heightCm));

  late final TextEditingController _providerController = TextEditingController(
    text: widget.providerEnergyKcal == null ? '' : widget.providerEnergyKcal!.round().toString(),
  );

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  double? get _weight => WeightPlanOptions.parse(_weightController.text);

  double? get _height => WeightPlanOptions.parse(_heightController.text);

  bool get _complete =>
      _goal != null &&
      _sex != null &&
      _activity != null &&
      WeightPlanOptions.weightOk(_weight) &&
      WeightPlanOptions.heightOk(_height) &&
      WeightPlanOptions.providerTextOk(_providerController.text);

  DailyTargets? get _targets {
    if (!_complete) return null;

    return WeightPlanOptions.energyTargets(
      ProfileSetupData(
        dateOfBirth: widget.dateOfBirth,
        weightGoal: _goal,
        genderForEnergyEstimate: _sex,
        currentWeight: _weight,
        height: _height,
        activityLevel: _activity,
        providerEnergyKcal: WeightPlanOptions.providerKcal(_providerController.text),
      ),
    );
  }

  void _done() {
    if (!_complete) return;

    Navigator.pop(
      context,
      _WeightSheetResult(
        goal: _goal!,
        sex: _sex!,
        weightKg: _weight!,
        heightCm: _height!,
        activity: _activity!,
        providerEnergyKcal: WeightPlanOptions.providerKcal(_providerController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DailyTargets? targets = _targets;
    final double keyboard = MediaQuery.viewInsetsOf(context).bottom;

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

              // ---- header --------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Weight management',
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
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'NutriPal uses these details to estimate your daily energy needs.',
                    style: TextStyle(color: WeightPlanColors.muted, fontSize: 14.5, height: 1.4),
                  ),
                ),
              ),

              // ---- questions -----------------------------
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + keyboard),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetSectionTitle('Weight goal'),
                      WeightGoalRow(
                        selected: _goal,
                        onChanged: (String v) => setState(() => _goal = v),
                      ),
                      const SizedBox(height: 22),
                      const _SheetSectionTitle('Gender'),
                      GenderRow(
                        selected: _sex,
                        onChanged: (String v) => setState(() => _sex = v),
                      ),
                      const SizedBox(height: 18),
                      MeasurementFields(
                        weightController: _weightController,
                        heightController: _heightController,
                        onWeightChanged: (_) => setState(() {}),
                        onHeightChanged: (_) => setState(() {}),
                        // Same wording style as Weight goal,
                        // Gender and Activity level.
                        labelsAsSectionTitles: true,
                      ),
                      const SizedBox(height: 22),
                      const _SheetSectionTitle('Activity level'),
                      ActivityList(
                        selected: _activity,
                        onChanged: (String v) => setState(() => _activity = v),
                      ),
                      const SizedBox(height: 22),
                      ProviderEnergyField(
                        controller: _providerController,
                        sex: _sex,
                        onChanged: (_) => setState(() {}),
                        labelAsSectionTitle: true,
                      ),
                      if (targets != null) ...[
                        const SizedBox(height: 18),
                        EnergyGuideCard.fromTargets(targets, goal: _goal),
                        const SizedBox(height: 14),
                        GoalGuidanceCard(
                          goal: _goal,
                          sex: _sex,
                          weightKg: _weight,
                          heightCm: _height,
                          diabetes: widget.diabetes,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ---- done ----------------------------------
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: WeightPlanColors.cardBorder)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _complete ? _done : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: WeightPlanColors.purple,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFDCD3EC),
                      disabledForegroundColor: const Color(0xFF4F4268),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: Text(
                      _complete ? 'Done' : 'Complete all details',
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

class _SheetSectionTitle extends StatelessWidget {
  final String text;

  const _SheetSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: WeightPlanColors.ink,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
