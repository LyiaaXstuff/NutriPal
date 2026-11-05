import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile_setup_data.dart';

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

  String? _readCholesterolType() {
    final dynamic data =
        widget.data;

    try {
      final dynamic value =
          data.cholesterolType;

      if (value is String) {
        return value;
      }
    } catch (_) {}

    try {
      final dynamic value =
          data.cholesterolConcern;

      if (value is String) {
        return value;
      }
    } catch (_) {}

    try {
      final dynamic value =
          data.highCholesterolType;

      if (value is String) {
        return value;
      }
    } catch (_) {}

    return null;
  }

  void _writeCholesterolType(
    String? value,
  ) {
    final dynamic data =
        widget.data;

    try {
      data.cholesterolType =
          value;

      return;
    } catch (_) {}

    try {
      data.cholesterolConcern =
          value;

      return;
    } catch (_) {}

    try {
      data.highCholesterolType =
          value;
    } catch (_) {}
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
  // FORMAT NUMBER
  // =====================================================

  String _formatNumber(
    double? value,
  ) {
    if (value == null) {
      return '';
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

  Future<void>
      _showWeightManagementSheet() async {
    String? tempGoal =
        _weightGoal;

    String? tempGender =
        _gender;

    String? tempActivity =
        _activityLevel;

    final TextEditingController
        weightController =
        TextEditingController(
      text:
          _formatNumber(
        _currentWeight,
      ),
    );

    final TextEditingController
        heightController =
        TextEditingController(
      text:
          _formatNumber(
        _height,
      ),
    );

    final bool? completed =
        await showModalBottomSheet<bool>(
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
            final double? tempWeight =
                double.tryParse(
              weightController.text.trim(),
            );

            final double? tempHeight =
                double.tryParse(
              heightController.text.trim(),
            );

            final bool complete =
                tempGoal !=
                        null &&
                    tempGender !=
                        null &&
                    tempWeight !=
                        null &&
                    tempWeight >
                        0 &&
                    tempHeight !=
                        null &&
                    tempHeight >
                        0 &&
                    tempActivity !=
                        null;

            return SafeArea(
              top:
                  false,

              child:
                  Container(
                height:
                    MediaQuery.of(
                          context,
                        )
                        .size
                        .height *
                    0.88,

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

                    Expanded(
                      child:
                          SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior
                                .onDrag,

                        padding:
                            const EdgeInsets.fromLTRB(
                          22,
                          14,
                          22,
                          20,
                        ),

                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child:
                                      Text(
                                    'Weight management',

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

                            const Center(
                              child:
                                  Text(
                                'Complete the details below.',

                                style:
                                    TextStyle(
                                  color:
                                      mediumPurple,

                                  fontSize:
                                      16,
                                ),
                              ),
                            ),

                            const SizedBox(
                              height:
                                  26,
                            ),

                            // =============================
                            // WEIGHT GOAL
                            // =============================

                            const Text(
                              'Weight goal',

                              style:
                                  TextStyle(
                                color:
                                    darkPurple,

                                fontSize:
                                    17,

                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  10,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      _MiniChoiceCard(
                                    text:
                                        'Lose',

                                    selected:
                                        tempGoal ==
                                            'Lose weight',

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          tempGoal =
                                              'Lose weight';
                                        },
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      8,
                                ),

                                Expanded(
                                  child:
                                      _MiniChoiceCard(
                                    text:
                                        'Maintain',

                                    selected:
                                        tempGoal ==
                                            'Maintain weight',

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          tempGoal =
                                              'Maintain weight';
                                        },
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      8,
                                ),

                                Expanded(
                                  child:
                                      _MiniChoiceCard(
                                    text:
                                        'Gain',

                                    selected:
                                        tempGoal ==
                                            'Gain weight',

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          tempGoal =
                                              'Gain weight';
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  24,
                            ),

                            // =============================
                            // GENDER
                            // =============================

                            const Text(
                              'Gender',

                              style:
                                  TextStyle(
                                color:
                                    darkPurple,

                                fontSize:
                                    17,

                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  10,
                            ),

                            Row(
                              children: [
                                // ==========================
                                // MALE
                                // ==========================

                                Expanded(
                                  child:
                                      _GenderChoiceCard(
                                    text:
                                        'Male',

                                    icon:
                                        Icons.male_rounded,

                                    selected:
                                        tempGender ==
                                            'Male',

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          tempGender =
                                              'Male';
                                        },
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      10,
                                ),

                                // ==========================
                                // FEMALE
                                // ==========================

                                Expanded(
                                  child:
                                      _GenderChoiceCard(
                                    text:
                                        'Female',

                                    icon:
                                        Icons.female_rounded,

                                    selected:
                                        tempGender ==
                                            'Female',

                                    onTap:
                                        () {
                                      setSheetState(
                                        () {
                                          tempGender =
                                              'Female';
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  18,
                            ),

                            // =============================
                            // CURRENT WEIGHT + HEIGHT
                            // =============================

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [
                                Expanded(
                                  child:
                                      _MeasurementField(
                                    title:
                                        'Current weight',

                                    controller:
                                        weightController,

                                    unit:
                                        'kg',

                                    onChanged:
                                        () {
                                      setSheetState(
                                        () {},
                                      );
                                    },
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      10,
                                ),

                                Expanded(
                                  child:
                                      _MeasurementField(
                                    title:
                                        'Height',

                                    controller:
                                        heightController,

                                    unit:
                                        'cm',

                                    onChanged:
                                        () {
                                      setSheetState(
                                        () {},
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height:
                                  24,
                            ),

                            // =============================
                            // ACTIVITY
                            // =============================

                            const Text(
                              'Activity level',

                              style:
                                  TextStyle(
                                color:
                                    darkPurple,

                                fontSize:
                                    17,

                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),

                            const SizedBox(
                              height:
                                  10,
                            ),

                            _ActivitySelector(
                              activity:
                                  tempActivity,

                              onTap:
                                  () async {
                                final String? result =
                                    await _showActivityPicker(
                                  tempActivity,
                                );

                                if (result !=
                                        null &&
                                    mounted) {
                                  setSheetState(
                                    () {
                                      tempActivity =
                                          result;
                                    },
                                  );
                                }
                              },
                            ),

                            const SizedBox(
                              height:
                                  10,
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
                              complete
                                  ? () {
                                      _weightGoal =
                                          tempGoal;

                                      _gender =
                                          tempGender;

                                      _currentWeight =
                                          double.parse(
                                        weightController
                                            .text
                                            .trim(),
                                      );

                                      _height =
                                          double.parse(
                                        heightController
                                            .text
                                            .trim(),
                                      );

                                      _activityLevel =
                                          tempActivity;

                                      Navigator.pop(
                                        sheetContext,
                                        true,
                                      );
                                    }
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
                            'Complete setup',

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

    weightController.dispose();

    heightController.dispose();

    if (completed ==
            true &&
        mounted) {
      setState(() {
        _weightManagement =
            true;
      });
    }
  }

  // =====================================================
  // ACTIVITY PICKER
  // =====================================================

  Future<String?>
      _showActivityPicker(
    String? current,
  ) {
    String? selected =
        current;

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

                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Center(
                      child:
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
                    ),

                    const SizedBox(
                      height:
                          18,
                    ),

                    const Text(
                      'Activity level',

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
                          14,
                    ),

                    _ActivityOption(
                      icon:
                          Icons
                              .self_improvement_rounded,

                      title:
                          'Sedentary',

                      subtitle:
                          'Little or no exercise',

                      selected:
                          selected ==
                              'Sedentary',

                      onTap:
                          () {
                        setSheetState(
                          () {
                            selected =
                                'Sedentary';
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height:
                          9,
                    ),

                    _ActivityOption(
                      icon:
                          Icons
                              .directions_walk_rounded,

                      title:
                          'Lightly active',

                      subtitle:
                          'Light exercise 1–3 days/week',

                      selected:
                          selected ==
                              'Lightly active',

                      onTap:
                          () {
                        setSheetState(
                          () {
                            selected =
                                'Lightly active';
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height:
                          9,
                    ),

                    _ActivityOption(
                      icon:
                          Icons
                              .directions_run_rounded,

                      title:
                          'Moderately active',

                      subtitle:
                          'Moderate exercise 3–5 days/week',

                      selected:
                          selected ==
                              'Moderately active',

                      onTap:
                          () {
                        setSheetState(
                          () {
                            selected =
                                'Moderately active';
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height:
                          9,
                    ),

                    _ActivityOption(
                      icon:
                          Icons
                              .sports_handball_rounded,

                      title:
                          'Very active',

                      subtitle:
                          'Hard exercise 6–7 days/week',

                      selected:
                          selected ==
                              'Very active',

                      onTap:
                          () {
                        setSheetState(
                          () {
                            selected =
                                'Very active';
                          },
                        );
                      },
                    ),

                    const SizedBox(
                      height:
                          16,
                    ),

                    SizedBox(
                      width:
                          double.infinity,

                      height:
                          52,

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
                          'Done',

                          style:
                              TextStyle(
                            fontSize:
                                17,

                            fontWeight:
                                FontWeight.w800,
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
                              .arrow_back_rounded,

                          color:
                              primaryPurple,

                          size:
                              31,
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
                            25,

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

  final String? subtitle;

  final bool selected;

  final VoidCallback onTap;

  final VoidCallback? onEditTap;

  const _ConditionCard({
    required this.title,
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
              20,
              18,
              18,
              18,
            ),

            child:
                Row(
              children: [
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
// WEIGHT GOAL
// =======================================================

class _MiniChoiceCard
    extends StatelessWidget {
  final String text;

  final bool selected;

  final VoidCallback onTap;

  const _MiniChoiceCard({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        14,
      ),

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),

        height:
            62,

        decoration:
            BoxDecoration(
          color:
              selected
                  ? const Color(
                      0xFFF3ECFF,
                    )
                  : Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
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
            Stack(
          children: [
            Center(
              child:
                  Text(
                text,

                style:
                    TextStyle(
                  color:
                      selected
                          ? const Color(
                              0xFF38138C,
                            )
                          : const Color(
                              0xFF67558E,
                            ),

                  fontSize:
                      15,

                  fontWeight:
                      selected
                          ? FontWeight.w800
                          : FontWeight.w500,
                ),
              ),
            ),

            if (selected)
              const Positioned(
                right:
                    7,

                top:
                    7,

                child:
                    CircleAvatar(
                  radius:
                      12,

                  backgroundColor:
                      Color(
                    0xFF5631AE,
                  ),

                  child:
                      Icon(
                    Icons
                        .check_rounded,

                    color:
                        Colors.white,

                    size:
                        16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// GENDER
// =======================================================

class _GenderChoiceCard
    extends StatelessWidget {
  final String text;

  final IconData icon;

  final bool selected;

  final VoidCallback onTap;

  const _GenderChoiceCard({
    required this.text,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        14,
      ),

      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),

        height:
            64,

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
            14,
          ),

          border:
              Border.all(
            color:
                selected
                    ? const Color(
                        0xFF5631AE,
                      )
                    : const Color(
                        0xFFDCCFF0,
                      ),

            width:
                selected
                    ? 1.5
                    : 1.2,
          ),
        ),

        child:
            Row(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            // =========================================
            // MALE / FEMALE SYMBOL
            // =========================================

            Icon(
              icon,

              color:
                  selected
                      ? Colors.white
                      : const Color(
                          0xFF4B2E83,
                        ),

              size:
                  25,
            ),

            const SizedBox(
              width:
                  8,
            ),

            Text(
              text,

              style:
                  TextStyle(
                color:
                    selected
                        ? Colors.white
                        : const Color(
                            0xFF67558E,
                          ),

                fontSize:
                    16,

                fontWeight:
                    selected
                        ? FontWeight.w800
                        : FontWeight.w600,
              ),
            ),

            if (selected) ...[
              const SizedBox(
                width:
                    9,
              ),

              Container(
                width:
                    24,

                height:
                    24,

                decoration:
                    const BoxDecoration(
                  color:
                      Colors.white,

                  shape:
                      BoxShape.circle,
                ),

                child:
                    const Icon(
                  Icons
                      .check_rounded,

                  color:
                      Color(
                    0xFF5631AE,
                  ),

                  size:
                      17,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =======================================================
// MEASUREMENT
// =======================================================

class _MeasurementField
    extends StatelessWidget {
  final String title;

  final TextEditingController controller;

  final String unit;

  final VoidCallback onChanged;

  const _MeasurementField({
    required this.title,
    required this.controller,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        12,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          15,
        ),

        border:
            Border.all(
          color:
              const Color(
            0xFFDCCFF0,
          ),
        ),
      ),

      child:
          Column(
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
                  13,

              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height:
                8,
          ),

          // =========================================
          // NUMBER + PERMANENT UNIT
          // =========================================

          Container(
            height:
                48,

            padding:
                const EdgeInsets.only(
              left:
                  12,

              right:
                  12,
            ),

            decoration:
                BoxDecoration(
              color:
                  Colors.white,

              borderRadius:
                  BorderRadius.circular(
                10,
              ),

              border:
                  Border.all(
                color:
                    const Color(
                  0xFFDCCFF0,
                ),
              ),
            ),

            child:
                Row(
              children: [
                Expanded(
                  child:
                      TextField(
                    controller:
                        controller,

                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal:
                          true,
                    ),

                    inputFormatters:
                        [
                      FilteringTextInputFormatter
                          .allow(
                        RegExp(
                          r'^\d*\.?\d{0,2}',
                        ),
                      ),
                    ],

                    onChanged:
                        (_) {
                      onChanged();
                    },

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

                    decoration:
                        const InputDecoration(
                      isDense:
                          true,

                      border:
                          InputBorder.none,

                      enabledBorder:
                          InputBorder.none,

                      focusedBorder:
                          InputBorder.none,

                      contentPadding:
                          EdgeInsets.zero,
                    ),
                  ),
                ),

                const SizedBox(
                  width:
                      8,
                ),

                // ALWAYS VISIBLE
                Text(
                  unit,

                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF67558E,
                    ),

                    fontSize:
                        15,

                    fontWeight:
                        FontWeight.w700,
                  ),
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
// ACTIVITY SELECTOR
// =======================================================

class _ActivitySelector
    extends StatelessWidget {
  final String? activity;

  final VoidCallback onTap;

  const _ActivitySelector({
    required this.activity,
    required this.onTap,
  });

  String get _subtitle {
    switch (activity) {
      case 'Sedentary':
        return 'Little or no exercise';

      case 'Lightly active':
        return 'Light exercise 1–3 days/week';

      case 'Moderately active':
        return 'Moderate exercise 3–5 days/week';

      case 'Very active':
        return 'Hard exercise 6–7 days/week';

      default:
        return 'Select your usual activity level';
    }
  }

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
          15,
        ),

        child:
            Container(
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
                Colors.white,

            borderRadius:
                BorderRadius.circular(
              15,
            ),

            border:
                Border.all(
              color:
                  const Color(
                0xFFDCCFF0,
              ),
            ),
          ),

          child:
              Row(
            children: [
              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      activity ??
                          'Select activity level',

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

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      _subtitle,

                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF67558E,
                        ),

                        fontSize:
                            13,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .chevron_right_rounded,

                color:
                    Color(
                  0xFF4B2E83,
                ),

                size:
                    28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =======================================================
// ACTIVITY OPTION
// =======================================================

class _ActivityOption
    extends StatelessWidget {
  final IconData icon;

  final String title;

  final String subtitle;

  final bool selected;

  final VoidCallback onTap;

  const _ActivityOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,

      borderRadius:
          BorderRadius.circular(
        15,
      ),

      child:
          Container(
        width:
            double.infinity,

        padding:
            const EdgeInsets.all(
          14,
        ),

        decoration:
            BoxDecoration(
          color:
              selected
                  ? const Color(
                      0xFFF3ECFF,
                    )
                  : Colors.white,

          borderRadius:
              BorderRadius.circular(
            15,
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
          ),
        ),

        child:
            Row(
          children: [
            Container(
              width:
                  43,

              height:
                  43,

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
                  12,
                ),
              ),

              child:
                  Icon(
                icon,

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
                  12,
            ),

            Expanded(
              child:
                  Column(
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
                          15,

                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(
                    height:
                        2,
                  ),

                  Text(
                    subtitle,

                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF67558E,
                      ),

                      fontSize:
                          12.5,
                    ),
                  ),
                ],
              ),
            ),

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
                      const Color(
                    0xFF4B2E83,
                  ),

                  width:
                      2,
                ),
              ),

              child:
                  selected
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
                                  Color(
                                0xFF4B2E83,
                              ),
                            ),
                          ),
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}