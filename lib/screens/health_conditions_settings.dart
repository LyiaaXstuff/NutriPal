import 'package:flutter/material.dart';

import '../models/nutrition_analysis.dart';
import '../models/profile_setup_data.dart';
import '../services/user_profile_service.dart';
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
  // CHOLESTEROL VALUES
  // =====================================================

  static const String cholesterolLdl =
      'High LDL cholesterol';

  static const String cholesterolTriglycerides =
      'High triglycerides';

  static const String cholesterolNotSure =
      'Not sure';

  // =====================================================
  // CURRENT VALUES
  // =====================================================

  late bool _diabetes;
  late bool _hypertension;
  late bool _highCholesterol;
  late bool _weightManagement;

  String? _diabetesType;
  String? _cholesterolType;

  String? _weightGoal;
  String? _gender;

  double? _currentWeight;
  double? _height;

  String? _activityLevel;

  // =====================================================
  // ORIGINAL VALUES
  // =====================================================

  late bool _originalDiabetes;
  late bool _originalHypertension;
  late bool _originalHighCholesterol;
  late bool _originalWeightManagement;

  String? _originalDiabetesType;
  String? _originalCholesterolType;

  String? _originalWeightGoal;
  String? _originalGender;

  double? _originalCurrentWeight;
  double? _originalHeight;

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

    _diabetesType =
        widget.data.diabetesType;

    _cholesterolType =
        _readCholesterolType();

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

    _originalDiabetes =
        _diabetes;

    _originalHypertension =
        _hypertension;

    _originalHighCholesterol =
        _highCholesterol;

    _originalWeightManagement =
        _weightManagement;

    _originalDiabetesType =
        _diabetesType;

    _originalCholesterolType =
        _cholesterolType;

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
  }

  // =====================================================
  // CHOLESTEROL STORAGE
  // =====================================================

  // The profile keeps the cholesterol details as three
  // yes/no fields (set in setup, Step 3): highLdl,
  // highTriglycerides and cholesterolNotSure. This screen
  // works with one text value ("High LDL cholesterol",
  // "High triglycerides", "Both" or "Not sure"), so these
  // two methods translate between them.

  String? _readCholesterolType() {
    final ProfileSetupData data =
        widget.data;

    if (data.cholesterolNotSure) {
      return cholesterolNotSure;
    }

    if (data.highLdl &&
        data.highTriglycerides) {
      return 'Both';
    }

    if (data.highLdl) {
      return cholesterolLdl;
    }

    if (data.highTriglycerides) {
      return cholesterolTriglycerides;
    }

    return null;
  }

  void _writeCholesterolType(
    String? value,
  ) {
    final Set<String> selected =
        _cholesterolSelectionsFromStoredValue(
      value,
    );

    final bool notSure =
        selected.contains(
      cholesterolNotSure,
    );

    widget.data.cholesterolNotSure =
        notSure;

    widget.data.highLdl =
        !notSure &&
            selected.contains(
              cholesterolLdl,
            );

    widget.data.highTriglycerides =
        !notSure &&
            selected.contains(
              cholesterolTriglycerides,
            );
  }

  // =====================================================
  // CHOLESTEROL HELPERS
  // =====================================================

  Set<String>
      _cholesterolSelectionsFromStoredValue(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return <String>{};
    }

    final String stored =
        value.trim();

    if (stored == 'Both') {
      return <String>{
        cholesterolLdl,
        cholesterolTriglycerides,
      };
    }

    if (stored ==
        cholesterolLdl) {
      return <String>{
        cholesterolLdl,
      };
    }

    if (stored ==
        cholesterolTriglycerides) {
      return <String>{
        cholesterolTriglycerides,
      };
    }

    if (stored ==
        cholesterolNotSure) {
      return <String>{
        cholesterolNotSure,
      };
    }

    if (stored.contains('|')) {
      return stored
          .split('|')
          .map(
            (item) =>
                item.trim(),
          )
          .where(
            (item) =>
                item.isNotEmpty,
          )
          .toSet();
    }

    if (stored.contains('·')) {
      return stored
          .split('·')
          .map(
            (item) =>
                item.trim(),
          )
          .where(
            (item) =>
                item.isNotEmpty,
          )
          .toSet();
    }

    return <String>{};
  }

  String?
      _cholesterolStoredValueFromSelections(
    Set<String> selections,
  ) {
    if (selections.isEmpty) {
      return null;
    }

    if (selections.contains(
      cholesterolNotSure,
    )) {
      return cholesterolNotSure;
    }

    final bool hasLdl =
        selections.contains(
      cholesterolLdl,
    );

    final bool hasTriglycerides =
        selections.contains(
      cholesterolTriglycerides,
    );

    if (hasLdl &&
        hasTriglycerides) {
      return 'Both';
    }

    if (hasLdl) {
      return cholesterolLdl;
    }

    if (hasTriglycerides) {
      return cholesterolTriglycerides;
    }

    return null;
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
        _diabetesType !=
            _originalDiabetesType ||
        _cholesterolType !=
            _originalCholesterolType ||
        _weightGoal !=
            _originalWeightGoal ||
        _gender !=
            _originalGender ||
        _currentWeight !=
            _originalCurrentWeight ||
        _height !=
            _originalHeight ||
        _activityLevel !=
            _originalActivityLevel;
  }

  // =====================================================
  // SUBTITLES
  // =====================================================

  String? get _diabetesSubtitle {
    if (!_diabetes) {
      return null;
    }

    return _diabetesType;
  }

  String? get _cholesterolSubtitle {
    if (!_highCholesterol) {
      return null;
    }

    final Set<String> selections =
        _cholesterolSelectionsFromStoredValue(
      _cholesterolType,
    );

    if (selections.isEmpty) {
      return null;
    }

    if (selections.contains(
      cholesterolNotSure,
    )) {
      return cholesterolNotSure;
    }

    final List<String> labels =
        [];

    if (selections.contains(
      cholesterolLdl,
    )) {
      labels.add(
        cholesterolLdl,
      );
    }

    if (selections.contains(
      cholesterolTriglycerides,
    )) {
      labels.add(
        cholesterolTriglycerides,
      );
    }

    return labels.join(
      ' · ',
    );
  }

  String? get _weightSubtitle {
    if (!_weightManagement) {
      return null;
    }

    return _weightGoal;
  }

  // =====================================================
  // DIABETES
  // =====================================================

  Future<void>
      _handleDiabetesTap() async {
    if (_diabetes) {
      setState(() {
        _diabetes =
            false;
      });

      return;
    }

    final String? result =
        await _showChoiceSheet(
      title:
          'Diabetes or prediabetes',
      question:
          'Which best describes your condition?',
      options:
          const [
        'Prediabetes',
        'Type 1 diabetes',
        'Type 2 diabetes',
        'Not sure',
      ],
      currentValue:
          _diabetesType,
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _diabetes =
          true;

      _diabetesType =
          result;
    });
  }

  Future<void>
      _editDiabetesType() async {
    final String? result =
        await _showChoiceSheet(
      title:
          'Diabetes or prediabetes',
      question:
          'Which best describes your condition?',
      options:
          const [
        'Prediabetes',
        'Type 1 diabetes',
        'Type 2 diabetes',
        'Not sure',
      ],
      currentValue:
          _diabetesType,
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _diabetesType =
          result;
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
  // HIGH CHOLESTEROL
  // =====================================================

  Future<void>
      _handleCholesterolTap() async {
    if (_highCholesterol) {
      setState(() {
        _highCholesterol =
            false;
      });

      return;
    }

    final String? result =
        await _showCholesterolMultiSelectSheet(
      currentValue:
          _cholesterolType,
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _highCholesterol =
          true;

      _cholesterolType =
          result;
    });
  }

  Future<void>
      _editCholesterolType() async {
    final String? result =
        await _showCholesterolMultiSelectSheet(
      currentValue:
          _cholesterolType,
    );

    if (result == null ||
        !mounted) {
      return;
    }

    setState(() {
      _cholesterolType =
          result;
    });
  }

  // =====================================================
  // HIGH CHOLESTEROL SHEET
  // =====================================================

  Future<String?>
      _showCholesterolMultiSelectSheet({
    required String? currentValue,
  }) {
    final Set<String> selected =
        _cholesterolSelectionsFromStoredValue(
      currentValue,
    );

    return showModalBottomSheet<String>(
      context:
          context,

      backgroundColor:
          Colors.transparent,

      isScrollControlled:
          true,

      builder: (
        BuildContext sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            void toggleSelection(
              String option,
            ) {
              setSheetState(() {
                if (option ==
                    cholesterolNotSure) {
                  if (selected.contains(
                    cholesterolNotSure,
                  )) {
                    selected.remove(
                      cholesterolNotSure,
                    );
                  } else {
                    selected
                      ..clear()
                      ..add(
                        cholesterolNotSure,
                      );
                  }

                  return;
                }

                selected.remove(
                  cholesterolNotSure,
                );

                if (selected.contains(
                  option,
                )) {
                  selected.remove(
                    option,
                  );
                } else {
                  selected.add(
                    option,
                  );
                }
              });
            }

            return SafeArea(
              top:
                  false,

              child:
                  Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.of(
                            context,
                          )
                          .size
                          .height *
                      0.80,
                ),

                decoration:
                    const BoxDecoration(
                  color:
                      backgroundColor,

                  borderRadius:
                      BorderRadius.vertical(
                    top:
                        Radius.circular(
                      30,
                    ),
                  ),
                ),

                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    const SizedBox(
                      height:
                          13,
                    ),

                    Container(
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

                    Flexible(
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(
                          22,
                          20,
                          22,
                          10,
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                const Expanded(
                                  child:
                                      Text(
                                    'High cholesterol',

                                    style:
                                        TextStyle(
                                      color:
                                          darkPurple,

                                      fontSize:
                                          25,

                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  onPressed:
                                      () {
                                    Navigator.pop(
                                      sheetContext,
                                    );
                                  },

                                  icon:
                                      const Icon(
                                    Icons
                                        .close_rounded,

                                    color:
                                        primaryPurple,

                                    size:
                                        31,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  5,
                            ),

                            const Text(
                              'What are you currently managing?',

                              style:
                                  TextStyle(
                                color:
                                    mediumPurple,

                                fontSize:
                                    18,

                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  4,
                            ),

                            const Text(
                              'Select all that apply.',

                              style:
                                  TextStyle(
                                color:
                                    mediumPurple,

                                fontSize:
                                    14,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  20,
                            ),

                            _CholesterolCheckboxOption(
                              label:
                                  cholesterolLdl,

                              selected:
                                  selected.contains(
                                cholesterolLdl,
                              ),

                              onTap:
                                  () {
                                toggleSelection(
                                  cholesterolLdl,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  11,
                            ),

                            _CholesterolCheckboxOption(
                              label:
                                  cholesterolTriglycerides,

                              selected:
                                  selected.contains(
                                cholesterolTriglycerides,
                              ),

                              onTap:
                                  () {
                                toggleSelection(
                                  cholesterolTriglycerides,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  11,
                            ),

                            _CholesterolCheckboxOption(
                              label:
                                  cholesterolNotSure,

                              selected:
                                  selected.contains(
                                cholesterolNotSure,
                              ),

                              onTap:
                                  () {
                                toggleSelection(
                                  cholesterolNotSure,
                                );
                              },
                            ),

                            const SizedBox(
                              height:
                                  8,
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        22,
                        8,
                        22,
                        20,
                      ),

                      child:
                          SizedBox(
                        width:
                            double.infinity,

                        height:
                            54,

                        child:
                            ElevatedButton(
                          onPressed:
                              selected.isEmpty
                                  ? null
                                  : () {
                                      final String? result =
                                          _cholesterolStoredValueFromSelections(
                                        selected,
                                      );

                                      Navigator.pop(
                                        sheetContext,
                                        result,
                                      );
                                    },

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
                                0,

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
                            'Done',

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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
  // SINGLE CHOICE SHEET
  // =====================================================

  Future<String?> _showChoiceSheet({
    required String title,
    required String question,
    required List<String> options,
    required String? currentValue,
  }) {
    String? selected =
        currentValue;

    return showModalBottomSheet<String>(
      context:
          context,

      backgroundColor:
          Colors.transparent,

      isScrollControlled:
          true,

      builder: (
        BuildContext sheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            BuildContext context,
            StateSetter setSheetState,
          ) {
            return SafeArea(
              top:
                  false,

              child:
                  Container(
                constraints:
                    BoxConstraints(
                  maxHeight:
                      MediaQuery.of(
                            context,
                          )
                          .size
                          .height *
                      0.82,
                ),

                decoration:
                    const BoxDecoration(
                  color:
                      backgroundColor,

                  borderRadius:
                      BorderRadius.vertical(
                    top:
                        Radius.circular(
                      30,
                    ),
                  ),
                ),

                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  children: [
                    const SizedBox(
                      height:
                          13,
                    ),

                    Container(
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

                    Flexible(
                      child:
                          SingleChildScrollView(
                        padding:
                            const EdgeInsets.fromLTRB(
                          22,
                          20,
                          22,
                          10,
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                Expanded(
                                  child:
                                      Text(
                                    title,

                                    style:
                                        const TextStyle(
                                      color:
                                          darkPurple,

                                      fontSize:
                                          25,

                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  onPressed:
                                      () {
                                    Navigator.pop(
                                      sheetContext,
                                    );
                                  },

                                  icon:
                                      const Icon(
                                    Icons
                                        .close_rounded,

                                    color:
                                        primaryPurple,

                                    size:
                                        31,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  6,
                            ),

                            Text(
                              question,

                              style:
                                  const TextStyle(
                                color:
                                    mediumPurple,

                                fontSize:
                                    18,

                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  20,
                            ),

                            ...options.map(
                              (
                                option,
                              ) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom:
                                        11,
                                  ),

                                  child:
                                      _BottomSheetOption(
                                    label:
                                        option,

                                    selected:
                                        selected ==
                                            option,

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          selected =
                                              option;
                                        },
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        22,
                        8,
                        22,
                        20,
                      ),

                      child:
                          SizedBox(
                        width:
                            double.infinity,

                        height:
                            54,

                        child:
                            ElevatedButton(
                          onPressed:
                              selected ==
                                      null
                                  ? null
                                  : () {
                                      Navigator.pop(
                                        sheetContext,
                                        selected,
                                      );
                                    },

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
                                0,

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
                            'Done',

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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        providerEnergyKcal: widget.data.providerEnergyKcal,
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
      _weightManagement = true;
    });
  }

  // =====================================================
  // VALIDATION
  // =====================================================

  bool _validate() {
    if (_diabetes &&
        (_diabetesType ==
                null ||
            _diabetesType!
                .trim()
                .isEmpty)) {
      _showMessage(
        'Please select your diabetes or prediabetes type.',
      );

      return false;
    }

    if (_highCholesterol &&
        (_cholesterolType ==
                null ||
            _cholesterolType!
                .trim()
                .isEmpty)) {
      _showMessage(
        'Please complete your high cholesterol details.',
      );

      return false;
    }

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

    widget.data.diabetesType =
        _diabetesType;

    _writeCholesterolType(
      _cholesterolType,
    );

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

      _originalDiabetesType =
          _diabetesType;

      _originalCholesterolType =
          _cholesterolType;

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
                    'Diabetes or prediabetes',

                icon:
                    Icons.water_drop_outlined,

                subtitle:
                    _diabetesSubtitle,

                selected:
                    _diabetes,

                onTap:
                    _handleDiabetesTap,

                onEditTap:
                    _diabetes
                        ? _editDiabetesType
                        : null,
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
                    'High cholesterol',

                icon:
                    Icons.favorite_border_rounded,

                subtitle:
                    _cholesterolSubtitle,

                selected:
                    _highCholesterol,

                onTap:
                    _handleCholesterolTap,

                onEditTap:
                    _highCholesterol
                        ? _editCholesterolType
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

class _BottomSheetOption
    extends StatelessWidget {
  final String label;

  final bool selected;

  final VoidCallback onTap;

  const _BottomSheetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            AnimatedContainer(
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
                70,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                18,

            vertical:
                15,
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
              16,
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
                      ? 1.6
                      : 1.2,
            ),
          ),

          child:
              Row(
            children: [
              Expanded(
                child:
                    Text(
                  label,

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),

                    fontSize:
                        17,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Container(
                width:
                    38,

                height:
                    38,

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
                                25,
                          )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// CHOLESTEROL CHECKBOX
// =======================================================

class _CholesterolCheckboxOption
    extends StatelessWidget {
  final String label;

  final bool selected;

  final VoidCallback onTap;

  const _CholesterolCheckboxOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,

      child:
          InkWell(
        onTap:
            onTap,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        child:
            AnimatedContainer(
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
                70,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                18,

            vertical:
                15,
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
              16,
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
                      ? 1.6
                      : 1.2,
            ),
          ),

          child:
              Row(
            children: [
              Expanded(
                child:
                    Text(
                  label,

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF38138C,
                    ),

                    fontSize:
                        17,

                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              AnimatedContainer(
                duration:
                    const Duration(
                  milliseconds:
                      180,
                ),

                width:
                    32,

                height:
                    32,

                decoration:
                    BoxDecoration(
                  color:
                      selected
                          ? const Color(
                              0xFF5631AE,
                            )
                          : Colors.white,

                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),

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
                                22,
                          )
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// WEIGHT MANAGEMENT SHEET
// =======================================================

class _WeightSheetResult {
  final String goal;
  final String sex;
  final double weightKg;
  final double heightCm;
  final String activity;

  const _WeightSheetResult({
    required this.goal,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
  });
}

class _WeightManagementSheet extends StatefulWidget {
  final String? goal;
  final String? sex;
  final double? weightKg;
  final double? heightCm;
  final String? activity;

  // For the energy guide only.
  final DateTime? dateOfBirth;
  final double? providerEnergyKcal;

  const _WeightManagementSheet({
    required this.goal,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    required this.activity,
    required this.dateOfBirth,
    required this.providerEnergyKcal,
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

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double? get _weight => WeightPlanOptions.parse(_weightController.text);

  double? get _height => WeightPlanOptions.parse(_heightController.text);

  bool get _complete =>
      _goal != null &&
      _sex != null &&
      _activity != null &&
      WeightPlanOptions.weightOk(_weight) &&
      WeightPlanOptions.heightOk(_height);

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
        providerEnergyKcal: widget.providerEnergyKcal,
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
                      if (targets != null) ...[
                        const SizedBox(height: 18),
                        EnergyGuideCard(
                          kcalText: WeightPlanOptions.kcalText(targets.energyKcal),
                          note: WeightPlanOptions.energyNote(targets, _goal),
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
