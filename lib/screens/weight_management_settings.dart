import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/energy_requirement.dart';
import '../services/user_profile_service.dart';
import '../widgets/weight_plan_widgets.dart';

class WeightManagementSettings extends StatefulWidget {
  final ProfileSetupData data;

  const WeightManagementSettings({
    super.key,
    required this.data,
  });

  @override
  State<WeightManagementSettings> createState() =>
      _WeightManagementSettingsState();
}

class _WeightManagementSettingsState
    extends State<WeightManagementSettings> {
  // =====================================================
  // NUTRIPAL COLOURS
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

  static const Color selectedPurple =
      Color(0xFFF3ECFF);

  static const Color borderPurple =
      Color(0xFFDCCFF0);

  // =====================================================
  // CURRENT VALUES
  // =====================================================

  late String _weightGoal;
  late String _gender;
  late String _activityLevel;

  double? _currentWeight;
  double? _height;

  // Daily figure from a doctor or dietitian (optional).
  double? _providerEnergyKcal;

  // kcal a day taken off (lose) or added (gain); null
  // means the default (GoalEnergy).
  int? _energyChangeKcal;

  // =====================================================
  // ORIGINAL VALUES
  // =====================================================

  late String _originalWeightGoal;
  late String _originalGender;
  late String _originalActivityLevel;

  double? _originalCurrentWeight;
  double? _originalHeight;
  double? _originalProviderEnergyKcal;
  int? _originalEnergyChangeKcal;

  // =====================================================
  // ACTIVITY ICONS
  // =====================================================

  // NASEM's four activity levels, with the same icons and
  // descriptions as setup Step 3 (weight_plan_widgets.dart).
  static final Map<String, IconData> _activityIcons = {
    for (final (String value, String _, IconData icon)
        in WeightPlanOptions.activities)
      value: icon,
  };

  static final Map<String, String> _activityDescriptions = {
    for (final (String value, String description, IconData _)
        in WeightPlanOptions.activities)
      value: description,
  };

  // =====================================================
  // INIT
  // =====================================================

  @override
  void initState() {
    super.initState();

    _loadCurrentValues();
  }

  // =====================================================
  // LOAD CURRENT VALUES
  // =====================================================

  void _loadCurrentValues() {
    // ===============================================
    // CONVERT OLD IMPERIAL TEST DATA
    // ===============================================

    if (widget.data.weightUnit == 'lb' &&
        widget.data.currentWeight != null) {
      widget.data.currentWeight =
          widget.data.currentWeight! *
              0.45359237;
    }

    if (widget.data.heightUnit == 'in' &&
        widget.data.height != null) {
      widget.data.height =
          widget.data.height! *
              2.54;
    }

    // NutriPal now always uses metric units.
    widget.data.weightUnit =
        'kg';

    widget.data.heightUnit =
        'cm';

    // ===============================================
    // WEIGHT GOAL
    // ===============================================

    final String? savedGoal =
        widget.data.weightGoal;

    if (savedGoal == 'Lose weight' ||
        savedGoal == 'Maintain weight' ||
        savedGoal == 'Gain weight') {
      _weightGoal =
          savedGoal!;
    } else {
      _weightGoal =
          'Not selected';
    }

    // ===============================================
    // GENDER
    // ===============================================

    final String? savedGender =
        widget.data.genderForEnergyEstimate;

    if (savedGender == 'Male' ||
        savedGender == 'Female') {
      _gender =
          savedGender!;
    } else {
      // Old unsupported values such as
      // "Prefer not to say" become unselected.
      _gender =
          'Not selected';
    }

    // ===============================================
    // ACTIVITY
    // ===============================================

    // Older values ("Sedentary"...) map to NASEM levels.
    final String? savedActivity =
        ActivityLevels.normalise(
      widget.data.activityLevel,
    );

    if (_activityIcons.containsKey(
      savedActivity,
    )) {
      _activityLevel =
          savedActivity!;
    } else {
      _activityLevel =
          'Not selected';
    }

    // ===============================================
    // BODY INFORMATION
    // ===============================================

    _currentWeight =
        widget.data.currentWeight;

    _height =
        widget.data.height;

    _providerEnergyKcal =
        widget.data.providerEnergyKcal;

    _energyChangeKcal =
        widget.data.energyChangeKcal;

    // ===============================================
    // ORIGINAL VALUES
    // ===============================================

    _originalWeightGoal =
        _weightGoal;

    _originalGender =
        _gender;

    _originalActivityLevel =
        _activityLevel;

    _originalCurrentWeight =
        _currentWeight;

    _originalHeight =
        _height;

    _originalProviderEnergyKcal =
        _providerEnergyKcal;

    _originalEnergyChangeKcal =
        _energyChangeKcal;
  }

  // =====================================================
  // ENERGY GUIDE (same calculation as the analysis)
  // =====================================================

  DailyTargets? get _energyTargets {
    return WeightPlanOptions.energyTargets(
      ProfileSetupData(
        dateOfBirth:
            widget.data.dateOfBirth,
        weightGoal:
            _weightGoal,
        genderForEnergyEstimate:
            _gender,
        currentWeight:
            _currentWeight,
        height:
            _height,
        activityLevel:
            _activityLevel,
        providerEnergyKcal:
            _providerEnergyKcal,
        energyChangeKcal:
            _energyChangeKcal,
      ),
    );
  }

  // =====================================================
  // HAS CHANGES
  // =====================================================

  bool get _hasChanges {
    return _weightGoal !=
            _originalWeightGoal ||
        _gender !=
            _originalGender ||
        _activityLevel !=
            _originalActivityLevel ||
        _currentWeight !=
            _originalCurrentWeight ||
        _height !=
            _originalHeight ||
        _providerEnergyKcal !=
            _originalProviderEnergyKcal ||
        _energyChangeKcal !=
            _originalEnergyChangeKcal;
  }

  // =====================================================
  // DISPLAY NUMBER
  // =====================================================

  String _displayNumber(
    double? value,
  ) {
    if (value == null) {
      return 'Not set';
    }

    if (value ==
        value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value.toStringAsFixed(
      1,
    );
  }

  // =====================================================
  // SHOW MESSAGE
  // =====================================================

  void _showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
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
  // EDIT WEIGHT GOAL
  // =====================================================

  void _editWeightGoal() {
    _showChoiceSheet(
      title:
          'Weight goal',
      options:
          const [
        'Lose weight',
        'Maintain weight',
        'Gain weight',
      ],
      // Same symbols as setup Step 3.
      icons:
          const {
        'Lose weight': Icons.trending_down_rounded,
        'Maintain weight': Icons.drag_handle_rounded,
        'Gain weight': Icons.trending_up_rounded,
      },
      selected:
          _weightGoal,
      onSelected: (
        value,
      ) {
        setState(() {
          _weightGoal =
              value;

          // A choice for the other goal goes back to the
          // default for this one.
          if (!WeightPlanOptions.energyChangeOptions(value)
              .contains(_energyChangeKcal)) {
            _energyChangeKcal =
                null;
          }
        });
      },
    );
  }

  // =====================================================
  // EDIT DAILY ENERGY CHANGE (lose / gain)
  // =====================================================

  void _editEnergyChange() {
    final List<int> options =
        WeightPlanOptions.energyChangeOptions(
      _weightGoal,
    );

    if (options.isEmpty) {
      return;
    }

    final Map<String, int> byLabel = {
      for (final int kcal in options)
        WeightPlanOptions.energyChangeText(
          _weightGoal,
          kcal,
        ): kcal,
    };

    _showChoiceSheet(
      title:
          'Daily energy change',
      options:
          byLabel.keys.toList(),
      selected:
          WeightPlanOptions.energyChangeText(
        _weightGoal,
        GoalEnergy.amountFor(
          _weightGoal,
          _energyChangeKcal,
        ),
      ),
      onSelected: (
        value,
      ) {
        setState(() {
          _energyChangeKcal =
              byLabel[value];
        });
      },
    );
  }

  // =====================================================
  // EDIT GENDER
  // =====================================================

  void _editGender() {
    _showChoiceSheet(
      title:
          'Gender',

      // Only these two options.
      options:
          const [
        'Male',
        'Female',
      ],

      icons:
          const {
        'Male': Icons.male_rounded,
        'Female': Icons.female_rounded,
      },

      selected:
          _gender,

      onSelected: (
        value,
      ) {
        setState(() {
          _gender =
              value;
        });
      },
    );
  }

  // =====================================================
  // EDIT ACTIVITY LEVEL
  // =====================================================

  void _editActivityLevel() {
    _showChoiceSheet(
      title:
          'Activity level',
      options:
          ActivityLevels.all,
      selected:
          _activityLevel,
      icons:
          _activityIcons,
      descriptions:
          _activityDescriptions,
      onSelected: (
        value,
      ) {
        setState(() {
          _activityLevel =
              value;
        });
      },
    );
  }

  // =====================================================
  // CHOICE SHEET
  // =====================================================

  void _showChoiceSheet({
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String>
        onSelected,
    Map<String, IconData>? icons,
    Map<String, String>? descriptions,
  }) {
    showModalBottomSheet(
      context:
          context,
      backgroundColor:
          Colors.transparent,
      isScrollControlled:
          true,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          top:
              false,
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              14,
              20,
              24,
            ),
            decoration:
                const BoxDecoration(
              color:
                  backgroundColor,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  28,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // =========================================
                // HANDLE
                // =========================================

                Center(
                  child: Container(
                    width:
                        44,
                    height:
                        5,
                    decoration:
                        BoxDecoration(
                      color:
                          lightPurple,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height:
                      18,
                ),

                // =========================================
                // TITLE
                // =========================================

                Text(
                  title,
                  style:
                      const TextStyle(
                    color:
                        darkPurple,
                    fontSize:
                        22,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(
                  height:
                      14,
                ),

                // =========================================
                // OPTIONS
                // =========================================

                ...options.map(
                  (
                    option,
                  ) {
                    final bool isSelected =
                        option ==
                            selected;

                    final IconData? optionIcon =
                        icons?[
                            option];

                    return Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom:
                            10,
                      ),
                      child: Material(
                        color:
                            Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            onSelected(
                              option,
                            );

                            Navigator.pop(
                              sheetContext,
                            );
                          },
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                          child: Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  16,
                              vertical:
                                  14,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  isSelected
                                      ? selectedPurple
                                      : Colors.white,
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              border:
                                  Border.all(
                                color:
                                    isSelected
                                        ? primaryPurple
                                        : borderPurple,
                                width:
                                    isSelected
                                        ? 1.6
                                        : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // =========================
                                // ACTIVITY ICON
                                // =========================

                                if (optionIcon !=
                                    null) ...[
                                  Container(
                                    width:
                                        42,
                                    height:
                                        42,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          isSelected
                                              ? primaryPurple
                                              : selectedPurple,
                                      borderRadius:
                                          BorderRadius.circular(
                                        12,
                                      ),
                                    ),
                                    child: Icon(
                                      optionIcon,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : primaryPurple,
                                      size:
                                          24,
                                    ),
                                  ),

                                  const SizedBox(
                                    width:
                                        13,
                                  ),
                                ],

                                // =========================
                                // TEXT
                                // =========================

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option,
                                        style:
                                            TextStyle(
                                          color:
                                              darkPurple,
                                          fontSize:
                                              16,
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                        ),
                                      ),
                                      if (descriptions?[option] !=
                                          null) ...[
                                        const SizedBox(
                                          height:
                                              2,
                                        ),
                                        Text(
                                          descriptions![option]!,
                                          style:
                                              const TextStyle(
                                            color:
                                                mediumPurple,
                                            fontSize:
                                                13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // =========================
                                // RADIO
                                // =========================

                                Container(
                                  width:
                                      24,
                                  height:
                                      24,
                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape.circle,
                                    border:
                                        Border.all(
                                      color:
                                          isSelected
                                              ? primaryPurple
                                              : const Color(
                                                  0xFFBDB2CE,
                                                ),
                                      width:
                                          2,
                                    ),
                                  ),
                                  child:
                                      isSelected
                                          ? Center(
                                              child:
                                                  Container(
                                                width:
                                                    12,
                                                height:
                                                    12,
                                                decoration:
                                                    const BoxDecoration(
                                                  shape:
                                                      BoxShape.circle,
                                                  color:
                                                      primaryPurple,
                                                ),
                                              ),
                                            )
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================
  // EDIT WEIGHT
  // =====================================================

  Future<void> _editCurrentWeight() async {
    final TextEditingController controller =
        TextEditingController(
      text:
          _currentWeight ==
                  null
              ? ''
              : _displayNumber(
                  _currentWeight,
                ),
    );

    final double? result =
        await _showNumberDialog(
      title:
          'Current weight',
      controller:
          controller,
      suffix:
          'kg',
      min:
          20,
      max:
          500,
    );

    // Not disposed here: the dialog is still fading out
    // and its text field keeps using the controller for a
    // few frames (disposing now crashes in debug). It holds
    // no listeners, so it is simply garbage collected.

    if (result != null &&
        mounted) {
      setState(() {
        _currentWeight =
            result;
      });
    }
  }

  // =====================================================
  // EDIT HEIGHT
  // =====================================================

  Future<void> _editHeight() async {
    final TextEditingController controller =
        TextEditingController(
      text:
          _height == null
              ? ''
              : _displayNumber(
                  _height,
                ),
    );

    final double? result =
        await _showNumberDialog(
      title:
          'Height',
      controller:
          controller,
      suffix:
          'cm',
      min:
          80,
      max:
          250,
    );

    // Not disposed here: the dialog is still fading out
    // and its text field keeps using the controller for a
    // few frames (disposing now crashes in debug). It holds
    // no listeners, so it is simply garbage collected.

    if (result != null &&
        mounted) {
      setState(() {
        _height =
            result;
      });
    }
  }

  // =====================================================
  // EDIT CALORIE TARGET FROM A DOCTOR OR DIETITIAN
  // =====================================================
  //
  // Optional. When set, it replaces NutriPal's estimate as
  // the energy base ("Set by your healthcare provider").

  Future<void> _editProviderEnergy() async {
    final TextEditingController controller =
        TextEditingController(
      text:
          _providerEnergyKcal ==
                  null
              ? ''
              : _providerEnergyKcal!
                  .round()
                  .toString(),
    );

    final double? result =
        await _showNumberDialog(
      title:
          'Daily calorie target',
      helper:
          'Only enter a figure your doctor or dietitian gave you. '
          'NutriPal then uses it instead of its own estimate.',
      controller:
          controller,
      suffix:
          'kcal',
      min:
          EnergyRequirement.providerMinimumKcal,
      max:
          EnergyRequirement.providerMaximumKcal,
      wholeNumber:
          true,
      invalidMessage:
          'Please enter a daily figure between 800 and 5,000 kcal.',
      allowRemove:
          _providerEnergyKcal !=
              null,
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      // A negative result means "Remove".
      _providerEnergyKcal =
          result < 0
              ? null
              : result;
    });

    final String? note =
        _providerEnergyKcal ==
                null
            ? null
            : WeightPlanOptions.providerNote(
                _providerEnergyKcal!
                    .round()
                    .toString(),
                _gender,
              );

    if (note != null) {
      _showMessage(
        note,
      );
    }
  }

  // =====================================================
  // NUMBER DIALOG
  // =====================================================

  Future<double?> _showNumberDialog({
    required String title,
    required TextEditingController
        controller,
    required String suffix,
    required double min,
    required double max,
    String? helper,
    bool wholeNumber = false,
    String? invalidMessage,
    // Adds a "Remove" button that returns -1.
    bool allowRemove = false,
  }) async {
    return showDialog<double>(
      context:
          context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              backgroundColor,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),
          title: Text(
            title,
            style:
                const TextStyle(
              color:
                  darkPurple,
              fontSize:
                  21,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              if (helper !=
                  null) ...[
                Text(
                  helper,
                  style:
                      const TextStyle(
                    color:
                        mediumPurple,
                    fontSize:
                        14,
                    height:
                        1.4,
                  ),
                ),
                const SizedBox(
                  height:
                      12,
                ),
              ],
              TextField(
            controller:
                controller,
            autofocus:
                true,
            keyboardType:
                wholeNumber
                    ? TextInputType.number
                    : const TextInputType
                        .numberWithOptions(
                        decimal:
                            true,
                      ),
            inputFormatters: [
              wholeNumber
                  ? FilteringTextInputFormatter.digitsOnly
                  : FilteringTextInputFormatter.allow(
                      RegExp(
                        r'^\d*\.?\d{0,2}',
                      ),
                    ),
            ],
            style:
                const TextStyle(
              color:
                  darkPurple,
              fontSize:
                  18,
              fontWeight:
                  FontWeight.w600,
            ),
            decoration:
                InputDecoration(
              suffixText:
                  suffix,
              suffixStyle:
                  const TextStyle(
                color:
                    mediumPurple,
                fontSize:
                    16,
                fontWeight:
                    FontWeight.w700,
              ),
              filled:
                  true,
              fillColor:
                  Colors.white,
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      borderPurple,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      primaryPurple,
                  width:
                      1.7,
                ),
              ),
            ),
          ),
            ],
          ),
          actions: [
            if (allowRemove)
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    -1.0,
                  );
                },
                child:
                    const Text(
                  'Remove',
                  style:
                      TextStyle(
                    color:
                        Color(
                      0xFFB3261E,
                    ),
                  ),
                ),
              ),

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
                  const Text(
                'Cancel',
                style:
                    TextStyle(
                  color:
                      mediumPurple,
                ),
              ),
            ),

            ElevatedButton(
              onPressed: () {
                final double? value =
                    double.tryParse(
                  controller.text.trim(),
                );

                if (value ==
                        null ||
                    value <
                        min ||
                    value >
                        max) {
                  _showMessage(
                    invalidMessage ??
                        'Please enter a valid $title.',
                  );

                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    primaryPurple,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text(
                'Update',
              ),
            ),
          ],
        );
      },
    );
  }

  // =====================================================
  // VALIDATE
  // =====================================================

  bool _validate() {
    if (_weightGoal ==
        'Not selected') {
      _showMessage(
        'Please select your weight goal.',
      );

      return false;
    }

    if (_gender ==
        'Not selected') {
      _showMessage(
        'Please select your gender.',
      );

      return false;
    }

    if (_currentWeight == null ||
        _currentWeight! <= 0) {
      _showMessage(
        'Please enter your current weight.',
      );

      return false;
    }

    if (_height == null ||
        _height! <= 0) {
      _showMessage(
        'Please enter your height.',
      );

      return false;
    }

    if (_activityLevel ==
        'Not selected') {
      _showMessage(
        'Please select your activity level.',
      );

      return false;
    }

    return true;
  }

  // =====================================================
  // SAVE CHANGES
  // =====================================================

  void _saveChanges() {
    if (!_validate()) {
      return;
    }

    widget.data.weightManagement =
        true;

    widget.data.generalNutrition =
        false;

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

    widget.data.energyChangeKcal =
        _energyChangeKcal;

    widget.data.weightUnit =
        'kg';

    widget.data.heightUnit =
        'cm';

    // Saved to Firestore (works offline, sent later).
    UserProfileService.save(widget.data);

    setState(() {
      _originalWeightGoal =
          _weightGoal;

      _originalGender =
          _gender;

      _originalActivityLevel =
          _activityLevel;

      _originalCurrentWeight =
          _currentWeight;

      _originalHeight =
          _height;

      _originalProviderEnergyKcal =
          _providerEnergyKcal;

      _originalEnergyChangeKcal =
          _energyChangeKcal;
    });

    _showMessage(
      'Weight management information updated.',
    );
  }

  // =====================================================
  // DISABLED VIEW
  // =====================================================

  Widget _buildDisabledView() {
    return Scaffold(
      backgroundColor:
          backgroundColor,
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            24,
          ),
          child: Column(
            children: [
              // =========================================
              // HEADER
              // =========================================

              SizedBox(
                height:
                    48,
                child: Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    Align(
                      alignment:
                          Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
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
                              primaryPurple,
                          size:
                              21,
                        ),
                      ),
                    ),

                    const Text(
                      'Weight Management',
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

              const Spacer(),

              Container(
                width:
                    84,
                height:
                    84,
                decoration:
                    const BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color:
                      selectedPurple,
                ),
                child:
                    const Icon(
                  Icons
                      .track_changes_rounded,
                  color:
                      primaryPurple,
                  size:
                      42,
                ),
              ),

              const SizedBox(
                height:
                    20,
              ),

              const Text(
                'Weight Management is not enabled',
                textAlign:
                    TextAlign.center,
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

              const SizedBox(
                height:
                    10,
              ),

              const Text(
                'Enable Weight Management from your Profile to set your goal, body information and activity level.',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      mediumPurple,
                  fontSize:
                      14,
                  height:
                      1.45,
                ),
              ),

              const SizedBox(
                height:
                    24,
              ),

              SizedBox(
                width:
                    double.infinity,
                height:
                    52,
                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primaryPurple,
                    foregroundColor:
                        Colors.white,
                    elevation:
                        0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        17,
                      ),
                    ),
                  ),
                  child:
                      const Text(
                    'Back to Profile',
                    style:
                        TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    // Defensive fallback.
    // Normally Profile enables Weight Management
    // before opening this page.
    if (!widget.data.weightManagement) {
      return _buildDisabledView();
    }

    return Scaffold(
      backgroundColor:
          backgroundColor,

      // =================================================
      // CONTENT
      // =================================================

      body: SafeArea(
        bottom:
            false,
        child: SingleChildScrollView(
          physics:
              const ClampingScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            120,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // =========================================
              // HEADER
              // =========================================

              SizedBox(
                height:
                    48,
                child: Stack(
                  alignment:
                      Alignment.center,
                  children: [
                    Align(
                      alignment:
                          Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () {
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
                              primaryPurple,
                          size:
                              21,
                        ),
                      ),
                    ),

                    const Text(
                      'Weight Management',
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

              const Center(
                child: Text(
                  'Review and update your information.',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    color:
                        mediumPurple,
                    fontSize:
                        15,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(
                height:
                    38,
              ),

              // =========================================
              // GOAL
              // =========================================

              const _SectionTitle(
                text:
                    'GOAL',
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SettingsGroup(
                children: [
                  _SettingsRow(
                    label:
                        'Weight goal',
                    value:
                        _weightGoal,
                    valueIcon:
                        _weightGoal == 'Lose weight'
                            ? Icons.trending_down_rounded
                            : _weightGoal == 'Maintain weight'
                                ? Icons.drag_handle_rounded
                                : _weightGoal == 'Gain weight'
                                    ? Icons.trending_up_rounded
                                    : null,
                    onTap:
                        _editWeightGoal,
                  ),

                  // Lose or gain, unless a provider's
                  // figure replaces NutriPal's estimate.
                  if (WeightPlanOptions.energyChangeOptions(
                        _weightGoal,
                      ).isNotEmpty &&
                      _providerEnergyKcal ==
                          null) ...[
                    const _SettingsDivider(),

                    _SettingsRow(
                      label:
                          'Daily energy change',
                      value:
                          WeightPlanOptions.energyChangeText(
                        _weightGoal,
                        GoalEnergy.amountFor(
                          _weightGoal,
                          _energyChangeKcal,
                        ),
                      ),
                      onTap:
                          _editEnergyChange,
                    ),
                  ],
                ],
              ),

              const SizedBox(
                height:
                    30,
              ),

              // =========================================
              // BODY INFORMATION
              // =========================================

              const _SectionTitle(
                text:
                    'BODY INFORMATION',
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SettingsGroup(
                children: [
                  _SettingsRow(
                    label:
                        'Gender',
                    value:
                        _gender,
                    valueIcon:
                        _gender == 'Male'
                            ? Icons.male_rounded
                            : _gender == 'Female'
                                ? Icons.female_rounded
                                : null,
                    onTap:
                        _editGender,
                  ),

                  const _SettingsDivider(),

                  _SettingsRow(
                    label:
                        'Current weight',
                    value:
                        _currentWeight ==
                                null
                            ? 'Not set'
                            : '${_displayNumber(_currentWeight)} kg',
                    onTap:
                        _editCurrentWeight,
                  ),

                  const _SettingsDivider(),

                  _SettingsRow(
                    label:
                        'Height',
                    value:
                        _height ==
                                null
                            ? 'Not set'
                            : '${_displayNumber(_height)} cm',
                    onTap:
                        _editHeight,
                  ),
                ],
              ),

              const SizedBox(
                height:
                    30,
              ),

              // =========================================
              // LIFESTYLE
              // =========================================

              const _SectionTitle(
                text:
                    'LIFESTYLE',
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SettingsGroup(
                children: [
                  _SettingsRow(
                    label:
                        'Activity level',
                    value:
                        _activityLevel,
                    valueIcon:
                        _activityIcons[
                            _activityLevel],
                    onTap:
                        _editActivityLevel,
                  ),
                ],
              ),

              const SizedBox(
                height:
                    30,
              ),

              // =========================================
              // HEALTHCARE PROVIDER (optional)
              // =========================================

              const _SectionTitle(
                text:
                    'FROM YOUR DOCTOR OR DIETITIAN',
              ),

              const SizedBox(
                height:
                    12,
              ),

              _SettingsGroup(
                children: [
                  _SettingsRow(
                    label:
                        'Daily calorie target',
                    value:
                        _providerEnergyKcal ==
                                null
                            ? 'Not set'
                            : '${WeightPlanOptions.exactKcalText(_providerEnergyKcal!)} kcal',
                    onTap:
                        _editProviderEnergy,
                  ),
                ],
              ),

              // =========================================
              // ENERGY GUIDE
              // =========================================

              if (_energyTargets !=
                  null) ...[
                const SizedBox(
                  height:
                      24,
                ),

                EnergyGuideCard.fromTargets(
                  _energyTargets!,
                  goal:
                      _weightGoal,
                ),

                const SizedBox(
                  height:
                      14,
                ),

                GoalGuidanceCard(
                  goal:
                      _weightGoal,
                  sex:
                      _gender,
                  weightKg:
                      _currentWeight,
                  heightCm:
                      _height,
                ),
              ],
            ],
          ),
        ),
      ),

      // =================================================
      // SAVE
      // =================================================

      bottomNavigationBar:
          SafeArea(
        top:
            false,
        child: Container(
          color:
              backgroundColor,
          padding:
              const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            18,
          ),
          child: SizedBox(
            width:
                double.infinity,
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
// SECTION TITLE
// =======================================================

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          const TextStyle(
        color:
            Color(
          0xFF4B2E83,
        ),
        fontSize:
            16,
        fontWeight:
            FontWeight.w900,
        letterSpacing:
            0.4,
      ),
    );
  }
}

// =======================================================
// SETTINGS GROUP
// =======================================================

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFDCCFF0,
          ),
          width:
              1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children:
            children,
      ),
    );
  }
}

// =======================================================
// SETTINGS ROW
// =======================================================

class _SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  final IconData? valueIcon;

  const _SettingsRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.valueIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap:
            onTap,
        child: SizedBox(
          width:
              double.infinity,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              19,
              12,
              19,
            ),
            child: Row(
              children: [
                // =====================================
                // LABEL
                // =====================================

                Expanded(
                  child: Text(
                    label,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF38138C,
                      ),
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),

                // =====================================
                // OPTIONAL ICON
                // =====================================

                if (valueIcon !=
                    null) ...[
                  Icon(
                    valueIcon,
                    color:
                        const Color(
                      0xFF4B2E83,
                    ),
                    size:
                        21,
                  ),

                  const SizedBox(
                    width:
                        7,
                  ),
                ],

                // =====================================
                // VALUE
                // =====================================

                ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth:
                        150,
                  ),
                  child: Text(
                    value,
                    textAlign:
                        TextAlign.right,
                    maxLines:
                        1,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF67558E,
                      ),
                      fontSize:
                          15,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                // =====================================
                // ARROW
                // =====================================

                const Icon(
                  Icons
                      .chevron_right_rounded,
                  color:
                      Color(
                    0xFF4B2E83,
                  ),
                  size:
                      27,
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
// SETTINGS DIVIDER
// =======================================================

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height:
          1,
      thickness:
          1,
      color:
          Color(
        0xFFE4D9F7,
      ),
    );
  }
}